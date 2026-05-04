// lib/screens/principal_dash.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:responsive_text_widget/responsive_text_widget.dart';

import 'package:lccu_finx/features/principal/viewmodel/principal_vm.dart';
import 'package:lccu_finx/features/principal/data/principal_repo.dart';
import 'package:lccu_finx/features/principal/view/principal_home.dart';
import 'package:lccu_finx/features/admin/view/dashboard_shell.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/app/app_utils.dart';

class PrincipalDashboard extends StatefulWidget {
  const PrincipalDashboard({super.key});

  @override
  State<PrincipalDashboard> createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends State<PrincipalDashboard> {
  static const _blue = AppColors.primaryBlue;
  static const _yellow = AppColors.accentYellow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = PrincipalScope.of(context, listen: false);
    if (!vm.isLoading && vm.snapshot == null) {
      Future.microtask(() => vm.bootstrap());
    }
  }

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;

    final vm = PrincipalScope.of(context);
    final teachers = vm.teacherOptions;
    final classes = vm.classOptions;
    final students = vm.studentOptions;
    final contribution = vm.contributionForPeriod;
    final txns = vm.transactions;

    final selectedTeacher = _coerceToValidValue(vm.selectedTeacherId, teachers);
    final selectedClass = _coerceToValidValue(vm.selectedClassId, classes);
    final selectedStudent = _coerceToValidValue(vm.selectedStudentId, students);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () => _exportCsvMobile(vm.exportRows),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _yellow,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: ResponsiveText(
                  text: 'Export',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              flex: 3,
              child: _MiniDropdownCard(
                title: 'Teacher',
                value: selectedTeacher,
                options: teachers,
                roundLeft: true,
                roundRight: false,
                onChanged: (v) {
                  if (v == null) return;
                  vm.setTeacher(v == 'ALL' ? null : v);
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _MiniDropdownCard(
                title: 'Class',
                value: selectedClass,
                options: classes,
                roundLeft: false,
                roundRight: true,
                onChanged: (v) {
                  if (v == null) return;
                  vm.setClass(v == 'ALL' ? null : v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _PillDropdownWithNames(
          label: 'Student',
          value: selectedStudent,
          options: students,
          onChanged: (v) {
            if (v == null) return;
            vm.setStudent(v == 'ALL' ? null : v);
          },
        ),
        const SizedBox(height: 10),

        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _MobileColors.blue),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: _MobileColors.blue,
                child: InkWell(
                  onTap: () async {
                    final r = await _pickPeriodRange(context, vm.range);
                    if (r != null) await vm.setRange(r);
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ResponsiveText(
                            text: 'Period:  ${_formatRange(vm.range)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(height: 1, color: _MobileColors.blue),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 220.0,
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: ResponsiveText(
                        text: 'Contribution For Period',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 28, color: Colors.grey[300]),
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerRight,
                        child: ResponsiveText(
                          text: '\$${contribution.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _PillValueRow(
          label: 'Account Balance',
          value: '\$${vm.filteredAccountBalance.toStringAsFixed(2)}',
          leftWidth: 140.0,
        ),
        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: _MobileColors.blue),
            ),
            child: Column(
              children: [
                Container(
                  height: 40,
                  color: _blue,
                  child: const Row(
                    children: [
                      _HeaderCell('Details', flex: 4),
                      _HeaderCell('Transaction', flex: 4),
                      _HeaderCell('Amount', flex: 3, right: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: _HistoryList(
                    txns: txns,
                    teacherOptions: vm.teacherOptions,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () {
              try {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                  return;
                }
              } catch (_) {}

              final vm = PrincipalScope.of(context, listen: false);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PrincipalScope(
                    notifier: vm,
                    child: const DashboardShell(
                      center: PrincipalHome(),
                      welcomeText: '',
                    ),
                  ),
                ),
              );
            },
            child: ResponsiveText(
              text: 'Home',
              style: const TextStyle(
                letterSpacing: 1.2,
                color: Colors.black45,
                fontSize: 11,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _coerceToValidValue(String value, List<PIdName> options) {
    if (options.any((o) => o.id == value)) return value;
    return options.isNotEmpty ? options.first.id : 'ALL';
  }

  Future<DateTimeRange?> _pickPeriodRange(
    BuildContext context,
    DateTimeRange initial,
  ) async {
    try {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDateRange: initial,
      );
      return picked;
    } catch (_) {
      return null;
    }
  }

  String _formatRange(DateTimeRange r) {
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${f(r.start)} - ${f(r.end)}';
  }

  Future<void> _exportCsvMobile(List<PrincipalSummaryRow> rows) async {
    final vm = PrincipalScope.of(context, listen: false);
    final teacherById = {for (final t in vm.teacherOptions) t.id: t.name};

    final csv = const ListToCsvEncoder().convert([
      ['Date', 'Teacher', 'Class', 'Student', 'Type', 'Amount'],
      ...rows.map(
        (r) => [
          r.date.toIso8601String(),
          teacherById[r.teacherId] ?? r.teacherId,
          r.className,
          r.studentName,
          r.type,
          r.amount.toStringAsFixed(2),
        ],
      ),
    ]);

    final bytes = Uint8List.fromList(csv.codeUnits);
    final params = ShareParams(
      files: [
        XFile.fromData(
          bytes,
          name: 'transaction_history.csv',
          mimeType: 'text/csv',
        ),
      ],
      text: 'Transaction History',
      subject: 'Transaction History',
    );
    await SharePlus.instance.share(params);
  }
}

const double _pillLeftWidth = AppDimensions.pillLeftWidth;

class _PillDropdownWithNames extends StatelessWidget {
  final String label;
  final String value;
  final List<PIdName> options;
  final ValueChanged<String?> onChanged;

  const _PillDropdownWithNames({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = options.any((o) => o.id == value)
        ? value
        : (options.isNotEmpty ? options.first.id : 'ALL');

    return Row(
      children: [
        const _Pill(),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
              border: Border.all(color: _MobileColors.blue),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                icon: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_drop_down),
                ),
                items: options
                    .map(
                      (opt) => DropdownMenuItem<String>(
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
    ).withLabel(label);
  }
}

class _MiniDropdownCard extends StatelessWidget {
  final String title;
  final String value;
  final List<PIdName> options;
  final ValueChanged<String?> onChanged;
  final bool roundLeft;
  final bool roundRight;

  const _MiniDropdownCard({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.roundLeft = true,
    this.roundRight = true,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;
    final safeValue = options.any((o) => o.id == value)
        ? value
        : (options.isNotEmpty ? options.first.id : 'ALL');

    final borderRadius = BorderRadius.only(
      topLeft: roundLeft ? const Radius.circular(radius) : Radius.zero,
      bottomLeft: roundLeft ? const Radius.circular(radius) : Radius.zero,
      topRight: roundRight ? const Radius.circular(radius) : Radius.zero,
      bottomRight: roundRight ? const Radius.circular(radius) : Radius.zero,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _MobileColors.blue),
          borderRadius: borderRadius,
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _MobileColors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: roundLeft ? const Radius.circular(radius) : Radius.zero,
                  topRight: roundRight ? const Radius.circular(radius) : Radius.zero,
                ),
              ),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ResponsiveText(
                text: title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: roundLeft ? const Radius.circular(radius) : Radius.zero,
                  bottomRight: roundRight ? const Radius.circular(radius) : Radius.zero,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: safeValue,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: options
                      .map(
                        (opt) => DropdownMenuItem<String>(
                          value: opt.id,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ResponsiveText(text: opt.name),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _pillLeftWidth,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: _MobileColors.blue,
        borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
      ),
      alignment: Alignment.centerLeft,
      child: const _PillText(),
    );
  }
}

class _PillText extends StatelessWidget {
  const _PillText();

  @override
  Widget build(BuildContext context) {
    final label = _PillLabel.of(context);
    return ResponsiveText(
      text: label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    );
  }
}

class _PillLabel extends InheritedWidget {
  final String label;
  const _PillLabel({required this.label, required super.child});

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PillLabel>()!.label;

  @override
  bool updateShouldNotify(covariant _PillLabel oldWidget) =>
      oldWidget.label != label;
}

extension _WithLabel on Widget {
  Widget withLabel(String label) => _PillLabel(label: label, child: this);
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
            overflow: TextOverflow.ellipsis,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: (Theme.of(context).textTheme.bodyMedium ??
                    const TextStyle())
                .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<PrincipalSummaryRow> txns;
  final List<PIdName> teacherOptions;

  const _HistoryList({
    required this.txns,
    required this.teacherOptions,
  });

  @override
  Widget build(BuildContext context) {
    final byDate = <String, List<PrincipalSummaryRow>>{};
    for (final t in txns) {
      final d = t.date;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(t);
    }

    final teacherById = {for (final t in teacherOptions) t.id: t.name};

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: byDate.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
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
            if (items.isNotEmpty)
              ResponsiveText(
                text: (() {
                  final tid = items.first.teacherId;
                  return tid.isNotEmpty
                      ? (teacherById[tid] ?? 'Former teacher (prev school)')
                      : '—';
                })(),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ..._byClass(items).entries.expand(
              (entry) => [
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: ResponsiveText(
                    text: entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...entry.value.map((t) => _TxnRow(txn: t)),
              ],
            ),
          ],
        );
      },
    );
  }

  Map<String, List<PrincipalSummaryRow>> _byClass(
    List<PrincipalSummaryRow> items,
  ) {
    final map = <String, List<PrincipalSummaryRow>>{};
    for (final t in items) {
      map.putIfAbsent(t.className, () => []).add(t);
    }
    return map;
  }
}

class _TxnRow extends StatelessWidget {
  final PrincipalSummaryRow txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final divider = Container(width: 1, height: 14, color: Colors.black26);
    final amount =
        (txn.amount >= 0 ? '\$' : '-\$') + txn.amount.abs().toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _MobileColors.blue)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: ResponsiveText(
              text: txn.studentName,
              style: Theme.of(context).textTheme.bodyMedium,
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

class _PillValueRow extends StatelessWidget {
  final String label;
  final String value;
  final double leftWidth;
  final TextStyle? _labelStyle;
  final TextStyle? _valueStyle;

  const _PillValueRow({
    required this.label,
    required this.value,
    this.leftWidth = _pillLeftWidth,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  })  : _labelStyle = labelStyle,
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
            style: _labelStyle ??
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
              style: _valueStyle ??
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

class ListToCsvEncoder {
  const ListToCsvEncoder();

  String convert(List<List<String>> rows) {
    String esc(String s) {
      final needs = s.contains(',') || s.contains('\n') || s.contains('"');
      final e = s.replaceAll('"', '""');
      return needs ? '"$e"' : e;
    }

    return rows.map((r) => r.map(esc).join(',')).join('\n');
  }
}

class _MobileColors {
  static const blue = AppColors.primaryBlue;
}