// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/features/admin/data/admin_repo.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';
import 'package:lccu_finx/app/roles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Minimal User object constructed from JSON — matches gotrue v2 API.
final _testUser = User.fromJson(const {
  'id': 'routing-test-user-id',
  'aud': 'authenticated',
  'created_at': '2024-01-01T00:00:00.000Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
});

/// GoTrueClient stub that always reports [_testUser] as the current user.
class _AuthenticatedGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  User? get currentUser => _testUser;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {}
}

/// GoTrueClient stub that reports no current user (unauthenticated state).
class _UnauthenticatedGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {}
}

class _MockSupabaseClient extends Fake implements SupabaseClient {
  _MockSupabaseClient(this._auth);

  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;
}

/// AdminRepo stub that immediately returns a pre-configured role list.
class _FixedRoleRepo extends Fake implements AdminRepo {
  _FixedRoleRepo(this._roles);

  final List<AppRole> _roles;

  @override
  Future<List<AppRole>> getUserRoles(String userId) async => List.of(_roles);
}

/// Builds an [AuthVm] with an authenticated user who has [roles].
AuthVm _makeVmWithRoles(List<AppRole> roles) {
  final client = _MockSupabaseClient(_AuthenticatedGoTrueClient());
  return AuthVm(client: client, adminRepo: _FixedRoleRepo(roles));
}

/// Builds an [AuthVm] for a user that has no assigned roles (triggers sign-out).
AuthVm _makeVmNoRoles() {
  final client = _MockSupabaseClient(_AuthenticatedGoTrueClient());
  return AuthVm(client: client, adminRepo: _FixedRoleRepo([]));
}

/// Builds an [AuthVm] with no current user (signedOut path).
AuthVm _makeVmSignedOut() {
  final client = _MockSupabaseClient(_UnauthenticatedGoTrueClient());
  return AuthVm(client: client, adminRepo: _FixedRoleRepo([]));
}

