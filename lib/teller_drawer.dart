import 'package:flutter/material.dart';

import 'auth_vm.dart';
import 'admin_repo.dart';
import 'auth_gate.dart';
import 'supabase_config.dart';
import 'app_constants.dart';

class TellerDrawer extends StatelessWidget {
  const TellerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppColors.primaryBlue),
              child: Center(
                child: Text(
                  'Teller Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/teller/home');
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/teller/dash');
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart_outlined),
              title: const Text('Reports'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/teller/report');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () async {
                try {
                  final auth = AuthScope.of(context, listen: false);
                  await auth.signOut();
                } catch (_) {}

                if (!context.mounted) return;

                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => AuthGate(
                      adminRepo: SupabaseAdminRepo(supabase),
                    ),
                  ),
                  (r) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}