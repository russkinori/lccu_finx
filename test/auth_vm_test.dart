import 'package:flutter_test/flutter_test.dart';
import 'package:lccu_finx/auth_vm.dart';
import 'package:lccu_finx/admin_repo.dart';
import 'package:lccu_finx/app_logger.dart';
import 'package:lccu_finx/roles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Simple mock admin repo for testing role resolution logic
class MockAdminRepo extends Fake implements AdminRepo {
  final Map<String, List<AppRole>> _userRoles = {};

  void setUserRoles(String userId, List<AppRole> roles) {
    _userRoles[userId] = roles;
  }

  @override
  Future<List<AppRole>> getUserRoles(String userId) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return _userRoles[userId] ?? [];
  }
}

// Minimal mock for Supabase client with empty auth stream
class MockSupabaseClient extends Fake implements SupabaseClient {
  final _mockAuth = MockGoTrueClient();

  @override
  GoTrueClient get auth => _mockAuth;
}

class MockGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {
    // no-op for testing
  }
}

void main() {
  setUpAll(() {
    setAppLoggerEnabledForTesting(false);
  });

  tearDownAll(() {
    setAppLoggerEnabledForTesting(true);
  });

  group('AuthVm Tests', () {
    late MockSupabaseClient mockClient;
    late MockAdminRepo mockRepo;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockRepo = MockAdminRepo();
    });

    test('AuthVm initializes and completes bootstrap', () async {
      final authVm = AuthVm(client: mockClient, adminRepo: mockRepo);

      // Wait for bootstrap to complete
      await Future.delayed(Duration(milliseconds: 50));

      expect(authVm.phase, AuthPhase.signedOut);
      expect(authVm.isAuthenticated, false);
      expect(authVm.role, null);

      authVm.dispose();
    });

    test('AuthVm transitions to signedOut when no user', () async {
      final authVm = AuthVm(client: mockClient, adminRepo: mockRepo);

      // Wait for bootstrap to complete
      await Future.delayed(const Duration(milliseconds: 150));

      expect(authVm.phase, AuthPhase.signedOut);
      expect(authVm.isAuthenticated, false);

      authVm.dispose();
    });

    test('AuthVm signOut sets phase to signedOut', () async {
      final authVm = AuthVm(client: mockClient, adminRepo: mockRepo);

      await authVm.signOut();

      expect(authVm.phase, AuthPhase.signedOut);
      expect(authVm.role, null);
      expect(authVm.isAuthenticated, false);

      authVm.dispose();
    });

    test('AuthVm role getters return correct values', () {
      final authVm = AuthVm(client: mockClient, adminRepo: mockRepo);

      // When not authenticated, all role checks should be false
      expect(authVm.isAdmin, false);
      expect(authVm.isTeller, false);
      expect(authVm.isTeacher, false);
      expect(authVm.isPrincipal, false);
      expect(authVm.isStudent, false);
      expect(authVm.isGuardian, false);

      authVm.dispose();
    });

    test('AuthVm takeError returns and clears error message', () {
      final authVm = AuthVm(client: mockClient, adminRepo: mockRepo);

      // Initially no error
      expect(authVm.takeError(), null);

      // After taking error, it should be null again
      expect(authVm.takeError(), null);

      authVm.dispose();
    });

    test('MockAdminRepo returns correct roles for user', () async {
      mockRepo.setUserRoles('test-user', [AppRole.teller, AppRole.admin]);

      final roles = await mockRepo.getUserRoles('test-user');

      expect(roles, contains(AppRole.teller));
      expect(roles, contains(AppRole.admin));
      expect(roles.length, 2);
    });

    test('MockAdminRepo returns empty list for unknown user', () async {
      final roles = await mockRepo.getUserRoles('unknown-user');

      expect(roles, isEmpty);
    });
  });
}