// How long to wait for the async bootstrap to complete.
const _bootstrapDelay = Duration(milliseconds: 150);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => setAppLoggerEnabledForTesting(false));
  tearDownAll(() => setAppLoggerEnabledForTesting(true));

  group('AuthVm role routing predicates', () {
    // -- admin ---------------------------------------------------------------
    test('admin role: isAdmin true, phase ready, all other predicates false',
        () async {
      final vm = _makeVmWithRoles([AppRole.admin]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.phase, AuthPhase.ready);
      expect(vm.role, AppRole.admin);
      expect(vm.isAdmin, isTrue);
      // All other role predicates should be false.
      expect(vm.isStudent, isFalse);
      expect(vm.isTeacher, isFalse);
      expect(vm.isPrincipal, isFalse);
      expect(vm.isGuardian, isFalse);
      expect(vm.isTeller, isFalse);
    });

    // -- student -------------------------------------------------------------
    test('student role: isStudent true, phase ready, all other predicates false',
        () async {
      final vm = _makeVmWithRoles([AppRole.student]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.phase, AuthPhase.ready);
      expect(vm.role, AppRole.student);
      expect(vm.isStudent, isTrue);
      expect(vm.isAdmin, isFalse);
      expect(vm.isTeacher, isFalse);
      expect(vm.isPrincipal, isFalse);
      expect(vm.isGuardian, isFalse);
      expect(vm.isTeller, isFalse);
    });

    // -- teacher -------------------------------------------------------------
    test('teacher role: isTeacher true, phase ready, all other predicates false',
        () async {
      final vm = _makeVmWithRoles([AppRole.teacher]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.phase, AuthPhase.ready);
      expect(vm.role, AppRole.teacher);
      expect(vm.isTeacher, isTrue);
      expect(vm.isAdmin, isFalse);
      expect(vm.isStudent, isFalse);
      expect(vm.isPrincipal, isFalse);
      expect(vm.isGuardian, isFalse);
      expect(vm.isTeller, isFalse);
    });

    // -- principal -----------------------------------------------------------
    test(
        'principal role: isPrincipal true, phase ready, all other predicates false',
        () async {
      final vm = _makeVmWithRoles([AppRole.principal]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.phase, AuthPhase.ready);
      expect(vm.role, AppRole.principal);
      expect(vm.isPrincipal, isTrue);
      expect(vm.isAdmin, isFalse);
      expect(vm.isStudent, isFalse);
      expect(vm.isTeacher, isFalse);
      expect(vm.isGuardian, isFalse);
      expect(vm.isTeller, isFalse);
    });

    // -- guardian ------------------------------------------------------------
    test(
        'guardian role: isGuardian true, phase ready, all other predicates false',
        () async {
      final vm = _makeVmWithRoles([AppRole.guardian]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.phase, AuthPhase.ready);
      expect(vm.role, AppRole.guardian);
      expect(vm.isGuardian, isTrue);
      expect(vm.isAdmin, isFalse);
      expect(vm.isStudent, isFalse);
      expect(vm.isTeacher, isFalse);
      expect(vm.isPrincipal, isFalse);
      expect(vm.isTeller, isFalse);
    });

    // -- teller --------------------------------------------------------------
    test('teller role: isTeller true, phase ready, all other predicates false',
        () async {
      final vm = _makeVmWithRoles([AppRole.teller]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.phase, AuthPhase.ready);
      expect(vm.role, AppRole.teller);
      expect(vm.isTeller, isTrue);
      expect(vm.isAdmin, isFalse);
      expect(vm.isStudent, isFalse);
      expect(vm.isTeacher, isFalse);
      expect(vm.isPrincipal, isFalse);
      expect(vm.isGuardian, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('AuthVm role precedence', () {
    test('admin takes precedence over student when both roles are assigned',
        () async {
      final vm = _makeVmWithRoles([AppRole.student, AppRole.admin]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.phase, AuthPhase.ready);
      expect(vm.role, AppRole.admin,
          reason: 'Admin always wins in the precedence chain.');
      expect(vm.isAdmin, isTrue);
      expect(vm.isStudent, isFalse);
    });

    test('admin takes precedence over teacher when both roles are assigned',
        () async {
      final vm = _makeVmWithRoles([AppRole.teacher, AppRole.admin]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.role, AppRole.admin);
      expect(vm.isAdmin, isTrue);
      expect(vm.isTeacher, isFalse);
    });

    test('student takes precedence over teacher in precedence chain', () async {
      // Per _handleAuthChange: admin > student > teacher > principal > guardian > teller
      final vm = _makeVmWithRoles([AppRole.teacher, AppRole.student]);
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.role, AppRole.student);
      expect(vm.isStudent, isTrue);
      expect(vm.isTeacher, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('AuthVm unauthenticated routing', () {
    test('all role predicates are false when phase is signedOut', () async {
      final vm = _makeVmSignedOut();
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      expect(vm.phase, AuthPhase.signedOut);
      expect(vm.isAuthenticated, isFalse);
      expect(vm.isAdmin, isFalse);
      expect(vm.isStudent, isFalse);
      expect(vm.isTeacher, isFalse);
      expect(vm.isPrincipal, isFalse);
      expect(vm.isGuardian, isFalse);
      expect(vm.isTeller, isFalse);
    });

    test('user with no assigned roles is signed out and error message is set',
        () async {
      final vm = _makeVmNoRoles();
      addTearDown(vm.dispose);
      await Future.delayed(_bootstrapDelay);

      // Unrecognised user should be booted back to signedOut.
      expect(vm.phase, AuthPhase.signedOut);
      expect(vm.role, isNull);
      // An error message should be queued for display.
      final error = vm.takeError();
      expect(error, isNotNull);
      expect(error, contains('not permitted'));
    });

    test('all role predicates false while role lookup is still in-flight', () {
      final vm = _makeVmWithRoles([AppRole.admin]);
      addTearDown(vm.dispose);

      // No await — bootstrap has started but getUserRoles has not returned yet.
      // The phase moves to signingIn synchronously; ready is only set after
      // the async role lookup completes.
      expect(vm.phase, AuthPhase.signingIn);
      expect(vm.isAuthenticated, isFalse,
          reason: 'isAuthenticated requires phase == ready');
      expect(vm.isAdmin, isFalse,
          reason: 'isAdmin requires both the correct role AND isAuthenticated');
    });
  });
}
