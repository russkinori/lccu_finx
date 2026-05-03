import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_repo.dart';
import 'roles.dart';
import 'app_logger.dart';
import 'friendly_error.dart';

enum AuthPhase { initializing, signedOut, signingIn, ready }

class AuthVm extends ChangeNotifier {
  AuthVm({required SupabaseClient client, required AdminRepo adminRepo})
    : _client = client,
      _adminRepo = adminRepo {
    _subscription = _client.auth.onAuthStateChange.listen((event) {
      final user = event.session?.user;
      _handleAuthChange(user);
    });
    _bootstrap();
  }

  final SupabaseClient _client;
  final AdminRepo _adminRepo;
  late final StreamSubscription<AuthState> _subscription;

  AuthPhase _phase = AuthPhase.initializing;
  AuthPhase get phase => _phase;

  AppRole? _role;
  AppRole? get role => _role;

  bool get isStudent => _role == AppRole.student && isAuthenticated;
  bool get isTeacher => _role == AppRole.teacher && isAuthenticated;
  bool get isPrincipal => _role == AppRole.principal && isAuthenticated;
  bool get isGuardian => _role == AppRole.guardian && isAuthenticated;
  bool get isTeller => _role == AppRole.teller && isAuthenticated;

  String? _errorMessage;
  String? takeError() {
    final msg = _errorMessage;
    _errorMessage = null;
    return msg;
  }

  bool get isAuthenticated => _phase == AuthPhase.ready;
  bool get isAdmin => _role == AppRole.admin && isAuthenticated;

  bool _disposed = false;
  // Increments on every auth-change handling to invalidate in-flight role lookups.
  int _authEpoch = 0;

  Future<void> _bootstrap() async {
    appLog('AuthVm: _bootstrap called');
    final user = _client.auth.currentUser;
    appLog('AuthVm: _bootstrap currentUser present = ${user != null}');
    await _handleAuthChange(user);
    appLog('AuthVm: _bootstrap completed');
  }

  Future<void> _handleAuthChange(User? user) async {
    appLog(
      'AuthVm: _handleAuthChange called with user = ${user?.id ?? "null"}',
    );
    if (_disposed) return;
    // Bump epoch to invalidate any in-flight role lookups from prior states.
    final int localEpoch = ++_authEpoch;
    if (user == null) {
      appLog('AuthVm: user is null, setting phase to signedOut');
      _role = null;
      _phase = AuthPhase.signedOut;
      notifyListeners();
      return;
    }
    appLog('AuthVm: user found, setting phase to signingIn');
    _phase = AuthPhase.signingIn;
    notifyListeners();

    try {
      if (kDebugMode) {
        // Helpful runtime trace when debugging role resolution hangs
        // (visible in debug console / device logs).
        // Do NOT log sensitive tokens or PII.
        appLog('AuthVm: resolving roles for current user');
      }
      // Protect against the role lookup hanging indefinitely by using a timeout.
      // If the backend is slow/unreachable, we'll treat it as an error and sign out
      // so the UI doesn't remain stuck in the signingIn phase.
      final String resolvingUserId = user.id;
      final roles = await _adminRepo
          .getUserRoles(resolvingUserId)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Role lookup timed out'),
          );
      appLog('AuthVm: got roles = $roles');
      // If auth state changed while awaiting (e.g., a sign-out occurred), ignore results.
      if (localEpoch != _authEpoch) {
        appLog(
          'AuthVm: stale role result ignored (epoch $localEpoch != current $_authEpoch)',
        );
        return;
      }
      final current = _client.auth.currentUser;
      if (current == null || current.id != resolvingUserId) {
        appLog(
          'AuthVm: user changed during role lookup; discarding results',
        );
        return;
      }
      // Accept multiple app roles. Admin takes precedence.
      if (roles.contains(AppRole.admin)) {
        appLog('AuthVm: user is admin');
        _role = AppRole.admin;
        _phase = AuthPhase.ready;
      } else if (roles.contains(AppRole.student)) {
        appLog('AuthVm: user is student');
        _role = AppRole.student;
        _phase = AuthPhase.ready;
      } else if (roles.contains(AppRole.teacher)) {
        appLog('AuthVm: user is teacher');
        _role = AppRole.teacher;
        _phase = AuthPhase.ready;
      } else if (roles.contains(AppRole.principal)) {
        _role = AppRole.principal;
        _phase = AuthPhase.ready;
      } else if (roles.contains(AppRole.guardian)) {
        _role = AppRole.guardian;
        _phase = AuthPhase.ready;
      } else if (roles.contains(AppRole.teller)) {
        _role = AppRole.teller;
        _phase = AuthPhase.ready;
      } else {
        _role = null;
        _errorMessage = 'Your account is not permitted to access this app.';
        // Double-check epoch before taking any destructive action.
        if (localEpoch == _authEpoch) {
          await _client.auth.signOut();
        }
        _phase = AuthPhase.signedOut;
      }
    } catch (e) {
      // If auth state changed while awaiting, just bail quietly.
      if (localEpoch != _authEpoch) {
        appLog('AuthVm: role lookup error ignored due to epoch change: $e');
        return;
      }
      _role = null;
      _errorMessage = friendlyActionError('Failed to resolve your account role.', e);
      // Ensure we clear any partially-authenticated state so the app returns to
      // the signed out/login UI instead of remaining stuck in signingIn.
      try {
        if (kDebugMode) {
          appLog('AuthVm: signing out due to role lookup failure: $e');
        }
        await _client.auth.signOut();
      } catch (_) {}
      _phase = AuthPhase.signedOut;
    }

