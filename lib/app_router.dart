import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_home.dart';
import 'admin_register.dart';
import 'admin_report.dart';
import 'admin_update.dart';
import 'admin_vm.dart';
import 'auth_vm.dart';
import 'roles.dart';
import 'web_shell.dart';

import 'admin_repo.dart';
import 'adaptive.dart';
import 'dashboard_shell.dart';
import 'settings.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key, required this.role, required this.repo});

  final AppRole role;
  final AdminRepo repo;

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late final AdminVm _adminVm;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  AuthVm? _authVm;

  @override
  void initState() {
    super.initState();
    _adminVm = AdminVm(repo: widget.repo);
    scheduleMicrotask(() => _adminVm.refreshDashboard());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuthScope.of(context);
    if (!identical(auth, _authVm)) {
      _authVm?.removeListener(_handleAuthChange);
      _authVm = auth;
      _authVm?.addListener(_handleAuthChange);
    }
  }

  void _handleAuthChange() {
    if (!mounted) return;
    final auth = _authVm;
    if (auth == null) return;
    if (!auth.isAuthenticated) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _adminVm.dispose();
    _authVm?.removeListener(_handleAuthChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      notifier: _adminVm,
      child: Navigator(
        key: _navKey,
        initialRoute: '/admin/home',
        onGenerateRoute: (settings) {
          final routeName = settings.name ?? '/admin/home';
          late Widget child;
          switch (routeName) {
            case '/admin/home':
              child = const AdminHome();
              break;
            case '/admin/register':
              child = const AdminRegister();
              break;
            case '/admin/update':
              child = const AdminUpdate();
              break;
            case '/admin/report':
              child = const AdminReport();
              break;
            default:
              child = const AdminHome();
              break;
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
    // Mobile: use DashboardShell with hamburger navigation (same as teller)
    // Build actions list with settings icon for all pages, plus refresh for home
    List<Widget> actions = [];
    if (routeName == '/admin/home') {
      // AdminHome provides the refresh button
      final homeActions = AdminHome.appBarActions(_adminVm);
      if (homeActions != null) {
        actions.addAll(homeActions);
      }
    }
    // Add settings icon to all admin pages
    actions.add(
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsAboutPage()));
        },
        tooltip: 'Settings',
      ),
    );
    return DashboardShell(
      center: child,
      welcomeText: '',
      appBarActions: actions,
    );
  }
}
