import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/features/teller/view/teller_home.dart';
import 'package:lccu_finx/features/teller/view/teller_dash.dart';
import 'package:lccu_finx/features/teller/view/teller_report.dart';
import 'package:lccu_finx/features/teller/viewmodel/teller_vm.dart';
import 'package:lccu_finx/features/teller/data/teller_repo.dart';
import 'package:lccu_finx/app/supabase_config.dart';
import 'package:lccu_finx/features/web/view/web_shell.dart';
import 'package:lccu_finx/app/adaptive.dart';
import 'package:lccu_finx/features/admin/view/dashboard_shell.dart';
import 'package:lccu_finx/features/settings/view/settings.dart';
import 'package:lccu_finx/features/notifications/data/notification_repo.dart';
import 'package:lccu_finx/features/notifications/viewmodel/notification_vm.dart';
import 'package:lccu_finx/features/notifications/view/notification_bell.dart';

class TellerRouter extends StatefulWidget {
  const TellerRouter({super.key});

  @override
  State<TellerRouter> createState() => _TellerRouterState();
}

class _TellerRouterState extends State<TellerRouter> {
  late final TellerVm _vm;
  late final NotificationVm _notifVm;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _vm = TellerVm(
      repo: SupabaseTellerRepository(supabase, CommonRepository(supabase)),
    );
    _notifVm = NotificationVm(
      repo: SupabaseNotificationRepository(supabase),
    );
    scheduleMicrotask(() => _vm.bootstrap());
    scheduleMicrotask(() => _notifVm.refresh());
  }

  @override
  void dispose() {
    _vm.dispose();
    _notifVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationScope(
      vm: _notifVm,
      child: TellerScope(
        notifier: _vm,
        child: Navigator(
        key: _navKey,
        initialRoute: '/teller/home',
        onGenerateRoute: (settings) {
          final routeName = settings.name ?? '/teller/home';

          late final Widget child;
          switch (routeName) {
            case '/teller/home':
              child = const TellerHome();
              break;
            case '/teller/dash':
              child = _vm.selectedSchoolId == null
                  ? const TellerHome()
                  : const TellerDashboard();
              break;
            case '/teller/report':
              child = const TellerReportScreen();
              break;
            default:
              child = const TellerHome();
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (_) => _wrapInShell(child, routeName),
          );
        },
        ),
      ),
    );
  }

  Widget _wrapInShell(Widget child, String routeName) {
    if (useWebLayout(context)) {
      return WebShell(currentRoute: routeName, child: child);
    }

    return DashboardShell(
      center: child,
      welcomeText: '',
      appBarActions: [
        const NotificationBell(),
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(
                ctx,
              ).push(MaterialPageRoute(builder: (_) => const SettingsAboutPage()));
            },
            tooltip: 'Settings',
          ),
        ),
      ],
    );
  }
}