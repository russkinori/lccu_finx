import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:responsive_text_widget/responsive_text_widget.dart';
import 'package:lccu_finx/features/guardian/viewmodel/guardian_vm.dart';
import 'package:lccu_finx/features/guardian/data/guardian_repo.dart';
import 'package:lccu_finx/app/id_name.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/app/app_utils.dart';

class GuardianDashboard extends StatefulWidget {
  const GuardianDashboard({super.key});

  @override
  State<GuardianDashboard> createState() => _GuardianDashboardState();
}

class _GuardianDashboardState extends State<GuardianDashboard> {
  static const _blue = AppColors.primaryBlue;
  bool _hasInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasInitialized) return; // Prevent repeated calls

    final vm = GuardianScope.of(context, listen: false);
    // Only trigger initial load if not already loaded and not currently loading
    if (!vm.transactionsLoaded && !vm.loadingTransactions) {
      _hasInitialized = true;
      Future.microtask(() => vm.refreshTransactions());
    }
  }

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;
    final vm = GuardianScope.of(context);
    final children = vm.children;
    final transactions = vm.transactions;

    final childOptions = <IdName>[
      const IdName(id: 'ALL', name: 'All Children'),
      ...children.map((c) => IdName(id: c.studentId, name: c.name)),
    ];

    final selectedChildId = vm.selectedChildId ?? 'ALL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        _ChildDropdown(
          value: selectedChildId,
          options: childOptions,
          onChanged: (v) {
            if (v == null) return;
            vm.setSelectedChild(v == 'ALL' ? null : v);
          },
        ),
        const SizedBox(height: 12),

        _BalanceCard(
          balance: vm.selectedChildId != null
              ? children
                    .firstWhere(
                      (c) => c.studentId == vm.selectedChildId,
                      orElse: () =>
                          GuardianChildRow(studentId: '', name: '', balance: 0),
                    )
                    .balance
              : children.fold<double>(0, (sum, c) => sum + c.balance),
        ),
        const SizedBox(height: 16),

        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.primaryBlue),
            ),
            child: Column(
              children: [
                Container(
                  height: 40,
                  color: _blue,
                  child: Row(
                    children: const [
                      _HeaderCell('Details', flex: 4),
                      _HeaderCell('Transaction', flex: 4, right: true),
                      _HeaderCell('Amount', flex: 3, right: true),
                    ],
                  ),
                ),
                if (vm.loadingTransactions)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ResponsiveText(
                        text: 'No transactions found',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: _HistoryList(txns: transactions),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// Fixed width used by the blue left "pill" across multiple rows so labels align
const double _pillLeftWidth = AppDimensions.pillLeftWidth;

class _ChildDropdown extends StatelessWidget {
  final String value;
  final List<IdName> options;
  final ValueChanged<String?> onChanged;

  const _ChildDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primaryBlue;
    return Row(
      children: [
        Container(
          width: _pillLeftWidth,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
          ),
          alignment: Alignment.centerLeft,
          child: ResponsiveText(
            text: 'Child',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
              border: Border.all(color: AppColors.primaryBlue),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_drop_down),
                ),
                items: options
                    .map(
                      (opt) => DropdownMenuItem(
                        value: opt.id,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: ResponsiveText(text: opt.name),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    // Use pill + value row to match teacher/principal design
    const blue = AppColors.primaryBlue;
    return Row(
      children: [
        Container(
          width: _pillLeftWidth,
          height: 48,
          decoration: const BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ResponsiveText(
            text: 'Account Balance',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 48,
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
              text: '\$${balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool right;
  const _HeaderCell(this.text, {this.flex = 1, this.right = false});

  @override
  Widget build(BuildContext context) {
    // Compute a header font size based on overall screen width so
    // all header cells keep consistent sizing across columns.
    final screenWidth = MediaQuery.of(context).size.width;
    double fontSize;
    if (screenWidth < 360) {
      fontSize = 12;
    } else if (screenWidth < 600) {
      fontSize = 14;
    } else {
      fontSize = 16;
    }

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: ResponsiveText(
            text: text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<GuardianTransaction> txns;
  const _HistoryList({required this.txns});

  @override
  Widget build(BuildContext context) {
    final byDate = <String, List<GuardianTransaction>>{};
    for (final t in txns) {
      final d = t.date;
      // Use plain day number without ordinal suffix
      final key = DateFormat('d MMMM yyyy').format(d);
      byDate.putIfAbsent(key, () => []).add(t);
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: byDate.length,
      separatorBuilder: (_, i_) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final date = byDate.keys.elementAt(i);
        final items = byDate[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveText(
              text: date,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...items.map((t) => _TxnRow(txn: t)),
          ],
        );
      },
    );
  }
}

class _TxnRow extends StatelessWidget {
  final GuardianTransaction txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final divider = Container(width: 1, height: 14, color: Colors.black26);
    final amount = '\$${txn.amount.abs().toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: ResponsiveText(text: txn.studentName)),
          divider,
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: ResponsiveText(text: capitalize(txn.type)),
            ),
          ),
          divider,
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: ResponsiveText(
                text: amount,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: txn.amount >= 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
