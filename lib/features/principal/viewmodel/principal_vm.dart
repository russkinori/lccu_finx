// lib/view_models/principal_vm.dart
import 'package:flutter/material.dart';

import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/features/principal/data/principal_repo.dart';
import 'package:lccu_finx/core/widgets/friendly_error.dart';

class PrincipalVm extends ChangeNotifier {
  PrincipalVm({
    required this.repo,
    required CommonRepository common,
  }) : _common = common;

  final PrincipalRepository repo;
  final CommonRepository _common;

  PrincipalHomeVM? _snapshot;
  bool _loading = false;
  String? _error;

  static const String _kAll = 'ALL';

  String _selectedTeacherId = _kAll;
  String _selectedClassId = _kAll;
  String _selectedStudentId = _kAll;
  String _studentQuery = '';
  String? _schoolId;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  double _accountBalance = 0.0;
  double _filteredAccountBalance = 0.0;
  double _fundsOnSite = 0.0;
  double _depositedFunds = 0.0;
  double _schoolDepositDue = 0.0;
  double _schoolDeposited = 0.0;
  double _schoolDifference = 0.0;
  double _teacherDepositDue = 0.0;
  double _teacherDeposited = 0.0;
  double _teacherDifference = 0.0;

  bool get isLoading => _loading;
  String? get error => _error;
  PrincipalHomeVM? get snapshot => _snapshot;
  String get principalName => _snapshot?.principalName ?? 'Principal';
  DateTimeRange get range => _range;

  String get selectedTeacherId => _selectedTeacherId;
  String get selectedClassId => _selectedClassId;
  String get selectedStudentId => _selectedStudentId;
  String get studentQuery => _studentQuery;

  double get contributionForPeriod => _snapshot?.contributionForPeriod ?? 0.0;

  double get accountBalance => _accountBalance;
  double get filteredAccountBalance => _filteredAccountBalance;
  double get fundsOnSite => _fundsOnSite;
  double get depositedFunds => _depositedFunds;
  double get schoolDepositDue => _schoolDepositDue;
  double get schoolDeposited => _schoolDeposited;
  double get schoolDifference => _schoolDifference;
  double get teacherDepositDue => _teacherDepositDue;
  double get teacherDeposited => _teacherDeposited;
  double get teacherDifference => _teacherDifference;

  List<PIdName> get teacherOptions =>
      _withAllOption(_snapshot?.teachers ?? const <PIdName>[]);

  List<PIdName> get classOptions {
    final classes = _snapshot?.classes ?? const <PIdName>[];
    return _withAllOption(classes);
  }

  List<PIdName> get studentOptions {
    final students = _snapshot?.students ?? const <PIdName>[];
    return _withAllOption(students);
  }

