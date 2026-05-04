import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Imports kept minimal; AuthGate is referenced from Splash route.
import 'package:lccu_finx/core/widgets/splash.dart';
import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/features/admin/data/admin_repo.dart';
import 'package:lccu_finx/app/supabase_config.dart';
import 'package:lccu_finx/app/app_theme.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';
// login UI is provided by AuthGate when not authenticated

Future<void> main() async {
  // Supabase must be initialised before the zone is created so that any
  // credential/network error surfaces immediately rather than being silently
  // swallowed by runZonedGuarded's error handler.
  WidgetsFlutterBinding.ensureInitialized();
  appLog('main: Flutter binding initialized');
  // Lock the app to portrait only. This prevents rotation into landscape.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await initSupabase();
  appLog('main: Supabase initialized');

  await runZonedGuarded(
    () async {
      final repo = SupabaseAdminRepo(supabase);
      appLog('main: SupabaseAdminRepo created');
      final authVm = AuthVm(client: supabase, adminRepo: repo);
      appLog('main: AuthVm created');

      // Global error handling: route Flutter framework errors into the current zone
      FlutterError.onError = (FlutterErrorDetails details) {
        // Forward to the zone's uncaught error handler so runZonedGuarded catches it
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.current,
        );
      };

      runApp(AppRoot(authVm: authVm, adminRepo: repo));
      appLog('main: runApp called');
    },
    (error, stack) {
      // TODO: integrate a crash reporter (e.g. Sentry.captureException or
      // FirebaseCrashlytics.instance.recordError) before Play Store release.
      appLogError(error, stack);
    },
  );
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.authVm, required this.adminRepo});

  final AuthVm authVm;
  final AdminRepo adminRepo;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void dispose() {
    widget.authVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    appLog('AppRoot: build called');

    return AuthScope(
      notifier: widget.authVm,
      child: MaterialApp(
        title: 'LCCU FinX',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // Make text responsive by adjusting the MediaQuery.textScaleFactor according to
        // screen width. This scales all Text widgets (including those with explicit
        // fontSize) without changing every file.
        builder: (context, child) {
          final size = MediaQuery.sizeOf(context);
          // Base design width is 380. Scale factor clamped to reasonable bounds.
          final scale = (size.width / 380).clamp(0.85, 1.4);
          final mq = MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale));
          return MediaQuery(data: mq, child: child ?? const SizedBox.shrink());
        },
        // Show a tiny splash first to keep the first frame light; it will
        // immediately perform a post-frame sign-out and route to AuthGate.
        home: SplashScreen(adminRepo: widget.adminRepo),
      ),
    );
  }
}
