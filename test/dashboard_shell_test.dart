import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lccu_finx/features/admin/view/dashboard_shell.dart';
import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/features/admin/data/admin_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mock classes for testing
class MockSupabaseClient extends Fake implements SupabaseClient {}

class MockAdminRepo extends Fake implements AdminRepo {}

class MockAuthVm extends ChangeNotifier implements AuthVm {
  bool _isAuthenticated = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    notifyListeners();
  }

  @override
  AuthPhase get phase =>
      isAuthenticated ? AuthPhase.ready : AuthPhase.signedOut;

  @override
  bool get isAdmin => false;

  @override
  bool get isPrincipal => false;

  @override
  bool get isTeacher => false;

  @override
  bool get isStudent => false;

  @override
  bool get isTeller => false;

  @override
  bool get isGuardian => false;

  @override
  String? takeError() => null;

  @override
  Future<void> signOut() async {
    setAuthenticated(false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DashboardShell Tests', () {
    testWidgets('DashboardShell renders with basic content', (
      WidgetTester tester,
    ) async {
      final mockAuthVm = MockAuthVm();

      await tester.pumpWidget(
        MaterialApp(
          home: AuthScope(
            notifier: mockAuthVm,
            child: const DashboardShell(
              center: Text('Test Content'),
              welcomeText: 'TEST WELCOME',
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.text('TEST WELCOME'), findsOneWidget);
      expect(find.byType(Image), findsWidgets); // LCCU logo
    });

    testWidgets('DashboardShell shows logout link when empty welcomeText', (
      WidgetTester tester,
    ) async {
      final mockAuthVm = MockAuthVm();
      mockAuthVm.setAuthenticated(true);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthScope(
            notifier: mockAuthVm,
            child: const DashboardShell(
              center: Text('Content'),
              welcomeText: '', // Empty triggers logout link
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('DashboardShell uses adaptive layout on narrow screens', (
      WidgetTester tester,
    ) async {
      final mockAuthVm = MockAuthVm();

      // Set a narrow screen size
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: AuthScope(
            notifier: mockAuthVm,
            child: const DashboardShell(
              center: Text('Narrow Screen'),
              welcomeText: 'NARROW',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('NARROW'), findsOneWidget);

      // Reset to default
      addTearDown(() => tester.view.resetPhysicalSize());
    });
  });
}
