// Widget tests for the brute-force lockout in LoginForm.
//
// LoginForm protects against credential stuffing by locking the sign-in
// button for 30 seconds after 5 consecutive failed attempts. These tests
// verify that critical protection is working correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lccu_finx/features/admin/data/admin_repo.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';
import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/features/auth/view/login_page.dart';
import 'package:lccu_finx/app/roles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

/// GoTrueClient stub whose signInWithPassword always throws AuthException.
class _FailingGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {}

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    throw const AuthException('Invalid login credentials');
  }
}

/// GoTrueClient stub that fails [failCount] times then succeeds.
/// Used to verify that a successful sign-in resets the failure counter.
class _FailThenSucceedGoTrueClient extends Fake implements GoTrueClient {
  _FailThenSucceedGoTrueClient({required this.failCount});

  final int failCount;
  int _calls = 0;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {}

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    _calls++;
    if (_calls <= failCount) {
      throw const AuthException('Invalid login credentials');
    }
    // Succeed — AuthVm keeps phase=signingIn (no stream event in mock),
    // but _LoginFormState resets _failedAttempts to 0.
    return AuthResponse();
  }
}

class _MockSupabaseClient extends Fake implements SupabaseClient {
  _MockSupabaseClient(this._auth);
  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;
}

class _MockAdminRepo extends Fake implements AdminRepo {
  @override
  Future<List<AppRole>> getUserRoles(String userId) async => [];
}

// ── Helpers ────────────────────────────────────────────────────────────────

AuthVm _makeAuthVm(GoTrueClient goTrue) => AuthVm(
  client: _MockSupabaseClient(goTrue),
  adminRepo: _MockAdminRepo(),
);

Widget _buildApp(AuthVm authVm) => MaterialApp(
  home: Scaffold(
    body: AuthScope(notifier: authVm, child: const LoginForm()),
  ),
);

/// Fills the email + password fields and taps "Login" [count] times,
/// pumping two frames after each tap to let the async chain complete.
Future<void> _tapLogin(WidgetTester tester, {required int count}) async {
  await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'password123');

  for (var i = 0; i < count; i++) {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump(); // start async chain / drain microtasks
    await tester.pump(); // build updated frame
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    setAppLoggerEnabledForTesting(false);
  });
  tearDownAll(() => setAppLoggerEnabledForTesting(true));

  group('LoginForm brute-force lockout', () {
    late AuthVm authVm;

    setUp(() {
      // Reset prefs before each test so lockout state from a previous test
      // does not bleed into the next one via _restoreLockoutState().
      SharedPreferences.setMockInitialValues({});
      authVm = _makeAuthVm(_FailingGoTrueClient());
    });
    tearDown(() => authVm.dispose());

    testWidgets('no lockout message is shown before 5 failures', (tester) async {
      await tester.pumpWidget(_buildApp(authVm));
      await tester.pump(); // bootstrap

      await _tapLogin(tester, count: 4);

      expect(find.textContaining('Too many failed attempts'), findsNothing);
    });

    testWidgets(
      'login button remains active before the lockout threshold',
      (tester) async {
        await tester.pumpWidget(_buildApp(authVm));
        await tester.pump();

        await _tapLogin(tester, count: 4);

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Login'),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'lockout message appears after exactly 5 consecutive failures',
      (tester) async {
        await tester.pumpWidget(_buildApp(authVm));
        await tester.pump();

        await _tapLogin(tester, count: 5);

        expect(
          find.textContaining('Too many failed attempts'),
          findsOneWidget,
        );
        expect(find.textContaining('Try again in'), findsOneWidget);
      },
    );

    testWidgets(
      'login button is disabled immediately after the 5th failure',
      (tester) async {
        await tester.pumpWidget(_buildApp(authVm));
        await tester.pump();

        await _tapLogin(tester, count: 5);

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Login'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'lockout countdown starts at 30 seconds on the 5th failure',
      (tester) async {
        // Note: the timer uses DateTime.now() for remaining-time display, so
        // wall-clock expiry cannot be simulated with FakeAsync.  We verify
        // that the countdown text initialises at the correct 30-second value.
        await tester.pumpWidget(_buildApp(authVm));
        await tester.pump();

        await _tapLogin(tester, count: 5);

        expect(
          find.textContaining('Try again in 30 seconds'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'email validation prevents login attempt with invalid email',
      (tester) async {
        await tester.pumpWidget(_buildApp(authVm));
        await tester.pump();

        await tester.enterText(
          find.byType(TextFormField).first,
          'not-an-email',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'password123',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump();
        await tester.pump();

        // Form validation should fail; no sign-in attempt → no failure counted
        expect(find.text('Enter a valid email address'), findsOneWidget);
        expect(find.textContaining('Too many failed attempts'), findsNothing);
      },
    );
  });

  group('LoginForm success resets failure counter', () {
    testWidgets(
      'successful sign-in after 4 failures does not trigger lockout',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        // Client fails the first 4 calls, succeeds on the 5th.
        final client = _FailThenSucceedGoTrueClient(failCount: 4);
        final vm = _makeAuthVm(client);
        addTearDown(vm.dispose);

        await tester.pumpWidget(_buildApp(vm));
        await tester.pump();

        // 4 failures — counter reaches 4 but lockout threshold (5) not met.
        await _tapLogin(tester, count: 4);
        expect(find.textContaining('Too many failed attempts'), findsNothing);

        // 5th attempt succeeds — _LoginFormState resets _failedAttempts to 0.
        await _tapLogin(tester, count: 1);

        // No lockout should have been triggered.
        expect(find.textContaining('Too many failed attempts'), findsNothing);
      },
    );
  });
}
