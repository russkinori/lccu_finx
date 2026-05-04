import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lccu_finx/features/auth/view/auth_gate.dart';
import 'package:lccu_finx/features/admin/data/admin_repo.dart';
import 'package:lccu_finx/app/supabase_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.adminRepo});

  final AdminRepo adminRepo;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure we start from a clean signed-out state without blocking the
      // very first frame. Use local scope to avoid a network call.
      try {
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AuthGate(adminRepo: widget.adminRepo),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
