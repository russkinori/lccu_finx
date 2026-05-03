import 'dart:async';

import 'package:flutter/material.dart';

import 'common_repo.dart';
import 'teller_home.dart';
import 'teller_dash.dart';
import 'teller_report.dart';
import 'teller_vm.dart';
import 'teller_repo.dart';
import 'supabase_config.dart';
import 'web_shell.dart';
import 'adaptive.dart';
import 'dashboard_shell.dart';
import 'settings.dart';

class TellerRouter extends StatefulWidget {
  const TellerRouter({super.key});

  @override
  State<TellerRouter> createState() => _TellerRouterState();
}

class _TellerRouterState extends State<TellerRouter> {
  late final TellerVm _vm;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _vm = TellerVm(
      repo: SupabaseTellerRepository(supabase, CommonRepository(supabase)),
    );
    scheduleMicrotask(() => _vm.bootstrap());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TellerScope(
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