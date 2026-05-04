import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:responsive_text_widget/responsive_text_widget.dart';
import 'package:lccu_finx/features/teacher/viewmodel/teacher_vm.dart';
import 'package:lccu_finx/features/teacher/data/teacher_repo.dart';
import 'package:lccu_finx/app/id_name.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/app/app_utils.dart';

class TeacherDash extends StatefulWidget {
  const TeacherDash({super.key});

  @override
  State<TeacherDash> createState() => _TeacherDashState();
}

// Fixed width used by the blue left "pill" across multiple rows so labels align
const double _pillLeftWidth = AppDimensions.pillLeftWidth;

class _TeacherDashState extends State<TeacherDash> {
  static const _blue = AppColors.primaryBlue;
  bool _hasBootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasBootstrapped && mounted) {
      _hasBootstrapped = true;
      final vm = TeacherScope.of(context, listen: false);
      if (vm.transactions.isEmpty && !vm.isLoading) {
        Future.microtask(() {
          if (mounted) vm.refresh();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;
    final vm = TeacherScope.of(context);
    final txns = vm.transactions;

    final classOptions = vm.classOptions;
    final studentOptions = vm.studentOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Top filters as per mock
        _PillDropdownId(
          label: 'Class',
          valueId: vm.selectedClassId,
          options: classOptions,
          onChanged: (id) => vm.setClass(id),
        ),
        const SizedBox(height: 8),
        _PillDropdownId(
          label: 'Student',
          valueId: vm.selectedStudentId,
          options: studentOptions,
          onChanged: (id) => vm.setStudent(id),
        ),
        const SizedBox(height: 8),

        // Account Balance card (using funds-in-hand here for now)
        _PillValueRow(
          label: 'Account Balance',
          value: NumberFormat.simpleCurrency(
            decimalDigits: 2,
          ).format(vm.accountBalanceTotal),
          leftWidth: 180.0,
          valueStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
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
                    children: [
                      _HeaderCell('Details', flex: 4),
                      _HeaderCell('Transaction', flex: 4, right: true),
                      _HeaderCell('Amount', flex: 3, right: true),
                    ],
                  ),
                ),
                if (vm.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (txns.isEmpty)
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
                    child: _HistoryList(txns: txns),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PillDropdownId extends StatelessWidget {
  final String label;
  final String valueId; // e.g., 'ALL' or an id
  final List<IdName> options; // expects first option to be 'ALL'
  final ValueChanged<String> onChanged;

  const _PillDropdownId({
    required this.label,
    required this.valueId,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primaryBlue;
    // Map id -> name for quick lookup
    final byId = {for (final o in options) o.id: o.name};
    final display = byId[valueId] ?? 'All';
    return Row(
      children: [
        Container(
          width: _pillLeftWidth,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
          ),
          alignment: Alignment.centerLeft,
          child: ResponsiveText(
            text: label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
              border: Border.all(color: AppColors.primaryBlue),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: display,
                isExpanded: true,
                icon: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_drop_down),
                ),
                items: options
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.name,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(e.name),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (name) {
                  if (name == null) return;
                  final id = options.firstWhere((o) => o.name == name).id;
                  onChanged(id);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PillValueRow extends StatelessWidget {
  final String label;
  final String value;
  final double leftWidth;
  // Styles kept for future extension; prefix underscores to avoid unused parameter lint until used.
  final TextStyle? _labelStyle;
  final TextStyle? _valueStyle;
  const _PillValueRow({
    required this.label,
    required this.value,
    this.leftWidth = _pillLeftWidth,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) : _labelStyle = labelStyle,
       _valueStyle = valueStyle;

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primaryBlue;
    return Row(
      children: [
        Container(
          width: leftWidth,
          height: 44,
          decoration: const BoxDecoration(
            color: blue,
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

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool right;
  const _HeaderCell(this.text, {this.flex = 1, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: ResponsiveText(
            text: text,
            style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<TeacherTxRow> txns;
  const _HistoryList({required this.txns});

  @override
  Widget build(BuildContext context) {
    final byDate = <String, List<TeacherTxRow>>{};
    for (final t in txns) {
      final d = t.date;
      final key = DateFormat('MMMM d yyyy').format(d);
      byDate.putIfAbsent(key, () => []).add(t);
    }

    // Sort dates in descending order (latest first) by comparing the first transaction date in each group
    final dates = byDate.keys.toList()
      ..sort((a, b) {
        final dateA = byDate[a]!.first.date;
        final dateB = byDate[b]!.first.date;
        return dateB.compareTo(dateA); // descending
      });
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: dates.length,
      separatorBuilder: (_, i_) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final date = dates[i];
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
  final TeacherTxRow txn;
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
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                txn.studentName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          divider,
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: ResponsiveText(
                text: capitalize(txn.type),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