    appLog(
      'AuthVm: _handleAuthChange complete, phase = $_phase, role = $_role',
    );
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    if (_disposed) return;
    if (_phase == AuthPhase.signingIn) return;
    _phase = AuthPhase.signingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _phase = AuthPhase.signedOut;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e, fallback: 'Sign in failed. Please check your details and try again.');
      _phase = AuthPhase.signedOut;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    // Immediately update local state so UI can react synchronously.
    try {
      _role = null;
      _phase = AuthPhase.signedOut;
      notifyListeners();
    } catch (_) {}
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // ignore errors; the onAuthStateChange listener will handle final state
    }
  }

  /// Request a password reset email for the given email address.
  /// Returns true if the request was successful, false otherwise.
  Future<bool> requestPasswordReset(String email) async {
    try {
      // Note: The redirect URL must match exactly what's configured in Supabase dashboard
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.lccu_finx://reset-password',
      );
      if (kDebugMode) {
        appLog('AuthVm: password reset email sent');
      }
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        appLog('AuthVm: Password reset error: ${e.message}');
      }
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = friendlyActionError('Failed to send reset email.', e);
      if (kDebugMode) {
        appLog('AuthVm: Password reset error: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// Send OTP to user's email for password reset verification
  /// Returns true if OTP was sent successfully
  Future<bool> sendPasswordResetOTP(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null,
      );
      if (kDebugMode) {
        appLog('AuthVm: password reset OTP sent');
      }
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        appLog('AuthVm: OTP send error: ${e.message}');
      }
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = friendlyActionError('Failed to send verification code.', e);
      if (kDebugMode) {
        appLog('AuthVm: OTP send error: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP and update password
  /// Returns true if verification and password update succeeded
  Future<bool> verifyOTPAndResetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      // First verify the OTP by signing in
      final response = await _client.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: otp,
      );

      if (response.session == null) {
        _errorMessage = 'Invalid or expired OTP';
        if (kDebugMode) {
          appLog('AuthVm: OTP verification failed - no session');
        }
        notifyListeners();
        return false;
      }

      if (kDebugMode) {
        appLog('AuthVm: OTP verified successfully');
      }

      // Now update the password
      await _client.auth.updateUser(UserAttributes(password: newPassword));

      if (kDebugMode) {
        appLog(
          'AuthVm: Password updated successfully after OTP verification',
        );
      }

      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        appLog(
          'AuthVm: OTP verification/password update error: ${e.message}',
        );
      }
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = friendlyActionError('Failed to verify the code or update your password.', e);
      if (kDebugMode) {
        appLog('AuthVm: OTP verification error: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// Update the user's password after they've clicked the reset link.
  /// This should be called after the app receives the deep link with the reset token.
  Future<bool> updatePassword(String newPassword) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (kDebugMode) {
        appLog(
          'AuthVm: attempting password update with active session: ${currentUser != null}',
        );
      }

      if (currentUser == null) {
        _errorMessage =
            'Session expired. Please request a new password reset link.';
        if (kDebugMode) {
          appLog('AuthVm: No active session for password update');
        }
        notifyListeners();
        return false;
      }

      await _client.auth.updateUser(UserAttributes(password: newPassword));

      if (kDebugMode) {
        appLog('AuthVm: Password updated successfully');
      }
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      if (kDebugMode) {
        appLog(
          'AuthVm: Password update error: ${e.message} (code: ${e.statusCode})',
        );
      }
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = friendlyActionError('Failed to update password.', e);
      if (kDebugMode) {
        appLog('AuthVm: Password update error: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// Requests a password reset email to be sent to the given email address.
  /// Returns true if the request was successful, false otherwise.
  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}

class AuthScope extends InheritedNotifier<AuthVm> {
  const AuthScope({
    super.key,
    required AuthVm super.notifier,
    required super.child,
  });

  static AuthVm of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
      assert(
        scope != null,
        'AuthScope.of() called with no AuthScope in context',
      );
      return scope!.notifier!;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<AuthScope>();
    final scope = element?.widget as AuthScope?;
    assert(scope != null, 'AuthScope.of() called with no AuthScope in context');
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant AuthScope oldWidget) => true;
}
