// principal_reconcile.dart
//
// Principal Reconciliation Screen
// Shows teacher collections for the previous week and allows principal to
// review physical cash on-site and submit deposit batch to teller

import 'package:flutter/material.dart';
import 'app_logger.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'principal_repo.dart';
import 'dashboard_shell.dart';
import 'app_constants.dart';
import 'widgets.dart';
import 'friendly_error.dart';


class PrincipalReconcileScreen extends StatefulWidget {
  final String schoolId;
  final SupabasePrincipalRepository repo;

  const PrincipalReconcileScreen({
    super.key,
    required this.schoolId,
    required this.repo,
  });

  @override
  State<PrincipalReconcileScreen> createState() =>
      _PrincipalReconcileScreenState();
}

class _PrincipalReconcileScreenState extends State<PrincipalReconcileScreen> {
  List<TeacherCollectionItem>? _collections;
  bool _loading = true;
  String? _error;
  final _noteController = TextEditingController();
  DateTime? _selectedWeekStart;

  @override
  void initState() {
    super.initState();
    // Default to the current reconciliation week (Sunday-start week).
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
    _selectedWeekStart = DateTime(
      currentWeekStart.year,
      currentWeekStart.month,
      currentWeekStart.day,
    );
    _loadCollections();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCollections() async {
    if (_selectedWeekStart == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      appLog('[RECON] _loadCollections: schoolId=${widget.schoolId} weekStart=$_selectedWeekStart');
      final collections =
          await widget.repo.getTeacherCollectionsForReconciliation(
        schoolId: widget.schoolId,
        weekStart: _selectedWeekStart!,
      );
      appLog('[RECON] _loadCollections: got ${collections.length} rows');
      for (final c in collections) {
        appLog('[RECON]   teacher=${c.teacherId} weekStart=${c.weekStart} remaining=${c.remainingAmount}');
      }

      if (mounted) {
        setState(() {
          _collections = collections;
          _loading = false;
        });
      }
    } catch (e, st) {
      appLogError(e, st);
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitDeposit() async {
    if (_collections == null || _collections!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No collections to deposit')),
      );
      return;
    }

    // Show confirmation dialog using popup background
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage(AppAssets.popupBg),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Confirm Deposit Submission',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Week: ${DateFormat('MMM d').format(_selectedWeekStart!)} - ${DateFormat('MMM d, yyyy').format(_selectedWeekStart!.add(const Duration(days: 6)))}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total Amount: \$${_calculateTotal().toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This will submit ${_collections!.where((c) => c.remainingAmount > 0).length} teacher collection(s) for deposit.',
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Are you sure you want to proceed?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 330;

                      final cancelButton = TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.primaryBlue),
                        ),
                      );

