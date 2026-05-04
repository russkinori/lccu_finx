import 'package:flutter/widgets.dart';
import 'package:lccu_finx/features/web/view/web_shell.dart';
import 'package:lccu_finx/features/admin/view/admin_home.dart' show buildAdminHome;
import 'package:lccu_finx/features/admin/view/admin_register.dart' show buildAdminRegister;
import 'package:lccu_finx/features/admin/view/admin_update.dart' show buildAdminUpdate;
import 'package:lccu_finx/features/admin/view/admin_report.dart' show buildAdminReport;

/// Web-only admin routes. Imported only on web via conditional import.
Map<String, Widget Function(BuildContext)> buildAdminWebRoutes() => {
  '/admin/home': (_) =>
      WebShell(currentRoute: '/admin/home', child: buildAdminHome()),
  '/admin/register': (_) =>
      WebShell(currentRoute: '/admin/register', child: buildAdminRegister()),
  '/admin/update': (_) =>
      WebShell(currentRoute: '/admin/update', child: buildAdminUpdate()),
  '/admin/report': (_) =>
      WebShell(currentRoute: '/admin/report', child: buildAdminReport()),
};
