import 'package:flutter/material.dart';

import 'id_name.dart';
import 'app_logger.dart';
import 'friendly_error.dart';
import 'teacher_repo.dart';

class TeacherVm extends ChangeNotifier {
  TeacherVm({required TeacherRepository repo}) : _repo = repo;

  final TeacherRepository _repo;

  TeacherHomeVM? _snapshot;
  List<TeacherPendingWithdrawal> _pending = const [];
  bool _loading = false;
  String? _error;

  String _selectedClassId = _kAll;
  String _selectedStudentId = _kAll;

  static const _kAll = 'ALL';

  bool get isLoading => _loading;
  String? get error => _error;
  TeacherHomeVM? get snapshot => _snapshot;
  List<TeacherPendingWithdrawal> get pendingWithdrawals => _pending;
  String get selectedClassId => _selectedClassId;
  String get selectedStudentId => _selectedStudentId;

  List<IdName> get classOptions => _withAll(_snapshot?.classes ?? const []);
  List<IdName> get studentOptions => _withAll(_snapshot?.students ?? const []);
  String get teacherName => _snapshot?.teacherName ?? 'Teacher';
  double get scopedBalance => _snapshot?.scopedBalance ?? 0.0;
  double get accountBalanceTotal => _snapshot?.accountBalanceTotal ?? 0.0;

  List<TeacherTxRow> get transactions => _snapshot?.transactions ?? const [];

  TeacherPendingWithdrawal? get highlightedWithdrawal {
    if (_pending.isEmpty) return null;
    return _pending.firstWhere(
      (w) => w.requestId.isNotEmpty,
      orElse: () => _pending.first,
    );
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
      appLog('TeacherVm refresh started');
      final classId = _selectedClassId == _kAll ? null : _selectedClassId;
      final studentId = _selectedStudentId == _kAll ? null : _selectedStudentId;
      appLog('TeacherVm loading home data');
      _snapshot = await _repo.getTeacherHome(
        classId: classId,
        studentId: studentId,
      );
      appLog('TeacherVm home snapshot loaded');
      _pending = await _repo.getPendingWithdrawals(
        classId: classId,
        studentId: studentId,
      );
      appLog('TeacherVm pending withdrawals loaded');
    } catch (e, stackTrace) {
      _error = friendlyActionError('Failed to load teacher dashboard.', e);
      appLogError(e, stackTrace);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setClass(String? classId) async {
    final id = classId ?? _kAll;
    if (_selectedClassId == id) return;
    _selectedClassId = id;
    _selectedStudentId = _kAll; // reset student when class changes
    await refresh();
  }

  Future<void> setStudent(String? studentId) async {
    final id = studentId ?? _kAll;
    if (_selectedStudentId == id) return;
    _selectedStudentId = id;
    await refresh();
  }

  Future<void> postWithdrawal(String requestId) async {
    await _repo.postWithdrawal(requestId: requestId);
    await refresh();
  }

  Future<void> completeWithdrawal(String requestId) async {
    await _repo.completeWithdrawal(requestId: requestId);
    await refresh();
  }

  Future<void> createDeposit({
    required String studentId,
    required double amount,
    String? note,
  }) async {
    try {
      await _repo.createDeposit(
        studentId: studentId,
        amount: amount,
        note: note,
      );
      await refresh();
    } catch (e) {
      // Don't swallow the error - let it bubble up to the UI
      rethrow;
    }
  }

  Future<void> submitWithdrawal({
    required String studentId,
    required double amount,
    String? note,
  }) async {
    await _repo.submitWithdrawalForStudent(
      studentId: studentId,
      amount: amount,
      note: note,
    );
    await refresh();
  }

  List<IdName> _withAll(List<IdName> items) {
    final seen = <String>{};
    final deduped = <IdName>[];
    for (final item in items) {
      if (seen.add(item.id)) {
        deduped.add(item);
      }
    }
    return [const IdName(id: _kAll, name: 'All'), ...deduped];
  }

  Future<List<TeacherPendingWithdrawal>> getAllWithdrawals() async {
    final classId = _selectedClassId == _kAll ? null : _selectedClassId;
    final studentId = _selectedStudentId == _kAll ? null : _selectedStudentId;
    return _repo.getAllWithdrawals(classId: classId, studentId: studentId);
  }
}

class TeacherScope extends InheritedNotifier<TeacherVm> {
  const TeacherScope({
    super.key,
    required TeacherVm super.notifier,
    required super.child,
  });

  static TeacherVm of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<TeacherScope>();
      assert(
        scope != null,
        'TeacherScope.of() called with no TeacherScope in context',
      );
      return scope!.notifier!;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<TeacherScope>();
    final scope = element?.widget as TeacherScope?;
    assert(
      scope != null,
      'TeacherScope.of() called with no TeacherScope in context',
    );
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant TeacherScope oldWidget) => true;
}
