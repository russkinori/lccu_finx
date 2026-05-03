import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'utils/download_helper.dart' as dl;
import 'app_constants.dart';
import 'admin_repo.dart';
import 'admin_vm.dart';
import 'common_repo.dart';
import 'supabase_config.dart';
import 'roles.dart';
import 'friendly_error.dart';

class AdminReport extends StatefulWidget {
  const AdminReport({super.key, this.showHeader = true});

  // When false, hides the built-in 'Reports' title so parent screens
  // can provide their own header.
  final bool showHeader;

  @override
  State<AdminReport> createState() => _AdminReportState();
}

Widget buildAdminReport() => const AdminReport();

class _AdminReportState extends State<AdminReport> {
  String? _displayName;
  final _formKey = GlobalKey<FormState>();
  final _teacherController = TextEditingController();
  final _studentController = TextEditingController();

  // Report type templates
  final _reportTypes = const <IdName>[
    IdName(id: 'all_transactions', name: 'All Transactions'),
    IdName(id: 'all_schools', name: 'All Schools Summary'),
    IdName(id: 'all_students', name: 'All Students Activity'),
    IdName(id: 'school_deposits', name: 'School Deposits'),
    IdName(id: 'teacher_activity', name: 'Teacher Activity'),
    IdName(id: 'student_activity', name: 'Student Activity'),
    IdName(id: 'class_summary', name: 'Class Summary'),
    IdName(id: 'custom', name: 'Custom Report'),
  ];

  final _transactionTypes = const <IdName>[
    IdName(id: 'all', name: 'All Transactions'),
    IdName(id: 'deposit', name: 'Deposits'),
    IdName(id: 'withdrawal', name: 'Withdrawals'),
    IdName(id: 'count', name: 'Transaction Count'),
  ];

  String _reportType = 'all_transactions';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedType = 'all';
  String? _schoolId;
  String? _classId;
  bool _loadingClasses = false;
  List<IdName> _classOptions = const <IdName>[];
  List<AdminUser> _studentResults = const <AdminUser>[];
  Timer? _studentDebounce;
  bool _searchingStudents = false;

