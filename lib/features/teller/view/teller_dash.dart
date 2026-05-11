// teller_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:lccu_finx/features/teller/viewmodel/teller_vm.dart';
import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/features/teller/data/teller_repo.dart';
import 'package:lccu_finx/app/supabase_config.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/core/widgets/friendly_error.dart';

class TellerDashboard extends StatefulWidget {
  const TellerDashboard({super.key});

  @override
  State<TellerDashboard> createState() => _TellerDashboardState();
}

class _TellerDashboardState extends State<TellerDashboard> {
  static const _radius = 12.0;

  final _formKey = GlobalKey<FormState>();

  final _fundsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _payoutAmountCtrl = TextEditingController();
  final _payoutNoteCtrl = TextEditingController();

  String? _displayName;
  String? _selectedTeacherId;
  final Set<String> _selectedBatchIds = {};
  String? _payoutRequestId;

  bool _recordingWithdrawal = false;

  @override
  void dispose() {
    _fundsCtrl.dispose();
    _notesCtrl.dispose();
    _payoutAmountCtrl.dispose();
    _payoutNoteCtrl.dispose();
    super.dispose();
  }

  double get _fundsReceived =>
      double.tryParse(_fundsCtrl.text.replaceAll(',', '')) ?? 0.0;

  /// Discrepancy relative to the batches the teller has chosen to cover.
  /// Expected = sum of selected batches' remaining amounts.
  double _discrepancy(TellerVm vm) {
    if (_selectedBatchIds.isEmpty) return -_fundsReceived;
    final selectedTotal = vm.batches
        .where((b) => _selectedBatchIds.contains(b.batchId))
        .fold(0.0, (sum, b) => sum + b.remainingAmount);
    return selectedTotal - _fundsReceived;
  }

