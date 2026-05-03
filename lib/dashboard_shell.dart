import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'auth_vm.dart';
import 'auth_gate.dart';
import 'supabase_config.dart';
import 'admin_repo.dart';
import 'app_constants.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    this.center,
    this.pages,
    this.initialPageKey,
    this.welcomeText = 'WELCOME',
    this.maxContentWidth = 760,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    this.drawer,
    this.floatingActionButton,
    this.appBarActions,
  });

  // Center content (e.g., LoginPage)
  final Widget? center;

  // Optional named pages that can be swapped into the center area. If
  // provided, the DashboardShell will show the page identified by
  // `initialPageKey` (or the first key) and allow switching.
  final Map<String, Widget>? pages;

  // The key of the page to show initially when `pages` is provided.
  final String? initialPageKey;

  // Heading text
  final String welcomeText;

  // Max width for center content on large screens
  final double maxContentWidth;

  // Padding for center content
  final EdgeInsetsGeometry padding;

  // Optional FAB
  // Optional drawer shown by a hamburger icon in the top-left of the shell.
  final Widget? drawer;
  // Optional actions to show in the AppBar (useful for role-specific actions)
  final List<Widget>? appBarActions;
  // Optional FAB
  final Widget? floatingActionButton;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  // Hero aspect ratio (width / height). Update if your hero image differs.
  // For the sample you posted: 1550 x 652  =>  1550 / 652 ≈ 2.377
  static const double _heroAR = 1550 / 652;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache to avoid first-frame flicker
    precacheImage(const AssetImage(AppAssets.bgImage), context);
    precacheImage(const AssetImage(AppAssets.icon), context);
    precacheImage(const AssetImage(AppAssets.lccuLogo), context);
  }

  @override
  void initState() {
    super.initState();
  }

  ImageProvider _bgProvider(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Decode close to screen width to save RAM
    return ResizeImage(
      const AssetImage(AppAssets.bgImage),
      width: (size.width * dpr).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final isTeller = auth.isTeller;
    final isAdmin = auth.isAdmin;
    final isAuthenticated = auth.isAuthenticated;
    final isStudent = auth.isStudent;
    final isTeacher = auth.isTeacher;
    final isPrincipal = auth.isPrincipal;
    final isGuardian = auth.isGuardian;
    // Show a role-based hamburger only for Teller/Admin.
    final showRoleNav = isTeller || isAdmin;
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cs = Theme.of(context).colorScheme;
    final isLandscape = size.width > size.height;

    // Height to show the entire hero with BoxFit.contain.
    const double minHero = 100;
    final double maxHero = isLandscape ? 140 : 260;
    final double heroHeight = (size.width / _heroAR)
        .clamp(minHero, maxHero)
        .toDouble();

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double bottomLogoHeight =
        (isLandscape ? 56 : 72) + 8 + 4; // logo height + padding

    return Scaffold(
      appBar: !isAuthenticated
          ? null
          : showRoleNav
          ? AppBar(
              title: Text(isTeller ? 'Teller Console' : 'Admin Console'),
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 3,
              actions: widget.appBarActions,
            )
          : AppBar(
              title: Text(
                isStudent
                    ? 'Student Dashboard'
                    : isTeacher
                    ? 'Teacher Dashboard'
                    : isPrincipal
                    ? 'Principal Dashboard'
                    : isGuardian
                    ? 'Guardian Dashboard'
                    : 'Dashboard',
              ),
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 3,
              actions: widget.appBarActions,
            ),
      drawer: showRoleNav
          ? Drawer(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DrawerHeader(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Image.asset(AppAssets.lccuLogo, height: 56),
                          const SizedBox(height: 8),
                          Text(
                            isTeller ? 'Teller' : 'Admin',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    // Navigation items (teller/admin)
                    if (isTeller) ...[
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text('Home'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/teller/home');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.dashboard),
                        title: const Text('Dashboard'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/teller/dash');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: const Text('Transaction Report'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/teller/report');
                        },
                      ),
                    ] else ...[
                      // Minimal admin links if an admin lands in DashboardShell
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text('Home'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/admin/home');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('Register'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/admin/register');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Update'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/admin/update');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.assessment),
                        title: const Text('Report'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/admin/report');
                        },
                      ),
                    ],
                    const Spacer(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Log out',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        final auth = AuthScope.of(context, listen: false);
                        auth.signOut().whenComplete(() {
                          if (!context.mounted) return;
                          try {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          } catch (_) {}
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            )
          : null,
      // Prevent the Scaffold from resizing when keyboard appears, keeping the
      // bottom logo visually fixed. The scrollable content handles input visibility.
      resizeToAvoidBottomInset: false,
      floatingActionButton: widget.floatingActionButton,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // 1) Full-bleed wallpaper (safe to crop)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: _bgProvider(context),
                    fit: BoxFit.fill,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // 2) Fixed icon row at the top
            // Top icon row. Use SafeArea with a small minimum top padding so we
            // don't call MediaQuery.of(context) directly here (avoids crashes when
            // this build context unexpectedly lacks a MediaQuery ancestor).
            Positioned(
              left: 0,
              right: 0,
              child: SafeArea(
                top: true,
                bottom: false,
                minimum: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    // If a drawer is provided, show a hamburger button to open it.
                    if (widget.drawer != null)
                      Builder(
                        builder: (ctx) {
                          return IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () {
                              try {
                                Scaffold.of(ctx).openDrawer();
                              } catch (_) {}
                            },
                          );
                        },
                      )
                    else
                      const SizedBox(width: 48),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        child: Image.asset(
                          AppAssets.icon,
                          cacheWidth: (size.width * dpr).round(),
                          filterQuality: FilterQuality.high,
                          height: heroHeight,
                        ),
                      ),
                    ),
                    // You can add more widgets to this row if needed
                  ],
                ),
              ),
            ),
            // 3) Foreground scroll view (heading + content + footer)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  top: heroHeight + 16,
                  bottom: bottomLogoHeight + bottomInset,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Heading (only if welcomeText is not empty)
                      if (widget.welcomeText.trim().isNotEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            isLandscape ? 16 : 32,
                            8,
                            isLandscape ? 16 : 32,
                            12,
                          ),
                          child: Text(
                            widget.welcomeText,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface.withValues(alpha: 0.90),
                                ),
                          ),
                        ),

                      // Main content + footer
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: widget.maxContentWidth,
                          ),
                          child: Padding(
                            padding: widget.padding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.center != null) widget.center!,

                                // Push footer to the bottom when there is extra space
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-anchored logo and logout link (outside scrollable area, respects safe area inset)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left: back arrow when logged in, otherwise spacing
                    Builder(
                      builder: (context) {
                        try {
                          final auth = AuthScope.of(context, listen: true);
                          if (auth.isAuthenticated) {
                            return SizedBox(
                              width: 56,
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () {
                                  // Safely pop if possible.
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                            );
                          }
                        } catch (_) {
                          // If AuthScope is not present for some reason, fall back to spacing
                        }
                        return const SizedBox(width: 56);
                      },
                    ),
                    // Center: logo
                    Center(
                      child: Image.asset(
                        AppAssets.lccuLogo,
                        height: isLandscape ? 56 : 72,
                        semanticLabel: 'LCCU logo',
                        cacheWidth: (math.min(300.0, size.width) * dpr).round(),
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    // Right: logout link (only if user is logged in)
                    Builder(
                      builder: (context) {
                        if (widget.welcomeText.trim().isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: 4.0,
                              bottom: 8.0,
                            ),
                            child: GestureDetector(
                              onTap: () async {
                                final auth = AuthScope.of(
                                  context,
                                  listen: false,
                                );
                                await auth.signOut();
                                if (!context.mounted) return;
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => AuthGate(
                                      adminRepo: SupabaseAdminRepo(supabase),
                                    ),
                                  ),
                                  (r) => false,
                                );
                              },
                              child: Text(
                                'Log out',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        } else {
                          return const SizedBox(width: 56);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
