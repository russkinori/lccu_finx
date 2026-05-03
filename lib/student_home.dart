// student_home.dart
//
// Mobile-only “Student Home” screen (use inside DashboardShell).
// Matches your mock:
// - Welcome header (student name)
// - Blue-pill "Account Balance" with right-aligned amount
// - Card: Transaction History (Date | Transaction | Amount)
// - Card: Withdrawal Request (Time | Status | Amount)
// - Yellow gradient button: Request Withdrawal

import 'package:flutter/material.dart';
import 'package:responsive_text_widget/responsive_text_widget.dart';
import 'student_vm.dart';
import 'app_constants.dart';
import 'app_utils.dart';

import 'app_logger.dart';
import 'friendly_error.dart';
class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    // DEBUG: Print when StudentHome is built
    // ignore: avoid_print
    appLog('StudentHome.build called');

    final vm = StudentScope.of(context);

    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      // Show a visible error banner at the top of the screen
      return Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.red.shade100,
            padding: const EdgeInsets.all(12),
            child: Text(
              'Error: ${vm.error}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: vm.refresh, child: const Text('Retry')),
        ],
      );
    }

    final snapshot = vm.snapshot;
    final balance = snapshot?.balance ?? 0.0;
    final history = snapshot?.transactions ?? const <dynamic>[];
    final latest = snapshot?.latestWithdrawal;

    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'WELCOME',
          style: TextStyle(letterSpacing: 1.2, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          vm.studentName,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),

        // Account Balance pill row
        _PillValueRow(label: 'Account Balance', value: formatMoney(balance)),

        const SizedBox(height: 12),

        // Transaction History card
        _BlueCard(
          title: 'Transaction History',
          headerCells: const ['Date', 'Transaction', 'Amount'],
          headerFlexes: const [4, 4, 4],
          body: ListView.separated(
            itemCount: history.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, i_) =>
                const Divider(height: 1, color: AppColors.primaryBlue),
            itemBuilder: (_, i) {
              final t = history[i];
              final date = t.createdAt is DateTime
                  ? _fmtDate(t.createdAt as DateTime)
                  : (t.date ?? '');
              final txType = t.transaction ?? t.type ?? '';
              final amt = (t.amount as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Center(child: ResponsiveText(text: date)),
                    ),
                    _vDiv(),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: ResponsiveText(text: capitalize(txType)),
                      ),
                    ),
                    _vDiv(),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: ResponsiveText(
                          text: formatMoney(amt),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: amt >= 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Withdrawal Request card (latest)
        _BlueCard(
          title: 'Withdrawal Request',
          headerCells: const ['Time', 'Status', 'Amount'],
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: ResponsiveText(
                    text: latest?.requestedAt != null
                        ? _fmtDate(latest!.requestedAt)
                        : '-',
                  ),
                ),
                _vDiv(),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: ResponsiveText(
                      text: latest?.status != null
                          ? capitalize(latest!.status)
                          : '-',
                    ),
                  ),
                ),
                _vDiv(),
                Expanded(
                  flex: 4,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ResponsiveText(
                      text: formatMoney(latest?.amount ?? 0.0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Request Withdrawal button
        SizedBox(
          width: 230,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.yellowGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => _showRequestDialog(context, vm),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                foregroundColor: Colors.white,
              ),
              child: const Center(child: Text('Request Withdrawal')),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  static Future<void> _showRequestDialog(
    BuildContext context,
    StudentVm vm,
  ) async {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage(AppAssets.popupBg),
              fit: BoxFit.fill,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Request Withdrawal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show current available balance above the amount input
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Text(
                              'Available balance:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formatMoney(vm.snapshot?.balance ?? 0.0),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextFormField(
                        controller: amtCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          labelStyle: TextStyle(color: Colors.black54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black26),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black87),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Enter an amount';
                          final n = double.tryParse(s);
                          if (n == null || n <= 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: noteCtrl,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          labelStyle: TextStyle(color: Colors.black54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black26),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black87),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.of(ctx).pop(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow1,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true) return;

    final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
    try {
      await vm.requestWithdrawal(amount: amt, note: noteCtrl.text.trim());
      messenger.showSnackBar(
        const SnackBar(content: Text('Withdrawal requested')),
      );
      await vm.refresh();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyActionError('Failed to request withdrawal.', e))),
      );
    }
  }
}

// Fixed width used by the blue left "pill" across multiple rows so labels align
const double _pillLeftWidth = AppDimensions.pillLeftWidth;

// ---------- Reusable bits ----------

class _PillValueRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? _labelStyle;
  final TextStyle? _valueStyle;
  const _PillValueRow({
    required this.label,
    required this.value,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) : _labelStyle = labelStyle,
       _valueStyle = valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: _pillLeftWidth,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ResponsiveText(
            text: label,
            style:
                _labelStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.primaryBlue),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ResponsiveText(
              text: value,
              style:
                  _valueStyle ??
                  const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlueCard extends StatelessWidget {
  final String title;
  final List<String> headerCells;
  final List<int>? headerFlexes;
  final Widget body;
  const _BlueCard({
    required this.title,
    required this.headerCells,
    required this.body,
    this.headerFlexes,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.primaryBlue),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(
                child: ResponsiveText(
                  text: title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Container(
              height: 36,
              color: AppColors.primaryBlueLighter,
              child: Row(
                children: [
                  for (int i = 0; i < headerCells.length; i++) ...[
                    Expanded(
                      flex: (headerFlexes != null && headerFlexes!.length > i)
                          ? headerFlexes![i]
                          : 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.center,
                          child: ResponsiveText(
                            text: headerCells[i],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (i < headerCells.length - 1) _vDiv(),
                  ],
                ],
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}

// demo helper classes were removed; this file now consumes live data from StudentVm

Widget _vDiv() => Container(width: 1, height: 14, color: Colors.black26);

// ===== Helpers =====
// (Title/case helpers centralized in app_utils.dart)
