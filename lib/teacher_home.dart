// teacher_home.dart
//
// Mobile-only “Teacher Home” screen (to be centered inside DashboardShell).
// Matches your mock:
// - Welcome header
// - Left-pill bars: Funds In-Hand (value on right), Class dropdown, Student dropdown, Account Balance (value on right)
// - Blue card “Withdrawal Request” with row: Time | Status | Amount
// - Two yellow gradient buttons side-by-side: Transaction History, Submit Deposit

import 'package:flutter/material.dart';
import 'friendly_error.dart';
import 'package:intl/intl.dart';
import 'package:responsive_text_widget/responsive_text_widget.dart';
import 'teacher_vm.dart';
import 'id_name.dart';
import 'teacher_dash.dart';
import 'teacher_repo.dart';
import 'dashboard_shell.dart';
import 'app_constants.dart';
import 'app_utils.dart';
import 'widgets.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key, this.teacherName = 'John Doe'});
  final String teacherName;

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  String? _selectedClassId;
  String? _selectedStudentId;

  // Legacy sample data removed; real data comes from VM.

  @override
  Widget build(BuildContext context) {
    final vm = TeacherScope.of(context);
    // Lazy bootstrap if not already loaded
    if (vm.snapshot == null && !vm.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => vm.bootstrap());
    }

    final classOptions = vm.classOptions; // includes 'ALL'
    final studentOptions = vm.studentOptions; // includes 'ALL'
    _selectedClassId ??= vm.selectedClassId;
    _selectedStudentId ??= vm.selectedStudentId;

    final fundsInHand = vm.scopedBalance; // weekly deposits sum
    final acctTotal =
        vm.accountBalanceTotal; // sum of student balances (filtered)

    return Column(
      children: [
        WelcomeHeader(name: vm.teacherName),

        // Funds In-Hand (pill + value on right)
        _PillValueRow(
          label: 'Funds In-Hand',
          value: formatMoney(fundsInHand),
          leftWidth: 180.0,
        ),
        const SizedBox(height: 8),

        // Class dropdown
        _PillDropdownId(
          label: 'Class',
          valueId: _selectedClassId ?? 'ALL',
          options: classOptions,
          onChanged: (id) async {
            setState(() => _selectedClassId = id);
            await vm.setClass(id);
          },
        ),
        const SizedBox(height: 8),

        // Student dropdown
        _PillDropdownId(
          label: 'Student',
          valueId: _selectedStudentId ?? 'ALL',
          options: studentOptions,
          onChanged: (id) async {
            setState(() => _selectedStudentId = id);
            await vm.setStudent(id);
          },
        ),
        const SizedBox(height: 8),

        // Account Balance (pill + value on right)
        _PillValueRow(
          label: 'Account Balance',
          value: formatMoney(acctTotal),
          leftWidth: 180.0,
        ),
        const SizedBox(height: 12),

        // Withdrawal Request card (latest) -> tap to open all
        _WithdrawalCardLatest(),

        const SizedBox(height: 14),

        // Action buttons row
        Row(
          children: [
            Expanded(
              child: _YellowButton(
                text: 'Transactions',
                onPressed: () {
                  // Follow the guardian pattern: push a DashboardShell containing TeacherDash
                  final vm = TeacherScope.of(context, listen: false);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeacherScope(
                        notifier: vm,
                        child: Builder(
                          builder: (ctx) => DashboardShell(
                            key: ValueKey(
                              'teacher_dash_${DateTime.now().millisecondsSinceEpoch}',
                            ),
                            center: const TeacherDash(),
                            welcomeText: '',
                            appBarActions: [
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  final teacherVm = TeacherScope.of(
                                    ctx,
                                    listen: false,
                                  );
                                  teacherVm.refresh();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _YellowButton(
                text: 'Submit Deposit',
                onPressed: () async {
                  // Open deposit dialog with popup_bg background
                  final vm = TeacherScope.of(context, listen: false);
                  await showDialog(
                    context: context,
                    builder: (_) => TeacherScope(
                      notifier: vm,
                      child: _DepositSheet(
                        classOptions: classOptions,
                        studentOptions: studentOptions,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// ===== Widgets =====

class _PillValueRow extends StatelessWidget {
  final String label;
  final String value;
  final double leftWidth;
  final TextStyle? _labelStyle;
  final TextStyle? _valueStyle;
  const _PillValueRow({
    required this.label,
    required this.value,
    this.leftWidth = AppDimensions.pillLeftWidth,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) : _labelStyle = labelStyle,
       _valueStyle = valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: leftWidth,
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

// Old string-based dropdown removed; replaced by _PillDropdownId that works with IdName options.

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
    // Map id -> name for quick lookup
    final byId = {for (final o in options) o.id: o.name};
    final display = byId[valueId] ?? 'All';
    return Row(
      children: [
        Container(
          width: AppDimensions.pillLeftWidth,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: AppColors.primaryBlue,
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

// (Old _WithdrawalCard removed; replaced by _WithdrawalCardLatest that reads from VM.)

class _WithdrawalCardLatest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = TeacherScope.of(context);
    final latest = vm.highlightedWithdrawal;
    const radius = 12.0;

    return InkWell(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              TeacherScope(notifier: vm, child: const _AllWithdrawalsSheet()),
        );
      },
      child: ClipRRect(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Center(
                  child: ResponsiveText(
                    text: 'Withdrawal Request',
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
                    _HeaderCell('Date', flex: 4),
                    _HeaderCell('Status', flex: 4),
                    _HeaderCell('Amount', flex: 4, right: true),
                  ],
                ),
              ),
              if (latest == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No withdrawal requests'),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: ResponsiveText(
                          text: DateFormat(
                            'dd.MM.yyyy',
                          ).format(latest.requestedAt),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      _vDivider(),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: ResponsiveText(
                            text: capitalize(latest.status),
                          ),
                        ),
                      ),
                      _vDivider(),
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ResponsiveText(
                            text: '\$${latest.amount.toStringAsFixed(2)}',
                            style:
                                (Theme.of(context).textTheme.bodyMedium ??
                                        const TextStyle())
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
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
      ),
    );
  }

  // (second build() removed)
}

class _YellowButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _YellowButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            foregroundColor: Colors.white,
          ),
          child: Center(child: Text(text)),
        ),
      ),
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
          alignment: right ? Alignment.centerRight : Alignment.center,
          child: ResponsiveText(
            text: text,
            style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                .copyWith(fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

// ===== Helpers =====

// (Title/case helpers centralized in app_utils.dart)

// (Old _Withdrawal model removed; using TeacherPendingWithdrawal from repository.)

Widget _vDivider() => Container(width: 1, height: 14, color: Colors.black26);

class _DepositSheet extends StatefulWidget {
  final List<IdName> classOptions;
  final List<IdName> studentOptions;
  const _DepositSheet({
    required this.classOptions,
    required this.studentOptions,
  });

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _AllWithdrawalsSheet extends StatelessWidget {
  const _AllWithdrawalsSheet();

  @override
  Widget build(BuildContext context) {
    final vm = TeacherScope.of(context, listen: false);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: FutureBuilder(
              future: vm.getAllWithdrawals(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed: ${snap.error}'),
                    ),
                  );
                }
                final items =
                    (snap.data as List?)?.cast<TeacherPendingWithdrawal>() ??
                    const [];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No withdrawal requests'),
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, i_) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final w = items[i];
                    final amount = '\$${w.amount.toStringAsFixed(2)}';
                    return Row(
                      children: [
                        // Student name + requested date below
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd.MM.yy').format(w.requestedAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _vDivider(),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: () {
                              final raw = w.status;
                              final upper = raw.toUpperCase();
                              final display = capitalize(raw);
                              if (upper == 'APPROVED') {
                                return TextButton(
                                  onPressed: () async {
                                    await vm.completeWithdrawal(w.requestId);
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text('Approved (Complete)'),
                                );
                              }
                              return Text(display);
                            }(),
                          ),
                        ),
                        _vDivider(),
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              amount,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// _fmtTime removed — teacher view now shows date (dd/MM/yyyy) instead of hh.mm.ss

class _DepositSheetState extends State<_DepositSheet> {
  String? _studentId = 'ALL';
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = TeacherScope.of(context);
    final students = widget.studentOptions;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage(AppAssets.popupBg),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'SUBMIT DEPOSIT',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Student dropdown
                _PillDropdownId(
                  label: 'Student',
                  valueId: _studentId ?? 'ALL',
                  options: students,
                  onChanged: (id) => setState(() => _studentId = id),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                      child: const Text('Cancel'),
                    ),
                    SizedBox(
                      width: 160,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppGradients.yellowGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  final id = _studentId;
                                  final amt = double.tryParse(
                                    _amountCtrl.text.trim(),
                                  );
                                  final note = _noteCtrl.text.trim();
                                  if (id == null ||
                                      id == 'ALL' ||
                                      amt == null ||
                                      amt <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Select a student and enter a valid amount',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  // Resolve student display name from options
                                  final student = students.firstWhere(
                                    (s) => s.id == id,
                                    orElse: () => const IdName(
                                      id: 'UNKNOWN',
                                      name: 'Student',
                                    ),
                                  );

                                  // Confirm details with the teacher before submitting
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 400,
                                        ),
                                        decoration: BoxDecoration(
                                          image: const DecorationImage(
                                            image: AssetImage(
                                              AppAssets.popupBg,
                                            ),
                                            fit: BoxFit.fill,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'CONFIRM DEPOSIT',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  letterSpacing: 2.0,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Student: ${student.name}',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Amount: \$${amt.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Note: ${note.isEmpty ? '—' : note}',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(false),
                                                    child: const Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    width: 140,
                                                    height: 44,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        gradient: AppGradients
                                                            .yellowGradient,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        boxShadow: const [
                                                          BoxShadow(
                                                            color:
                                                                Colors.black12,
                                                            blurRadius: 4,
                                                            offset: Offset(
                                                              0,
                                                              2,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(true),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                          shadowColor: Colors
                                                              .transparent,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                        child: const Text(
                                                          'Confirm',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );

                                  if (confirmed != true) return;

                                  setState(() => _submitting = true);
                                  try {
                                    await vm.createDeposit(
                                      studentId: id,
                                      amount: amt,
                                      note: note.isEmpty ? null : note,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Deposit submitted'),
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(friendlyActionError('Action failed.', e))),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _submitting = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
