import 'package:flutter/material.dart';

import 'package:lccu_finx/features/admin/data/admin_repo.dart';
import 'package:lccu_finx/app/app_router.dart';
import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/features/web/view/web_shell.dart';
import 'package:lccu_finx/features/auth/view/login_page.dart';
import 'package:lccu_finx/features/auth/view/web_login.dart';
import 'package:lccu_finx/app/adaptive.dart';
import 'dart:async';
import 'package:lccu_finx/app/supabase_config.dart';
import 'package:lccu_finx/features/admin/view/dashboard_shell.dart';
import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/features/student/data/student_repo.dart';
import 'package:lccu_finx/features/student/viewmodel/student_vm.dart';
import 'package:lccu_finx/features/student/view/student_home.dart';
import 'package:lccu_finx/features/principal/data/principal_repo.dart';
import 'package:lccu_finx/features/principal/viewmodel/principal_vm.dart';
import 'package:lccu_finx/features/principal/view/principal_home.dart';
import 'package:lccu_finx/features/teacher/view/teacher_home.dart';
import 'package:lccu_finx/features/teacher/data/teacher_repo.dart';
import 'package:lccu_finx/features/teacher/viewmodel/teacher_vm.dart';
import 'package:lccu_finx/features/guardian/view/guardian_home.dart';
import 'package:lccu_finx/features/guardian/data/guardian_repo.dart';
import 'package:lccu_finx/features/guardian/viewmodel/guardian_vm.dart';
import 'package:lccu_finx/features/teller/view/teller_router.dart';
import 'package:lccu_finx/features/auth/view/reset_password.dart';
import 'package:lccu_finx/features/auth/view/password_reset.dart';
import 'package:lccu_finx/features/settings/view/settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';
import 'package:lccu_finx/features/notifications/data/notification_repo.dart';
import 'package:lccu_finx/features/notifications/viewmodel/notification_vm.dart';
import 'package:lccu_finx/features/notifications/view/notification_bell.dart';
import 'package:lccu_finx/features/legal/service/consent_service.dart';
import 'package:lccu_finx/features/legal/view/consent_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.adminRepo});

  final AdminRepo adminRepo;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;

  // null = not yet checked, false = must show consent, true = accepted
  bool? _consentAccepted;
  bool _checkingConsent = false;

  Future<void> _checkConsent() async {
    if (_checkingConsent) return;
    _checkingConsent = true;
    final accepted = await ConsentService.isAccepted();
    if (mounted) setState(() => _consentAccepted = accepted);
  }

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes (including password reset deep links)
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final event = data.event;
      appLog('AuthGate: Auth event: $event');
      appLog('AuthGate: Session: ${data.session != null}');

      if (event == AuthChangeEvent.passwordRecovery) {
        // Check if we have a valid session from the reset link
        if (data.session != null) {
          appLog('AuthGate: Valid password recovery session, navigating to reset page');
          // Navigate to reset password page when deep link is clicked
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ResetPasswordPage()),
          );
        } else {
          appLog('AuthGate: Password recovery event but no session');
          // Show error page if no session (token expired or invalid)
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PasswordResetErrorPage(),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Widget _settingsButton(BuildContext ctx) => IconButton(
    icon: const Icon(Icons.settings),
    onPressed: () => Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => const SettingsAboutPage()),
    ),
  );

  /// Creates a fresh NotificationVm and kicks off an initial fetch.
  NotificationVm _makeNotifVm() {
    final vm = NotificationVm(
      repo: SupabaseNotificationRepository(supabase),
    );
    scheduleMicrotask(() => vm.refresh());
    return vm;
  }

  @override
  Widget build(BuildContext context) {
    appLog('AuthGate: build called');
    final authVm = AuthScope.of(context);
    final phase = authVm.phase;
    appLog('AuthGate: phase = $phase');

    final error = authVm.takeError();
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(SnackBar(content: Text(error)));
      });
    }

    if (phase == AuthPhase.ready) {
      appLog('AuthGate: phase is ready, checking roles');

      // --- Consent gate ---
      if (_consentAccepted == null) {
        _checkConsent();
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!_consentAccepted!) {
        return ConsentScreen(
          onAccepted: () => setState(() => _consentAccepted = true),
        );
      }
      // Admin users go to the admin console
      if (authVm.isAdmin) {
        appLog('AuthGate: user is admin, showing AppRouter');
        return AppRouter(role: authVm.role!, repo: widget.adminRepo);
      }

      // Students -> StudentHome (mobile DashboardShell)
      if (authVm.isStudent) {
        appLog('AuthGate: user is student, showing StudentHome');
        final common = CommonRepository(supabase);
        final repo = SupabaseStudentRepository(supabase, common);
        final vm = StudentVm(repo: repo);
        scheduleMicrotask(() => vm.bootstrap());
        return NotificationScope(
          vm: _makeNotifVm(),
          child: StudentScope(
            notifier: vm,
            child: DashboardShell(
              center: const StudentHome(),
              welcomeText: '',
              appBarActions: [
                const NotificationBell(),
                _settingsButton(context),
              ],
            ),
          ),
        );
      }

      // Principals -> PrincipalHome with PrincipalVm scope
      if (authVm.isPrincipal) {
        appLog('AuthGate: user is principal, showing PrincipalHome');
        final common = CommonRepository(supabase);
        final repo = SupabasePrincipalRepository(supabase, common);
        final vm = PrincipalVm(repo: repo, common: common);
        scheduleMicrotask(() => vm.bootstrap());
        return NotificationScope(
          vm: _makeNotifVm(),
          child: PrincipalScope(
            notifier: vm,
            child: DashboardShell(
              center: const PrincipalHome(),
              welcomeText: '',
              appBarActions: [
                const NotificationBell(),
                _settingsButton(context),
              ],
            ),
          ),
        );
      }

      // Teachers -> TeacherHome with TeacherVm scope
      if (authVm.isTeacher) {
        final common = CommonRepository(supabase);
        final repo = SupabaseTeacherRepository(supabase, common);
        final vm = TeacherVm(repo: repo);
        scheduleMicrotask(() => vm.bootstrap());
        return NotificationScope(
          vm: _makeNotifVm(),
          child: TeacherScope(
            notifier: vm,
            child: Builder(
              builder: (ctx) => DashboardShell(
                center: const TeacherHome(),
                welcomeText: '',
                appBarActions: [
                  const NotificationBell(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      final teacherVm = TeacherScope.of(ctx, listen: false);
                      teacherVm.refresh();
                    },
                  ),
                  _settingsButton(ctx),
                ],
              ),
            ),
          ),
        );
      }

      // Guardians -> GuardianHome with GuardianVm scope
      if (authVm.isGuardian) {
        appLog('AuthGate: user is guardian, showing GuardianHome');
        final common = CommonRepository(supabase);
        final repo = SupabaseGuardianRepository(supabase, common);
        final vm = GuardianVm(repo: repo);
        scheduleMicrotask(() => vm.bootstrap());
        return NotificationScope(
          vm: _makeNotifVm(),
          child: GuardianScope(
            notifier: vm,
            child: DashboardShell(
              center: const GuardianHome(),
              welcomeText: '',
              appBarActions: [
                const NotificationBell(),
                _settingsButton(context),
              ],
            ),
          ),
        );
      }

      // Tellers -> TellerRouter for web, DashboardShell with TellerHome for mobile
      // Tellers -> always use TellerRouter (it handles both web and mobile with correct routing)
      if (authVm.isTeller) {
        return const TellerRouter();
      }
    }

    if (phase == AuthPhase.initializing) {
      appLog('AuthGate: phase is initializing, showing spinner');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    appLog('AuthGate: building login UI');
    final loginUi = _buildLoginUi();

    if (phase == AuthPhase.signingIn) {
      return Stack(
        children: [
          loginUi,
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
    }

    return loginUi;
  }

  Widget _buildLoginUi() {
    if (useWebLayout(context)) {
      return WebShell(
        currentRoute: '/login',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                color: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: WebLogin(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const LoginPage();
  }
}
