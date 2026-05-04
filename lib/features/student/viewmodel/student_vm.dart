import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lccu_finx/features/student/data/student_repo.dart';
import 'package:lccu_finx/core/widgets/friendly_error.dart';

class StudentVm extends ChangeNotifier {
  StudentVm({required StudentRepository repo}) : _repo = repo;

  final StudentRepository _repo;

  StudentHomeVm? _snapshot;
  bool _loading = false;
  String? _error;

  bool get isLoading => _loading;
  String? get error => _error;
  StudentHomeVm? get snapshot => _snapshot;
  String get studentName => _snapshot?.studentName ?? 'Student';
  String? get studentId => _snapshot?.studentId;
  String? get accountId =>
      _snapshot?.accountId.isEmpty == true ? null : _snapshot?.accountId;
  double get balance => _snapshot?.balance ?? 0;
  List<StudentTransactionRow> get transactions =>
      _snapshot?.transactions ?? const [];
  StudentWithdrawalRow? get latestWithdrawal => _snapshot?.latestWithdrawal;

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
      // Guard the repository call with a timeout so the UI can recover if the
      // backend is slow or unreachable.
      _snapshot = await _repo.getHome().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Student home fetch timed out'),
      );
    } catch (e) {
      _error = friendlyActionError('Failed to load student dashboard.', e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> requestWithdrawal({
    required double amount,
    String? reason,
    String? note,
  }) async {
    final state = _snapshot;
    if (state == null) throw StateError('Student dashboard not ready');
    if (state.accountId.isEmpty) {
      throw StateError('No account available for withdrawal requests');
    }
    if (state.studentId.isEmpty) {
      throw StateError('Student identifier missing');
    }
    await _repo.requestWithdrawal(
      accountId: state.accountId,
      studentId: state.studentId,
      amount: amount,
      reason: reason,
      note: note,
    );
    await refresh();
  }
}

class StudentScope extends InheritedNotifier<StudentVm> {
  const StudentScope({
    super.key,
    required StudentVm super.notifier,
    required super.child,
  });

  static StudentVm of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<StudentScope>();
      assert(
        scope != null,
        'StudentScope.of() called with no StudentScope in context',
      );
      return scope!.notifier!;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<StudentScope>();
    final scope = element?.widget as StudentScope?;
    assert(
      scope != null,
      'StudentScope.of() called with no StudentScope in context',
    );
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant StudentScope oldWidget) => true;
}
