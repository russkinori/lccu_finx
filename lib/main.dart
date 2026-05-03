import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Imports kept minimal; AuthGate is referenced from Splash route.
import 'splash.dart';
import 'auth_vm.dart';
import 'admin_repo.dart';
import 'supabase_config.dart';
import 'app_theme.dart';
import 'app_logger.dart';
// login UI is provided by AuthGate when not authenticated

Future<void> main() async {
  // Initialize and run within the same zone to avoid the "Zone mismatch" warning
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      appLog('main: Flutter binding initialized');
      // Lock the app to portrait only. This prevents rotation into landscape.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await initSupabase();
      appLog('main: Supabase initialized');
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
      // Production builds should route this to Sentry, Crashlytics, or equivalent.
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