  // Preview state
  bool _loadingPreview = false;
  List<Map<String, dynamic>> _previewData = [];
  String? _previewError;
  int _previewPage = 0;
  static const int _rowsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _initWelcome();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = AdminScope.of(context);
      vm.ensureLookups();
    });
  }

  Future<void> _initWelcome() async {
    try {
      final name = await CommonRepository(
        supabase,
      ).getCurrentUserDisplayName(fallback: '');
      if (!mounted) return;
      setState(() => _displayName = name);
    } catch (_) {
      // ignore welcome load errors
    }
  }

  @override
  void dispose() {
    _studentDebounce?.cancel();
    _teacherController.dispose();
    _studentController.dispose();
    super.dispose();
  }

  void _applyReportTypeDefaults(String reportType) {
    switch (reportType) {
      case 'all_schools':
        _selectedType = 'all';
        _teacherController.clear();
        _studentController.clear();
        _classId = null;
        break;
      case 'all_students':
        _selectedType = 'all';
        _teacherController.clear();
        break;
      case 'school_deposits':
        _selectedType = 'deposit';
        _teacherController.clear();
        _studentController.clear();
        break;
      case 'teacher_activity':
        _selectedType = 'all';
        _studentController.clear();
        _classId = null;
        break;
      case 'student_activity':
        _selectedType = 'all';
        _teacherController.clear();
        break;
      case 'class_summary':
        _selectedType = 'all';
        _teacherController.clear();
        _studentController.clear();
        break;
      case 'all_transactions':
      default:
        // No defaults, keep current selections
        break;
    }
  }

  bool _shouldShowFilter(String filterName) {
    if (_reportType == 'custom') return true;

    switch (filterName) {
      case 'school':
        return !['all_schools', 'all_students'].contains(_reportType);
      case 'class':
        return ['class_summary', 'custom'].contains(_reportType);
      case 'teacher':
        return [
          'teacher_activity',
          'all_transactions',
          'custom',
        ].contains(_reportType);
      case 'student':
        return [
          'student_activity',
          'all_transactions',
          'custom',
        ].contains(_reportType);
      case 'transactionType':
        return !['all_schools', 'all_students'].contains(_reportType);
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = AdminScope.of(context);
    final schools = vm.schools;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHeader) ...[
          const Center(
            child: Text(
              'Reports',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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
        ],
        // Scrollable form content below fixed header
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Report Type Selector
                  _FieldBox(
                    width: double.infinity,
                    label: 'Report Type',
                    child: DropdownButtonFormField<String>(
                      initialValue: _reportType,
                      items: _reportTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type.id,
                              child: Text(type.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _reportType = value;
                          // Reset filters when changing report type
                          if (value != 'custom') {
                            _applyReportTypeDefaults(value);
                          }
                        });
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 32,
                    runSpacing: 18,
                    children: [
                      _FieldBox(
                        width: 320,
                        label: 'From Date',
                        child: _DatePickerField(
                          value: _fromDate,
                          onChanged: (value) =>
                              setState(() => _fromDate = value),
                        ),
                      ),
                      _FieldBox(
                        width: 320,
                        label: 'To Date',
                        child: _DatePickerField(
                          value: _toDate,
                          onChanged: (value) => setState(() => _toDate = value),
                        ),
                      ),
                      _FieldBox(
                        width: 320,
                        label: 'Transaction Type',
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          items: _transactionTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type.id,
                                  child: Text(type.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedType = value);
                          },
                        ),
                      ),
                      if (_shouldShowFilter('school'))
                        _FieldBox(
                          width: 320,
                          label: 'School',
                          child: DropdownButtonFormField<String>(
                            initialValue: _schoolId,
                            items: schools
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _schoolId = value;
                                _classId = null;
                              });
                              _loadClasses(value);
                            },
                            hint: const Text('All schools'),
                          ),
                        ),
                      if (_shouldShowFilter('class'))
                        _FieldBox(
                          width: 320,
                          label: 'Class',
                          child: _loadingClasses
                              ? const Center(child: CircularProgressIndicator())
                              : DropdownButtonFormField<String>(
                                  initialValue: _classId,
                                  items: _classOptions
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _classId = value),
                                  hint: const Text('All classes'),
                                ),
                        ),
                      if (_shouldShowFilter('teacher'))
                        _FieldBox(
                          width: 320,
                          label: 'Teacher',
                          child: TextFormField(
                            controller: _teacherController,
                            decoration: const InputDecoration(
                              hintText: 'Optional teacher name',
                            ),
                          ),
                        ),
                      if (_shouldShowFilter('student'))
                        _FieldBox(
                          width: 320,
                          label: 'Student',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _studentController,
                                autofillHints: const [AutofillHints.name],
                                decoration: InputDecoration(
                                  suffixIcon: _studentController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _studentController.clear();
                                            setState(
                                              () => _studentResults =
                                                  const <AdminUser>[],
                                            );
                                          },
                                          icon: const Icon(Icons.clear),
                                        ),
                                  hintText: 'Search student by name',
                                ),
                                onChanged: (value) {
                                  _studentDebounce?.cancel();
                                  _studentDebounce = Timer(
                                    const Duration(milliseconds: 400),
                                    () => _searchStudents(vm, value),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              if (_searchingStudents)
                                const LinearProgressIndicator(minHeight: 2)
                              else if (_studentResults.isNotEmpty)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 220,
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemBuilder: (context, index) {
                                      final user = _studentResults[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(user.fullName),
                                        subtitle: Text(user.email),
                                        onTap: () {
                                          _studentController.text =
                                              user.fullName;
                                          setState(
                                            () => _studentResults =
                                                const <AdminUser>[],
                                          );
                                        },
                                      );
                                    },
                                    separatorBuilder: (_, i_) =>
                                        const Divider(height: 1),
                                    itemCount: _studentResults.length,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _loadingPreview
                            ? null
                            : () => _generatePreview(vm),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        icon: _loadingPreview
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.preview),
                        label: const Text('Generate Preview'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _submit(vm),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Export Report'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _downloadCsv(vm),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          side: BorderSide.none,
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('Download CSV'),
                      ),
                    ],
                  ),

                  // Preview Section
                  if (_previewError != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.red[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _previewError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],

                  if (_previewData.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildPreviewSection(vm),
                  ],
                ], // close inner Column children
              ), // close inner Column
            ), // close Form
          ), // close ConstrainedBox
        ), // close Center
      ], // close outer Column children
    ); // close outer Column (the content variable)

    // On mobile (inside DashboardShell's scroll view), return content directly
    // On web (inside WebShell's Expanded widget), wrap in SingleChildScrollView
    return LayoutBuilder(
      builder: (context, constraints) {
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

  Future<void> _loadClasses(String? schoolId) async {
    if (schoolId == null) {
      setState(() => _classOptions = const <IdName>[]);
      return;
    }
    setState(() => _loadingClasses = true);
    final vm = AdminScope.of(context, listen: false);
    try {
      // DEBUG
      debugPrint('[REPORT] _loadClasses: schoolId=$schoolId');
      final classes = await vm.classesForSchool(schoolId);
      // DEBUG
      debugPrint('[REPORT] _loadClasses: got ${classes.length} classes');
      if (!mounted) return;
      setState(() {
        _classOptions = classes;
        if (!_classOptions.any((c) => c.id == _classId)) {
          _classId = null;
        }
      });
    } catch (e, st) {
      // DEBUG
      debugPrint('[REPORT] _loadClasses ERROR: $e');
      debugPrint('[REPORT] stack: $st');
    } finally {
      if (mounted) {
        setState(() => _loadingClasses = false);
      }
    }
  }

  Future<void> _searchStudents(AdminVm vm, String query) async {
    if (query.trim().isEmpty) {
      setState(() => _studentResults = const <AdminUser>[]);
      return;
    }
    setState(() => _searchingStudents = true);
    try {
      final result = await vm.repo.searchUsers(
        UserSearchFilter(
          searchQuery: query.trim(),
          role: AppRole.student,
          limit: 10,
        ),
      );
      if (!mounted) return;
      setState(() => _studentResults = result.users);
    } catch (_) {
      if (!mounted) return;
      setState(() => _studentResults = const <AdminUser>[]);
    } finally {
      if (mounted) {
        setState(() => _searchingStudents = false);
      }
    }
  }

  Future<void> _generatePreview(AdminVm vm) async {
    // Ensure lookups are loaded before generating preview
    await vm.ensureLookups();

    // Validate date range
    if (_fromDate != null && _toDate != null && _fromDate!.isAfter(_toDate!)) {
      setState(() {
        _previewError = 'Start date must be before end date.';
        _previewData = [];
      });
      return;
    }

    setState(() {
      _loadingPreview = true;
      _previewError = null;
      _previewData = [];
      _previewPage = 0;
    });

    try {
      // DEBUG
      debugPrint('[REPORT] _generatePreview: type=$_reportType selectedType=$_selectedType schoolId=$_schoolId classId=$_classId from=$_fromDate to=$_toDate');
      final rows = await _fetchReportRows(vm);
      // DEBUG
      debugPrint('[REPORT] _generatePreview: got ${rows.length} rows');
      if (rows.isNotEmpty) debugPrint('[REPORT] first row keys: ${rows.first.keys.toList()}');
      if (!mounted) return;
      setState(() {
        _previewData = rows;
        _loadingPreview = false;
      });
    } catch (e, st) {
      // DEBUG
      debugPrint('[REPORT] _generatePreview ERROR: $e');
      debugPrint('[REPORT] stack: $st');
      if (!mounted) return;
      setState(() {
        _previewError = friendlyActionError('Failed to generate preview.', e);
        _loadingPreview = false;
      });
    }
  }

  Widget _buildPreviewSection(AdminVm vm) {
    final isCount = _selectedType == 'count';
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (isCount && _previewData.isNotEmpty) {
      final r = _previewData.first;
      return Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.primaryBlue, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Transaction Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Transaction Count',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r['transaction_count'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (r['total_amount'] is num)
                            ? '\$${(r['total_amount'] as num).toStringAsFixed(2)}'
                            : '\$${r['total_amount'] ?? '0.00'}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Detailed transactions
    final start = _previewPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _previewData.length);
    final pageData = _previewData.sublist(start, end);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Card(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.primaryBlue, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Preview (${_previewData.length} transactions)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_previewData.length > _rowsPerPage)
                      Row(
                        children: [
                          IconButton(
                            onPressed: _previewPage > 0
                                ? () => setState(() => _previewPage--)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${_previewPage + 1}/${(_previewData.length / _rowsPerPage).ceil()}',
                          ),
                          IconButton(
                            onPressed: end < _previewData.length
                                ? () => setState(() => _previewPage++)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isMobile)
                  _buildMobilePreview(pageData)
                else
                  _buildWebPreview(pageData),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebPreview(List<Map<String, dynamic>> data) {
    final vm = AdminScope.of(context);
    final isSchoolDeposit =
        _reportType == 'all_schools' || _reportType == 'school_deposits';

    if (isSchoolDeposit) {
      // School deposits (cu_dep_event table)
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.primaryBlue.withValues(alpha: 0.1),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Posted Date',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'School',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Amount',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          rows: data.map((r) {
            final dateStr = (r['posted_at'] as String?)?.split('T').first ?? '';
            final school = (r['school_name'] as String?) ?? '';
            final amount = (r['amount'] as num?)?.toStringAsFixed(2) ?? '';
            final status = (r['status'] as String?) ?? '';

            return DataRow(
              cells: [
                DataCell(Text(dateStr)),
                DataCell(Text(school)),
                DataCell(Text('\$$amount')),
                DataCell(Text(status)),
              ],
            );
          }).toList(),
        ),
      );
    }

    // Student transactions from admin_transaction_report RPC
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          AppColors.primaryBlue.withValues(alpha: 0.1),
        ),
        columns: const [
          DataColumn(
            label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          DataColumn(
            label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          DataColumn(
            label: Text(
              'Amount',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Teacher',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          DataColumn(
            label: Text(
              'Student',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          DataColumn(
            label: Text(
              'School',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        rows: data.map((r) {
          final dateStr = (r['created_at'] as String?)?.split('T').first ?? '';
          final type = (r['tx_type'] as String?) ?? '';
          final amount = (r['amount'] as num?)?.toStringAsFixed(2) ?? '';
          final teacher =
              '${r['teacher_first_name'] ?? ''} ${r['teacher_last_name'] ?? ''}'
                  .trim();
          final student =
              '${r['student_first_name'] ?? ''} ${r['student_last_name'] ?? ''}'
                  .trim();
          final schoolId = (r['school_id'] as String?) ?? '';
          // Try to get school_name from data, fall back to lookup
          var schoolName = (r['school_name'] as String?) ?? '';
          if (schoolName.isEmpty && schoolId.isNotEmpty) {
            schoolName = vm.schools
                .firstWhere(
                  (s) => s.id == schoolId,
                  orElse: () => IdName(id: schoolId, name: schoolId),
                )
                .name;
          }

          return DataRow(
            cells: [
              DataCell(Text(dateStr)),
              DataCell(Text(type)),
              DataCell(Text('\$$amount')),
              DataCell(Text(teacher.isEmpty ? '-' : teacher)),
              DataCell(Text(student.isEmpty ? '-' : student)),
              DataCell(Text(schoolName)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobilePreview(List<Map<String, dynamic>> data) {
    final vm = AdminScope.of(context);
    final isSchoolDeposit =
        _reportType == 'all_schools' || _reportType == 'school_deposits';

    if (isSchoolDeposit) {
      // School deposits (cu_dep_event table)
      return Column(
        children: data.map((r) {
          final dateStr = (r['posted_at'] as String?)?.split('T').first ?? '';
          final school = (r['school_name'] as String?) ?? '';
          final amount = (r['amount'] as num?)?.toStringAsFixed(2) ?? '';
          final status = (r['status'] as String?) ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.primaryBlue, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\$$amount',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('School', school),
                  const SizedBox(height: 8),
                  _buildInfoRow('Status', status),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    // Student transactions from admin_transaction_report RPC
    return Column(
      children: data.map((r) {
        final dateStr = (r['created_at'] as String?)?.split('T').first ?? '';
        final type = (r['tx_type'] as String?) ?? '';
        final amount = (r['amount'] as num?)?.toStringAsFixed(2) ?? '';
        final teacher =
            '${r['teacher_first_name'] ?? ''} ${r['teacher_last_name'] ?? ''}'
                .trim();
        final student =
            '${r['student_first_name'] ?? ''} ${r['student_last_name'] ?? ''}'
                .trim();
        final schoolId = (r['school_id'] as String?) ?? '';
        // Try to get school_name from data, fall back to lookup
        var schoolName = (r['school_name'] as String?) ?? '';
        if (schoolName.isEmpty && schoolId.isNotEmpty) {
          schoolName = vm.schools
              .firstWhere(
                (s) => s.id == schoolId,
                orElse: () => IdName(id: schoolId, name: schoolId),
              )
              .name;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.primaryBlue, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$$amount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Type', type),
                if (teacher.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('Teacher', teacher),
                ],
                if (student.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('Student', student),
                ],
                const SizedBox(height: 8),
                _buildInfoRow('School', schoolName),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(AdminVm vm) async {
    // Validate date range
    if (_fromDate != null && _toDate != null && _fromDate!.isAfter(_toDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start date must be before end date.')),
      );
      return;
    }

    final rows = await _fetchReportRows(vm);
    final csvBody = _composeCsvBody(vm, rows);

    // Share the CSV using an in-memory file so it works across web/mobile/desktop
    final bytes = Uint8List.fromList(utf8.encode(csvBody));
    final xfile = XFile.fromData(
      bytes,
      name: 'admin_report.csv',
      mimeType: 'text/csv',
    );

    final params = ShareParams(
      text: 'Admin Report',
      subject: 'Admin Report Export',
      files: [xfile],
    );

    try {
      await SharePlus.instance.share(params);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Export failed.', e))));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReportRows(AdminVm vm) async {
    // Normalize dates to day bounds
    DateTime? from = _fromDate == null
        ? null
        : DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    DateTime? to = _toDate == null
        ? null
        : DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);

    // Use cu_dep_event table for school-level deposit reports (school to credit union)
    if (_reportType == 'all_schools' || _reportType == 'school_deposits') {
      // DEBUG
      debugPrint('[REPORT] fetchSchoolDepositsReport: from=$from to=$to schoolId=$_schoolId type=$_selectedType');
      final rows = await vm.repo.fetchSchoolDepositsReport(
        from: from,
        to: to,
        schoolId: _schoolId,
        type: _selectedType,
        limit: 5000,
      );
      // DEBUG
      debugPrint('[REPORT] fetchSchoolDepositsReport: ${rows.length} rows returned');
      return rows;
    }

    // Use admin_transaction_report RPC for student-level activity (students to school)
    // DEBUG
    debugPrint('[REPORT] fetchTransactionReport: from=$from to=$to schoolId=$_schoolId classId=$_classId type=$_selectedType teacher="${_teacherController.text.trim()}" student="${_studentController.text.trim()}"');
    final rows = await vm.repo.fetchTransactionReport(
      from: from,
      to: to,
      schoolId: _schoolId,
      classId: _classId,
      teacherNameLike: _teacherController.text.trim().isEmpty
          ? null
          : _teacherController.text.trim(),
      studentNameLike: _studentController.text.trim().isEmpty
          ? null
          : _studentController.text.trim(),
      type: _selectedType,
      limit: 5000,
    );
    // DEBUG
    debugPrint('[REPORT] fetchTransactionReport: ${rows.length} rows returned');
    return rows;
  }

  String _composeCsvBody(AdminVm vm, List<Map<String, dynamic>> rows) {
    String fmt(DateTime? d) => d == null
        ? ''
        : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String esc(String s) {
      final needs = s.contains(',') || s.contains('\n') || s.contains('"');
      final e = s.replaceAll('"', '""');
      return needs ? '"$e"' : e;
    }

    String nameFor(List<IdName> list, String? id) {
      if (id == null) return '';
      for (final item in list) {
        if (item.id == id) return item.name;
      }
      return id;
    }

    final selectedSchoolName = nameFor(vm.schools, _schoolId);
    final selectedClassName = nameFor(_classOptions, _classId);
    final selectedTypeName = _transactionTypes
        .firstWhere(
          (t) => t.id == _selectedType,
          orElse: () => _transactionTypes.first,
        )
        .name;
    final reportTypeName = _reportTypes
        .firstWhere(
          (t) => t.id == _reportType,
          orElse: () => _reportTypes.first,
        )
        .name;

    final out = <List<String>>[
      ['Report Type', reportTypeName],
      [
        'From',
        'To',
        'Transaction Type',
        'School',
        'Class',
        'Teacher',
        'Student',
      ],
      [
        fmt(_fromDate),
        fmt(_toDate),
        selectedTypeName,
        selectedSchoolName,
        selectedClassName,
        _teacherController.text,
        _studentController.text,
      ],
    ];

    // If we requested a count summary, rows contain one map with transaction_count and total_amount
    final isCount = _selectedType == 'count';
    if (isCount) {
      out.add([]); // blank line
      out.add(['Transaction Count', 'Total Amount']);
      if (rows.isNotEmpty) {
        final r = rows.first;
        out.add([
          '${r['transaction_count'] ?? 0}',
          (r['total_amount'] is num)
              ? (r['total_amount'] as num).toStringAsFixed(2)
              : '${r['total_amount'] ?? ''}',
        ]);
      }
      return out.map((r) => r.map(esc).join(',')).join('\n');
    }

    // School deposits (cu_dep_event table)
    final isSchoolDeposit =
        _reportType == 'all_schools' || _reportType == 'school_deposits';
    if (isSchoolDeposit) {
      out.add([]); // blank line
      out.add(['Posted Date', 'School', 'Amount', 'Status', 'Deposit ID']);
      for (final r in rows) {
        final dateStr = (r['posted_at'] as String?) ?? '';
        final school = (r['school_name'] as String?) ?? '';
        final amount = (r['amount'] is num)
            ? (r['amount'] as num).toStringAsFixed(2)
            : '${r['amount'] ?? ''}';
        final status = (r['status'] as String?) ?? '';
        final depositId = (r['dep_event_id'] as String?) ?? '';
        out.add([dateStr, school, amount, status, depositId]);
      }
      return out.map((r) => r.map(esc).join(',')).join('\n');
    }

    // Detailed student transactions from admin_transaction_report RPC
    out.add([]); // blank line
    out.add([
      'Date',
      'Type',
      'Amount',
      'Teacher',
      'Student',
      'School',
      'Class',
    ]);
    for (final r in rows) {
      final dateStr = (r['created_at'] as String?) ?? '';
      final type = (r['tx_type'] as String?) ?? '';
      final amount = (r['amount'] as num?)?.toStringAsFixed(2) ?? '';
      final teacher =
          '${(r['teacher_first_name'] ?? '')} ${(r['teacher_last_name'] ?? '')}'
              .trim();
      final student =
          '${(r['student_first_name'] ?? '')} ${(r['student_last_name'] ?? '')}'
              .trim();
      final schoolId = (r['school_id'] as String?) ?? '';
      final school = (r['school_name'] as String?)?.isNotEmpty == true
          ? r['school_name'] as String
          : nameFor(vm.schools, schoolId.isNotEmpty ? schoolId : null);
      final classId = (r['class_id'] as String?) ?? '';
      final klass = (r['class_name'] as String?)?.isNotEmpty == true
          ? r['class_name'] as String
          : nameFor(_classOptions, classId.isNotEmpty ? classId : null);
      out.add([dateStr, type, amount, teacher, student, school, klass]);
    }

    return out.map((r) => r.map(esc).join(',')).join('\n');
  }

  Future<void> _downloadCsv(AdminVm vm) async {
    final rows = await _fetchReportRows(vm);
    final csvBody = _composeCsvBody(vm, rows);
    final bytes = Uint8List.fromList(utf8.encode(csvBody));
    try {
      await dl.downloadBytes(filename: 'admin_report.csv', bytes: bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Download failed.', e))));
    }
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.width,
    required this.label,
    required this.child,
  });

  final double width;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Select date'
        : value!.toIso8601String().split('T').first;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: now,
          initialDate: value ?? now,
          builder: (ctx, child) {
            final theme = Theme.of(ctx);
            return Theme(
              data: theme.copyWith(
                // Force white background for the Material date picker dialog
                datePickerTheme: theme.datePickerTheme.copyWith(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                ),
                colorScheme: theme.colorScheme.copyWith(
                  surface: Colors.white,
                  surfaceContainerHighest: Colors.white,
                ),
                dialogTheme: DialogThemeData(backgroundColor: Colors.white),
              ),
              child: child!,
            );
          },
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text(text),
      ),
    );
  }
}
