import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'id_name.dart';
import 'teller_repo.dart';
import 'friendly_error.dart';

class TellerVm extends ChangeNotifier {
  TellerVm({required TellerRepository repo}) : _repo = repo;

  final TellerRepository _repo;

  bool _loadingHome = false;
  bool _loadingSchool = false;
  String? _error;

  List<TellerSchoolRow> _schools = const [];
  String? _selectedSchoolId;

  List<IdName> _teachers = const [];
  String? _selectedTeacherId;

  List<DepositBatchRow> _batches = const [];

  (double depositDue, double deposited, double discrepancy)? _schoolSnapshot;

  TellerRepository get repo => _repo;
  bool get isLoading => _loadingHome || _loadingSchool;
  String? get error => _error;

  List<TellerSchoolRow> get schools => _schools;

  String? get selectedSchoolId => _selectedSchoolId;

  List<IdName> get teachers => _teachers;
  String? get selectedTeacherId => _selectedTeacherId;

  List<DepositBatchRow> get batches => _batches;

  double get schoolDepositDue => _schoolSnapshot?.$1 ?? 0.0;
  double get schoolDeposited => _schoolSnapshot?.$2 ?? 0.0;
  double get schoolDiscrepancy => _schoolSnapshot?.$3 ?? 0.0;

  TellerSchoolRow? get selectedSchoolRow {
    final sid = _selectedSchoolId;
    if (sid == null) return null;
    for (final row in _schools) {
      if (row.schoolId == sid) return row;
    }
    return null;
  }

  Future<void> bootstrap() async {
    if (_loadingHome || _schools.isNotEmpty) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_loadingHome) return;

    _loadingHome = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _repo.getTellerHomeRows();
      _schools = rows;

      final sid = _selectedSchoolId;
      if (sid != null && !_schools.any((s) => s.schoolId == sid)) {
        _selectedSchoolId = null;
        _selectedTeacherId = null;
        _teachers = const [];
        _batches = const [];
        _schoolSnapshot = null;
      }
    } catch (e) {
      _error = friendlyActionError('Failed to load teller data.', e);
    } finally {
      _loadingHome = false;
      notifyListeners();
    }
  }

  Future<void> selectSchool(String schoolId) async {
    final alreadyLoaded =
        _selectedSchoolId == schoolId &&
        (_teachers.isNotEmpty || _batches.isNotEmpty || _schoolSnapshot != null);

    if (alreadyLoaded) return;

    _selectedSchoolId = schoolId;
    _selectedTeacherId = null;
    await refreshSelectedSchoolData();
  }

  Future<void> refreshSelectedSchoolData() async {
    final sid = _selectedSchoolId;
    if (sid == null) {
      _teachers = const [];
      _selectedTeacherId = null;
      _batches = const [];
      _schoolSnapshot = null;
      notifyListeners();
      return;
    }

    if (_loadingSchool) return;

    _loadingSchool = true;
    _error = null;
    _teachers = const [];
    _selectedTeacherId = null;
    _batches = const [];
    _schoolSnapshot = null;
    notifyListeners();

    try {
      final teachers = await _repo.getTeachersForSchool(sid);
      final batches = await _repo.fetchPendingDepositBatches(sid);
      final snapshot = await _repo.getSchoolDepositSnapshot(sid);

      _teachers = teachers;
      _batches = batches;
      _schoolSnapshot = snapshot;
    } catch (e) {
      _error = friendlyActionError('Failed to load school data.', e);
      _teachers = const [];
      _selectedTeacherId = null;
      _batches = const [];
      _schoolSnapshot = null;
    } finally {
      _loadingSchool = false;
      notifyListeners();
    }
  }

  void clearSelectedSchool() {
    if (_selectedSchoolId == null) return;
    _selectedSchoolId = null;
    _teachers = const [];
    _selectedTeacherId = null;
    _batches = const [];
    _schoolSnapshot = null;
    notifyListeners();
  }

  void selectTeacher(String? teacherId) {
    _selectedTeacherId = teacherId;
    notifyListeners();
  }

  Future<(double depositDue, double deposited, double discrepancy)>
  schoolSnapshot() async {
    final sid = _selectedSchoolId;
    if (sid == null) return (0.0, 0.0, 0.0);

    if (_schoolSnapshot != null) {
      return _schoolSnapshot!;
    }

    final snapshot = await _repo.getSchoolDepositSnapshot(sid);
    _schoolSnapshot = snapshot;
    notifyListeners();
    return snapshot;
  }

  Future<void> confirmDeposit({
    required double amount,
    required double discrepancy,
    String? notes,
    List<String>? batchIds,
  }) async {
    final sid = _selectedSchoolId;
    final tid = _selectedTeacherId;

    if (sid == null || tid == null || tid.isEmpty) {
      throw StateError('Select a school and a depositor');
    }

    await _repo.confirmDeposit(
      schoolId: sid,
      teacherId: tid,
      amount: amount,
      discrepancy: discrepancy,
      notes: notes,
      batchIds: batchIds,
    );

    await refresh();
    await refreshSelectedSchoolData();
  }

  Future<String> postSchoolPayout({
    required String requestId,
    required double amount,
    String? note,
    String? requestedByTeacherId,
    String? requestedByPrincipalId,
  }) async {
    final sid = _selectedSchoolId;
    if (sid == null) {
      throw StateError('Select a school first');
    }

    final id = await _repo.postSchoolPayout(
      schoolId: sid,
      requestId: requestId,
      amount: amount,
      note: note,
      requestedByTeacherId: requestedByTeacherId,
      requestedByPrincipalId: requestedByPrincipalId,
    );

    await refresh();
    await refreshSelectedSchoolData();
    return id;
  }

  Future<List<CuDepositRow>> fetchCreditUnionDeposits({
    required DateTime from,
    required DateTime to,
    String? schoolId,
    String? teacherId,
    int limit = 5000,
  }) {
    return _repo.fetchCreditUnionDeposits(
      from: from,
      to: to,
      schoolId: schoolId,
      teacherId: teacherId,
      limit: limit,
    );
  }

  String generateRequestId() {
    const uuid = Uuid();
    return uuid.v4();
  }
}

class TellerScope extends InheritedNotifier<TellerVm> {
  const TellerScope({
    super.key,
    required TellerVm super.notifier,
    required super.child,
  });

  static TellerVm of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<TellerScope>();
      assert(
        scope != null,
        'TellerScope.of() called with no TellerScope in context',
      );
      return scope!.notifier!;
    }

    final element = context.getElementForInheritedWidgetOfExactType<TellerScope>();
    final scope = element?.widget as TellerScope?;
    assert(
      scope != null,
      'TellerScope.of() called with no TellerScope in context',
    );
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant TellerScope oldWidget) => true;
}
