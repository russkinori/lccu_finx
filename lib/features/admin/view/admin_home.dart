import 'package:flutter/material.dart';
import 'package:responsive_text_widget/responsive_text_widget.dart';

import 'package:lccu_finx/app/app_constants.dart';

import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/app/supabase_config.dart';

import 'package:lccu_finx/features/admin/viewmodel/admin_vm.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  // Provide AppBar actions for AdminHome so the router can delegate action
  // construction to the page itself (keeps action logic colocated with page).
  static List<Widget>? appBarActions(AdminVm vm) {
    return [
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Reload metrics',
        onPressed: vm.isDashboardLoading ? null : () => vm.refreshDashboard(),
      ),
    ];
  }

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  String? _displayName;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AdminScope.of(context, listen: false).refreshDashboard();
      // Load display name for welcome line, similar to teller headers
      CommonRepository(supabase).getCurrentUserDisplayName(fallback: '').then((
        name,
      ) {
        if (!mounted) return;
        setState(() => _displayName = name);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = AdminScope.of(context);
    final metrics = vm.dashboard;
    final loading = vm.isDashboardLoading && metrics == null;
    final error = vm.dashboardError;

    // Build the content widget
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fixed, top-centered header (refresh moved to AppBar actions)
        Center(
          child: SizedBox(
            height: 56,
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Administration Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                // Refresh action has been moved to the AppBar via
                // `AdminHome.appBarActions` so we no longer show an
                // in-body refresh button next to the header.
              ],
            ),
          ),
        ),
        if ((_displayName ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(
                    text: 'Welcome ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: _displayName!,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        // Content area
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  )
                else if (metrics != null)
                  _MetricsGrid(metrics: metrics),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );

    // On mobile (inside DashboardShell's scroll view), return content directly
    // On web (inside WebShell's Expanded widget), wrap in SingleChildScrollView
    // to handle overflow gracefully while filling available space
    return LayoutBuilder(
      builder: (context, constraints) {
        // If we have unbounded height constraints, we're in a scroll view (mobile)
        // If we have bounded height, we're in WebShell's Expanded (web)
        final hasMaxHeight = constraints.maxHeight != double.infinity;

        if (hasMaxHeight) {
          // Web layout: wrap in scroll view to handle overflow
          return SingleChildScrollView(child: content);
        } else {
          // Mobile layout: content flows in parent scroll view
          return content;
        }
      },
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final AdminDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricDefinition(
        label: 'Active Users',
        value: metrics.userCount,
        icon: Icons.people_alt,
        color: AppColors.primaryBlue,
      ),
      _MetricDefinition(
        label: 'Schools',
        value: metrics.schoolCount,
        icon: Icons.school,
        color: AppColors.yellow1,
      ),
      _MetricDefinition(
        label: 'Credit Union Branches',
        value: metrics.creditUnionCount,
        icon: Icons.account_balance,
        color: AppColors.accentGreen,
      ),
      _MetricDefinition(
        label: 'Student Accounts',
        value: metrics.studentAccountCount,
        icon: Icons.savings,
        color: AppColors.accentPurple,
      ),
      _MetricDefinition(
        label: 'Total Student Account Value',
        valueString: '\$${metrics.totalStudentAccountValue.toStringAsFixed(2)}',
        icon: Icons.account_balance_wallet,
        color: AppColors.accentBlue2,
      ),
      _MetricDefinition(
        label: 'Total School Account Value',
        valueString: '\$${metrics.totalSchoolAccountValue.toStringAsFixed(2)}',
        icon: Icons.business,
        color: AppColors.accentRed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final crossAxisCount = maxWidth > 1200
            ? 3
            : maxWidth > 800
            ? 2
            : 1;
        // Use a fixed reasonable card height to avoid MediaQuery conflicts
        // during semantics tree building
        const double computedCardHeight = 180.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            // Use computedCardHeight so cards scale with device size but remain bounded
            mainAxisExtent: computedCardHeight,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _MetricCard(definition: items[index]),
        );
      },
    );
  }
}

class _MetricDefinition {
  const _MetricDefinition({
    required this.label,
    this.value,
    this.valueString,
    required this.icon,
    required this.color,
  }) : assert(
         value != null || valueString != null,
         'Either value or valueString must be provided',
       );

  final String label;
  final int? value;
  final String? valueString;
  final IconData icon;
  final Color color;

  String get displayValue => valueString ?? value.toString();
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.definition});

  final _MetricDefinition definition;

  @override
  Widget build(BuildContext context) {
    // Make the card content responsive to the allocated height. Use a
    // LayoutBuilder so we can size the avatar and text proportionally.
    // Use a white background for metric tiles to match app theming.
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primaryBlue),
      ),
      elevation: 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use available height to select avatar radius and text scaling.
          final h = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 180.0;
          final avatarRadius = (h * 0.14).clamp(18.0, 40.0);
          final labelStyle =
              Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: (h * 0.07).clamp(12.0, 16.0),
                fontWeight: FontWeight.w600,
              ) ??
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
          final valueStyle =
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: (h * 0.16).clamp(20.0, 36.0),
                fontWeight: FontWeight.bold,
              ) ??
              const TextStyle(fontSize: 28, fontWeight: FontWeight.bold);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: definition.color.withValues(alpha: 0.15),
                  child: Icon(
                    definition.icon,
                    color: definition.color,
                    size: avatarRadius,
                  ),
                ),
                SizedBox(height: (h * 0.08).clamp(10.0, 22.0)),
                ResponsiveText(text: definition.label, style: labelStyle),
                SizedBox(height: (h * 0.03).clamp(4.0, 8.0)),
                ResponsiveText(
                  text: definition.displayValue,
                  style: valueStyle,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget buildAdminHome() => const AdminHome();

// (AppBar actions are provided by AdminHome.appBarActions())