  @override
  Widget build(BuildContext context) {
    final vm = TellerScope.of(context);
    final rows = vm.schools;

    TellerSchoolRow? row;
    if (rows.isNotEmpty) {
      row = rows.firstWhere(
        (r) => r.schoolId == vm.selectedSchoolId,
        orElse: () => rows.first,
      );
    }

    if (_displayName == null) {
      Future.microtask(() async {
        final name = await CommonRepository(supabase)
            .getCurrentUserDisplayName(fallback: '');
        if (!mounted) return;
        setState(() => _displayName = name);
      });
    }

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Teller Dashboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((_displayName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Welcome $_displayName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ================= TABLE =================
                // Use the same batches already loaded into the VM so the
                // card total always matches the batch selector list.
                Builder(
                  builder: (context) {
                    final pendingDeposit = vm.batches.fold(
                      0.0,
                      (sum, b) => sum + b.remainingAmount,
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 500;

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(_radius),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primaryBlue),
                            ),
                            child: isNarrow
                                ? _buildSchoolCard(row, pendingDeposit)
                                : _buildSchoolTable(row, pendingDeposit),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ================= MODE SELECTOR =================
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 500;
                    return isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _recordingWithdrawal ? 'Record Withdrawal' : 'Confirm Deposit',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(value: false, label: Text('Deposit')),
                                  ButtonSegment(value: true, label: Text('Withdrawal')),
                                ],
                                selected: {_recordingWithdrawal},
                                onSelectionChanged: (s) =>
                                    setState(() => _recordingWithdrawal = s.first),
                                showSelectedIcon: false,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Text(
                                _recordingWithdrawal ? 'Record Withdrawal' : 'Confirm Deposit',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(value: false, label: Text('Deposit')),
                                  ButtonSegment(value: true, label: Text('Withdrawal')),
                                ],
                                selected: {_recordingWithdrawal},
                                onSelectionChanged: (s) =>
                                    setState(() => _recordingWithdrawal = s.first),
                                showSelectedIcon: false,
                              ),
                            ],
                          );
                  },
                ),

                const SizedBox(height: 20),

                // ================= FORM =================
                Form(
                  key: _formKey,
                  child: Column(
                    children: _recordingWithdrawal
                        ? _buildWithdrawalForm(vm, row)
                        : _buildDepositForm(vm),
                  ),
                ),

                const SizedBox(height: 20),

                // ================= SUBMIT =================
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _canSubmit(vm, row) ? () => _submit(vm, row) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    child: Text(
                      _recordingWithdrawal ? 'Record Withdrawal' : 'Confirm Deposit',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= SCHOOL TABLE (wide) =================
  Widget _buildSchoolTable(TellerSchoolRow? row, double depositDue) {
    return Column(
      children: [
        Container(
          color: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Row(
            children: [
              _HeaderCell('School', flex: 4),
              _HeaderCell('Account Balance', flex: 4, right: true),
              _HeaderCell('Pending Deposit', flex: 4, right: true),
              _HeaderCell('Disparity', flex: 4, right: true),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  row?.schoolName ?? 'Select a school',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(row == null ? '—' : _formatMoney(row.accountBalance)),
                ),
              ),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(_formatMoney(depositDue)),
                ),
              ),
              const Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('—'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= SCHOOL CARD (narrow / mobile) =================
  Widget _buildSchoolCard(TellerSchoolRow? row, double depositDue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            row?.schoolName ?? 'Select a school',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _CardRow(label: 'Account Balance', value: row == null ? '—' : _formatMoney(row.accountBalance)),
              const Divider(height: 20),
              _CardRow(label: 'Pending Deposit', value: _formatMoney(depositDue)),
              const Divider(height: 20),
              const _CardRow(label: 'Disparity', value: '—'),
            ],
          ),
        ),
      ],
    );
  }

  // ================= DEPOSIT FORM =================
  List<Widget> _buildDepositForm(TellerVm vm) {
    return [
      _teacherDropdown(vm),
      const SizedBox(height: 12),
      _moneyField('Funds Received', _fundsCtrl, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),

      // ✅ RadioGroup-based batch selection (no groupValue/onChanged on each tile)
      _batchSelection(vm),

      const SizedBox(height: 12),
      TextFormField(
        controller: _notesCtrl,
        decoration: const InputDecoration(labelText: 'Notes'),
      ),
    ];
  }

  // ================= WITHDRAWAL FORM =================
  List<Widget> _buildWithdrawalForm(TellerVm vm, TellerSchoolRow? row) {
    return [
      _teacherDropdown(vm, label: 'Withdrawer'),
      const SizedBox(height: 12),
      _moneyField('Amount', _payoutAmountCtrl, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      TextFormField(
        controller: _payoutNoteCtrl,
        decoration: const InputDecoration(labelText: 'Notes'),
      ),
    ];
  }

  Widget _teacherDropdown(TellerVm vm, {String label = 'Depositor'}) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedTeacherId,
      items: vm.teachers
          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
          .toList(),
      onChanged: (v) {
        setState(() => _selectedTeacherId = v);
        vm.selectTeacher(v);
      },
      decoration: InputDecoration(labelText: label),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _moneyField(String label, TextEditingController ctrl, {void Function(String)? onChanged}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        if (n == null || n <= 0) return 'Enter valid amount';
        return null;
      },
    );
  }

  Widget _batchSelection(TellerVm vm) {
    final batches = vm.batches;
    if (batches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No deposit batches have been submitted.\n',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final selectedTotal = batches
        .where((b) => _selectedBatchIds.contains(b.batchId))
        .fold(0.0, (sum, b) => sum + b.remainingAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select batch(es)',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        ...batches.map((b) {
          final week =
              '${DateFormat('MMM d').format(b.weekStart)} – ${DateFormat('MMM d, yyyy').format(b.weekEnd)}';
          final amount = _formatMoney(b.remainingAmount);
          final isChecked = _selectedBatchIds.contains(b.batchId);

          return CheckboxListTile(
            value: isChecked,
            onChanged: (checked) => setState(() {
              if (checked == true) {
                _selectedBatchIds.add(b.batchId);
              } else {
                _selectedBatchIds.remove(b.batchId);
              }
            }),
            title: Text(week),
            subtitle: b.note.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(amount),
                      Text(
                        b.note,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )
                : Text(amount),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
        if (_selectedBatchIds.isNotEmpty) ...[
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected total:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                _formatMoney(selectedTotal),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ================= SUBMIT LOGIC =================
  Future<bool> _confirmDepositDialog(TellerVm vm) async {
    final funds = _fundsReceived;
    final disc = _discrepancy(vm);
    final notes = _notesCtrl.text.trim();
    final depositorName = vm.teachers
        .where((t) => t.id == _selectedTeacherId)
        .map((t) => t.name)
        .firstOrNull ?? '—';

    final confirmed = await showDialog<bool>(
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Depositor: $depositorName',
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Funds Received: ${_formatMoney(funds)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discrepancy: ${_formatMoney(disc)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: disc.abs() > 0.01 ? Colors.red : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notes: ${notes.isEmpty ? '—' : notes}',
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      height: 44,
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
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Confirm',
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
    return confirmed ?? false;
  }

  Future<bool> _confirmWithdrawalDialog(TellerVm vm) async {
    final amount = double.tryParse(_payoutAmountCtrl.text) ?? 0;
    final notes = _payoutNoteCtrl.text.trim();
    final withdrawerName = vm.teachers
        .where((t) => t.id == _selectedTeacherId)
        .map((t) => t.name)
        .firstOrNull ?? '—';

    final confirmed = await showDialog<bool>(
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'RECORD WITHDRAWAL',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdrawer: $withdrawerName',
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Amount: ${_formatMoney(amount)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notes: ${notes.isEmpty ? '—' : notes}',
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      height: 44,
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
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Confirm',
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
    return confirmed ?? false;
  }

  Future<void> _submit(TellerVm vm, TellerSchoolRow? row) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      if (_recordingWithdrawal) {
        final ok = await _confirmWithdrawalDialog(vm);
        if (!ok) return;
        final amount = double.tryParse(_payoutAmountCtrl.text) ?? 0;
        await vm.postSchoolPayout(
          amount: amount,
          requestId: _payoutRequestId ?? vm.generateRequestId(),
          note: _payoutNoteCtrl.text.trim(),
          requestedByTeacherId: _selectedTeacherId,
        );
        _resetPayoutForm();
      } else {
        final ok = await _confirmDepositDialog(vm);
        if (!ok) return;
        await vm.confirmDeposit(
          amount: _fundsReceived,
          discrepancy: _discrepancy(vm),
          notes: _notesCtrl.text.trim(),
          batchIds: _selectedBatchIds.isEmpty ? null : _selectedBatchIds.toList(),
        );
        _resetDepositForm(vm);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Success')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyActionError('Action failed.', e))),
      );
    }
  }

  bool _canSubmit(TellerVm vm, TellerSchoolRow? row) {
    if (_recordingWithdrawal) {
      // Withdrawal: withdrawer selected + amount > 0
      if (_selectedTeacherId == null) return false;
      final amount = double.tryParse(_payoutAmountCtrl.text) ?? 0;
      return amount > 0;
    } else {
      // Deposit: depositor selected + funds received > 0 + batch selected
      if (_selectedTeacherId == null) return false;
      if (_fundsReceived <= 0) return false;
      if (_selectedBatchIds.isEmpty) return false;
      return true;
    }
  }

  void _resetDepositForm(TellerVm vm) {
    _formKey.currentState?.reset();
    _fundsCtrl.clear();
    _notesCtrl.clear();
    _selectedTeacherId = null;
    _selectedBatchIds.clear();
    vm.selectTeacher(null);
    setState(() {});
  }

  void _resetPayoutForm() {
    _formKey.currentState?.reset();
    _payoutAmountCtrl.clear();
    _payoutNoteCtrl.clear();
    _payoutRequestId = null;
    setState(() {});
  }

  String _formatMoney(double n) => '\$${n.toStringAsFixed(2)}';
}

// ================= HEADER CELL =================
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
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final String label;
  final String value;

  const _CardRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