                      final submitButton = GradientTextButton(
                        onPressed: () => Navigator.pop(context, true),
                        text: 'Submit Deposit',
                        gradient: AppGradients.yellowGradient,
                        width: isNarrow ? double.infinity : 180,
                        height: 44,
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            submitButton,
                            const SizedBox(height: 8),
                            cancelButton,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(child: cancelButton),
                          const SizedBox(width: 8),
                          submitButton,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    // Use the week_start that came back from the DB (canonical dep_batch convention)
    // rather than the UI-computed _selectedWeekStart (which may differ by a day
    // due to Sunday vs Monday week-start conventions). submit_dep_batch does an
    // exact match on dep_batch.week_start, so they must agree.
    final batchWeekStart = _collections!.isNotEmpty
        ? _collections!.first.weekStart
        : _selectedWeekStart!;

    appLog('[RECON] submitDepositBatch: schoolId=${widget.schoolId} batchWeekStart=$batchWeekStart selectedWeekStart=$_selectedWeekStart');
    try {
      final result = await widget.repo.submitDepositBatch(
        schoolId: widget.schoolId,
        weekStart: batchWeekStart,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      appLog('[RECON] submitDepositBatch result: "$result"');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deposit batch submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Return to previous screen
      }
    } catch (e, st) {
      appLogError(e, st);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyActionError('Failed to submit deposit.', e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _calculateTotal() {
    if (_collections == null) return 0.0;
    return _collections!
        .fold(0.0, (sum, c) => sum + c.remainingAmount);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      welcomeText: '',
      center: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCollections,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // (title removed per UI request)

                      // Week selector
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryBlue, width: 1.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                color: AppColors.primaryBlue,
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: const Center(
                                  child: Text(
                                    'Deposit Week',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedWeekStart!,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                      selectableDayPredicate: (date) {
                                        // Only allow Sundays
                                        return date.weekday == DateTime.sunday;
                                      },
                                      builder: (context, child) => Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: AppColors.primaryBlue,
                                            onSurface: Colors.black87,
                                          ),
                                            dialogTheme: Theme.of(context)
                                                .dialogTheme
                                                .copyWith(backgroundColor: Colors.transparent),
                                        ),
                                        child: child!,
                                      ),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedWeekStart = picked);
                                      _loadCollections();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _selectedWeekStart == null
                                                ? 'Select week'
                                                : '${DateFormat('MMM d').format(_selectedWeekStart!)} - ${DateFormat('MMM d, yyyy').format(_selectedWeekStart!.add(const Duration(days: 6)))}',
                                            style: const TextStyle(fontSize: 16, color: Colors.black),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(Icons.calendar_today),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Teacher collections list
                      if (_collections == null || _collections!.isEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryBlue, width: 1.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No collections found for selected week',
                                    style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Single card with all teachers
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryBlue, width: 1.0),
                                ),
                                child: Column(
                                  children: [
                                    // Header
                                    Container(
                                      color: AppColors.primaryBlue,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Teacher Collections',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Column headers
                                    Container(
                                      color: AppColors.primaryBlueLighter,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: AutoSizeText(
                                              'Teacher',
                                              textAlign: TextAlign.left,
                                              maxLines: 1,
                                              minFontSize: 9,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 1,
                                            child: ColoredBox(color: Colors.white),
                                          ),
                                          Expanded(
                                            child: AutoSizeText(
                                              'Batch',
                                              textAlign: TextAlign.right,
                                              maxLines: 1,
                                              minFontSize: 9,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 1,
                                            child: ColoredBox(color: Colors.white),
                                          ),
                                          Expanded(
                                            child: AutoSizeText(
                                              'Added',
                                              textAlign: TextAlign.right,
                                              maxLines: 1,
                                              minFontSize: 9,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 1,
                                            child: ColoredBox(color: Colors.white),
                                          ),
                                          Expanded(
                                            child: AutoSizeText(
                                              'Remain',
                                              textAlign: TextAlign.right,
                                              maxLines: 1,
                                              minFontSize: 9,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Teacher rows
                                    Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        children: _collections!.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final collection = entry.value;
                                          final isLast = index == _collections!.length - 1;
                                          return _TeacherCollectionRow(
                                            collection: collection,
                                            showDivider: !isLast,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Total summary
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryBlue, width: 1.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      color: AppColors.primaryBlue,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Total Deposit Amount',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      child: AutoSizeText(
                                        '\$${_calculateTotal().toStringAsFixed(2)}',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        minFontSize: 12,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Notes field
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryBlue, width: 1.0),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      color: AppColors.primaryBlue,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Notes (Optional)',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.all(12),
                                      child: TextField(
                                        controller: _noteController,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Add any notes about this deposit...',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        maxLines: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit button (match Principal Home's Transaction History)
                            GradientTextButton(
                              onPressed: _calculateTotal() > 0 ? _submitDeposit : null,
                              text: 'Submit Deposit Batch',
                              gradient: AppGradients.yellowGradient,
                            ),

                            const SizedBox(height: 8),

                            AutoSizeText(
                              'This will create a deposit batch for the teller to process',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              minFontSize: 9,
                              style: const TextStyle(
                                fontSize: 12, color: Colors.black),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _TeacherCollectionRow extends StatelessWidget {
  final TeacherCollectionItem collection;
  final bool showDivider;

  const _TeacherCollectionRow({
    required this.collection,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AutoSizeText(
                    collection.teacherName,
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    minFontSize: 9,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AutoSizeText(
                    '\$${collection.batchedPendingAmount.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    minFontSize: 9,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: collection.batchedPendingAmount > 0 ? Colors.orange.shade700 : Colors.grey[700],
                      fontWeight: collection.batchedPendingAmount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AutoSizeText(
                    '\$${collection.depositedAmount.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    minFontSize: 9,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AutoSizeText(
                    '\$${collection.remainingAmount.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    minFontSize: 10,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: collection.remainingAmount > 0
                        ? Colors.black
                        : Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: Colors.grey[300]),
      ],
    );
  }
}
