import 'package:flutter/material.dart';

import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/features/auth/view/auth_gate.dart';
import 'package:lccu_finx/app/supabase_config.dart';
import 'package:lccu_finx/features/admin/data/admin_repo.dart';
import 'package:lccu_finx/features/settings/view/settings.dart';
import 'package:lccu_finx/app/app_constants.dart';

class WebShell extends StatelessWidget {
  final Widget child; // this will hold the routed page (Home, Register, etc.)
  final String? currentRoute;

  const WebShell({super.key, required this.child, this.currentRoute});

  @override
  Widget build(BuildContext context) {
    const double bannerHeight = 90; // reduced banner height per request
    const double iconSize =
        140; // restored to previous size so icon is slightly larger
    // Increase width separately without changing height
    const double iconWidth =
        220; // wider than height to give a stretched/wide look
    final double iconTop = bannerHeight - (iconSize / 2);

    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 900;

    // Shared background image widget
    final background = Positioned.fill(
      child: Image.asset(
        AppAssets.webBg, // fallback to existing background image
        fit: BoxFit.cover,
      ),
    );

    // Determine whether the current user is an admin or teller to show nav links accordingly.
    final authVm = AuthScope.of(context, listen: false);
    final isAdmin = authVm.isAdmin;
    final isTeller = authVm.isTeller;

    if (!isNarrow) {
      // Wide / web layout (unchanged)
      return Scaffold(
        body: Stack(
          children: [
            background,

            // Main content column
            Column(
              children: [
                // Top banner (uses image background)
                Container(
                  height: bannerHeight,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(AppAssets.webBanner),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: LCCU logo and title
                        Row(
                          children: [
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                            ),
                          ],
                        ),

                        // Right: Navigation links for Admin or Teller routes + Settings
                        Row(
                          children: [
                            ..._buildNavForRoute(
                              context,
                              currentRoute ?? '/admin/home',
                              role: isAdmin
                                  ? 'admin'
                                  : (isTeller ? 'teller' : null),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsAboutPage(),
                                  ),
                                );
                              },
                              tooltip: 'Settings',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Main content area (white space)
                // Add a vertical gap between the banner and content for web
                SizedBox(height: 60),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.transparent,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: child, // Routed page content
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Overlapping icon: half over banner, half over content background
            Positioned(
              top: iconTop,
              left: 24,
              child: Image.asset(
                AppAssets.icon,
                height: iconSize,
                width: iconWidth,
                fit: BoxFit.fill,
              ),
            ),

            // Bottom-right logo overlay
            Positioned(
              bottom: 16,
              right: 16,
              child: Image.asset(
                AppAssets.lccuLogo, // e.g. cooperative crest
                height: 60,
              ),
            ),
          ],
        ),
      );
    }

    // Narrow / mobile-friendly admin shell: keep background, icon and logo,
    // but replace horizontal nav with an AppBar + Drawer so navigation remains
    // accessible on small screens.
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppAssets.webBanner),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Image.asset(AppAssets.lccuLogo, height: 48),
                ),
              ),
              // Drawer links: use the same ordering logic, exclude current route.
              // Place main nav items above and keep Log Out pinned to the bottom.
              ..._buildNavForRoute(
                    context,
                    currentRoute ?? '/admin/home',
                    role: isAdmin ? 'admin' : (isTeller ? 'teller' : null),
                  )
                  .where(
                    (w) =>
                        (w is _NavLink && w.title != 'Log Out') ||
                        w is _NavSeparator,
                  )
                  .map((w) {
                    if (w is _NavLink) {
                      return ListTile(title: Text(w.title), onTap: w.onTap);
                    }
                    return const SizedBox.shrink();
                  }),
              const Spacer(),
              // Bottom Log Out
              ListTile(
                title: const Text('Log Out'),
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('LCCU FinX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsAboutPage()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          background,
          // content area
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              ),
            ),
          ),
          Positioned(
            top: iconTop,
            left: 16,
            child: Image.asset(
              AppAssets.icon,
              height: iconSize,
              width: iconWidth,
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Image.asset(AppAssets.lccuLogo, height: 48),
          ),
        ],
      ),
    );
  }

  static void _navigate(BuildContext context, String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }

  static void _logout(BuildContext context) {
    AuthScope.of(context, listen: false).signOut().whenComplete(() {
      // Clear the whole stack and return directly to the AuthGate (login UI).
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthGate(adminRepo: SupabaseAdminRepo(supabase)),
        ),
        (r) => false,
      );
    });
  }

  // Build navigation widgets for the given current route. Each page should
  // not include a link to itself and should follow the ordering requested by
  // the product: Home -> [Register, Update, Report, Log Out],
  // Register -> [Home, Update, Report, Log Out], Update -> [Home, Register, Report, Log Out],
  // Report -> [Home, Register, Update, Log Out].
  List<Widget> _buildNavForRoute(
    BuildContext context,
    String route, {
    String? role,
  }) {
    // If no role was provided (not logged in as admin or teller), do not
    // show navigation links — navigation should only appear after a
    // successful admin/teller login.
    if (role == null) return <Widget>[];

    const home = '/admin/home';
    const reg = '/admin/register';
    const upd = '/admin/update';
    const rpt = '/admin/report';

    const thome = '/teller/home';
    const tdash = '/teller/dash';
    const trep = '/teller/report';

    final orders = <String, List<String>>{
      home: [reg, upd, rpt],
      reg: [home, upd, rpt],
      upd: [home, reg, rpt],
      rpt: [home, reg, upd],
      thome: [tdash, trep],
      tdash: [thome, trep],
      trep: [thome, tdash],
    };

    final list = <Widget>[];
    final isTellerRoute = route.startsWith('/teller/');
    final order =
        orders[route] ??
        (isTellerRoute ? [thome, tdash, trep] : [home, reg, upd, rpt]);
    for (var i = 0; i < order.length; i++) {
      final r = order[i];
      final label = r == home || r == thome
          ? 'Home'
          : r == reg
          ? 'Register'
          : r == upd
          ? 'Update'
          : r == tdash
          ? 'Dashboard'
          : 'Transaction Report';
      list.add(_NavLink(title: label, onTap: () => _navigate(context, r)));
      if (i < order.length - 1) list.add(const _NavSeparator());
    }

    // Always append Log Out at the end
    if (list.isNotEmpty) list.add(const _NavSeparator());
    list.add(_NavLink(title: 'Log Out', onTap: () => _logout(context)));
    return list;
  }
}

class _NavLink extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NavLink({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NavSeparator extends StatelessWidget {
  const _NavSeparator();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 1,
        height: 20,
        color: Colors.white.withValues(alpha: 0.22),
      ),
    );
  }
}