  List<PrincipalSummaryRow> get transactions {
    final rows = _snapshot?.rows ?? const <PrincipalSummaryRow>[];
    if (_studentQuery.isEmpty) return rows;
    final query = _studentQuery.toLowerCase();
    return rows
        .where((r) => r.studentName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  Future<void> bootstrap() async {
    if (_snapshot != null || _loading) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final from = DateTime(
        _range.start.year,
        _range.start.month,
        _range.start.day,
      );
      final to = DateTime(
        _range.end.year,
        _range.end.month,
        _range.end.day,
        23,
        59,
        59,
      );

      final raw = await repo.getPrincipalHome(
        from: from,
        to: to,
        teacherId: _selectedTeacherId == _kAll ? null : _selectedTeacherId,
        classId: _selectedClassId == _kAll ? null : _selectedClassId,
        studentId: _selectedStudentId == _kAll ? null : _selectedStudentId,
      );

      final principalName = await _common.getCurrentUserDisplayName(
        fallback: 'Principal',
      );

      _snapshot = PrincipalHomeVM(
        principalName: principalName,
        teachers: raw.teachers,
        classes: raw.classes,
        students: raw.students,
        contributionForPeriod: raw.contributionForPeriod,
        fundsOnSite: raw.fundsOnSite,
        rows: raw.rows,
      );

      _normalizeSelections();
    } catch (e) {
      _error = friendlyActionError('Failed to load principal dashboard.', e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshHomeData(String schoolId) async {
    if (repo is! SupabasePrincipalRepository) return;
    final r = repo as SupabasePrincipalRepository;
    _schoolId = schoolId;

    try {
      _accountBalance = await r.getSchoolAccountBalance(schoolId);

      final (fundsOnSite, depositedFunds) = await r.getSchoolWeeklySummary(
        schoolId,
      );
      _fundsOnSite = fundsOnSite;
      _depositedFunds = depositedFunds;

      if (_snapshot != null) {
        _snapshot = PrincipalHomeVM(
          principalName: _snapshot!.principalName,
          teachers: _snapshot!.teachers,
          classes: _snapshot!.classes,
          students: _snapshot!.students,
          contributionForPeriod: _snapshot!.contributionForPeriod,
          fundsOnSite: _fundsOnSite,
          rows: _snapshot!.rows,
        );
      }

      final (schoolDepositDue, schoolDeposited, schoolDifference) =
          await r.getSchoolDepositDetails(schoolId);
      _schoolDepositDue = schoolDepositDue;
      _schoolDeposited = schoolDeposited;
      _schoolDifference = schoolDifference;

      if (_selectedTeacherId != _kAll) {
        final (teacherDepositDue, teacherDeposited, teacherDifference) =
            await r.getTeacherDepositDetails(schoolId, _selectedTeacherId);
        _teacherDepositDue = teacherDepositDue;
        _teacherDeposited = teacherDeposited;
        _teacherDifference = teacherDifference;
      } else {
        final (teacherDepositDue, teacherDeposited, teacherDifference) =
            await r.getAllTeachersDepositDetails(schoolId);
        _teacherDepositDue = teacherDepositDue;
        _teacherDeposited = teacherDeposited;
        _teacherDifference = teacherDifference;
      }

      _filteredAccountBalance = await r.getFilteredAccountBalance(
        schoolId: schoolId,
        teacherId: _selectedTeacherId == _kAll ? null : _selectedTeacherId,
        classId: _selectedClassId == _kAll ? null : _selectedClassId,
        studentId: _selectedStudentId == _kAll ? null : _selectedStudentId,
      );

      notifyListeners();
    } catch (e) {
      _error = friendlyActionError('Failed to load home data.', e);
      notifyListeners();
    }
  }

  Future<void> setTeacher(String? teacherId) async {
    final id = teacherId ?? _kAll;
    if (_selectedTeacherId == id) return;

    _selectedTeacherId = id;
    _selectedClassId = _kAll;
    _selectedStudentId = _kAll;

    await refresh();

    if (_schoolId != null) {
      await refreshHomeData(_schoolId!);
    }
  }

  Future<void> setClass(String? classId) async {
    final id = classId ?? _kAll;
    if (_selectedClassId == id) return;

    _selectedClassId = id;

    // Required behavior:
    // changing class should reset student to All
    _selectedStudentId = _kAll;

    await refresh();

    if (_schoolId != null) {
      await refreshHomeData(_schoolId!);
    }
  }

  Future<void> setStudent(String? studentId) async {
    final id = studentId ?? _kAll;
    if (_selectedStudentId == id) return;

    _selectedStudentId = id;

    if (_selectedStudentId != _kAll) {
      final selected = (_snapshot?.students ?? const <PIdName>[])
          .where((s) => s.id == _selectedStudentId)
          .cast<PIdName?>()
          .firstWhere((_) => true, orElse: () => null);

      final classId = selected?.meta?['class_id'] as String?;
      if (classId != null && classId.isNotEmpty) {
        _selectedClassId = classId;
      }
    }

    await refresh();

    if (_schoolId != null) {
      await refreshHomeData(_schoolId!);
    }
  }

  void setStudentQuery(String value) {
    _studentQuery = value.trim();
    notifyListeners();
  }

  Future<void> setRange(DateTimeRange range) async {
    if (_range == range) return;
    _range = range;
    await refresh();
    if (_schoolId != null) {
      await refreshHomeData(_schoolId!);
    }
  }

  List<PrincipalSummaryRow> get exportRows => _snapshot?.rows ?? const [];

  void _normalizeSelections() {
    final validTeacherIds = teacherOptions.map((e) => e.id).toSet();
    final validClassIds = classOptions.map((e) => e.id).toSet();
    final validStudentIds = studentOptions.map((e) => e.id).toSet();

    if (!validTeacherIds.contains(_selectedTeacherId)) {
      _selectedTeacherId = _kAll;
    }
    if (!validClassIds.contains(_selectedClassId)) {
      _selectedClassId = _kAll;
    }
    if (!validStudentIds.contains(_selectedStudentId)) {
      _selectedStudentId = _kAll;
    }

    // If a specific student is selected, keep class aligned to that student
    if (_selectedStudentId != _kAll) {
      final selected = (_snapshot?.students ?? const <PIdName>[])
          .where((s) => s.id == _selectedStudentId)
          .cast<PIdName?>()
          .firstWhere((_) => true, orElse: () => null);

      final classId = selected?.meta?['class_id'] as String?;
      if (classId != null && classId.isNotEmpty) {
        _selectedClassId = classId;
      }
    }
  }

  List<PIdName> _withAllOption(List<PIdName> items) {
    final seen = <String>{};
    final deduped = <PIdName>[];
    for (final item in items) {
      if (seen.add(item.id)) {
        deduped.add(item);
      }
    }
    return [const PIdName(id: _kAll, name: 'All'), ...deduped];
  }
}

class PrincipalScope extends InheritedNotifier<PrincipalVm> {
  const PrincipalScope({
    super.key,
    required PrincipalVm super.notifier,
    required super.child,
  });

  static PrincipalVm of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<PrincipalScope>();
      assert(
        scope != null,
        'PrincipalScope.of() called with no PrincipalScope in context',
      );
      return scope!.notifier!;
    }
    final element =
        context.getElementForInheritedWidgetOfExactType<PrincipalScope>();
    final scope = element?.widget as PrincipalScope?;
    assert(
      scope != null,
      'PrincipalScope.of() called with no PrincipalScope in context',
    );
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant PrincipalScope oldWidget) => true;
}
