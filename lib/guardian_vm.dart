import 'package:flutter/material.dart';

import 'guardian_repo.dart';
import 'app_logger.dart';
import 'friendly_error.dart';

class GuardianVm extends ChangeNotifier {
  GuardianVm({required GuardianRepository repo}) : _repo = repo;

  final GuardianRepository _repo;

  GuardianHomeVm? _snapshot;
  bool _loading = false;
  bool _bootstrapped = false;
  String? _error;

  // Transaction history state
  List<GuardianTransaction> _transactions = const [];
  String? _selectedChildId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _loadingTransactions = false;
  bool _transactionsLoaded =
      false; // Track if we've attempted to load at least once

  bool get isLoading => _loading;
  String? get error => _error;
  GuardianHomeVm? get snapshot => _snapshot;
  String get guardianName => _snapshot?.guardianName ?? 'Guardian';
  List<GuardianChildRow> get children => _snapshot?.children ?? const [];
  GuardianWithdrawal? get highlightedRequest => _snapshot?.highlightedRequest;

  // Transaction history getters
  List<GuardianTransaction> get transactions => _transactions;
  String? get selectedChildId => _selectedChildId;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  bool get loadingTransactions => _loadingTransactions;
  bool get transactionsLoaded => _transactionsLoaded;

  Future<void> bootstrap() async {
    if (_bootstrapped || _loading) return;
    _bootstrapped = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _snapshot = await _repo.getHome();
    } catch (e) {
      _error = friendlyActionError('Failed to load guardian dashboard.', e);
      appLog('GuardianVm refresh error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> decide({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    await _repo.decideWithdrawal(
      requestId: requestId,
      approve: approve,
      note: note,
    );
    // Immediately refresh the dashboard snapshot after a decision. Use a
    // direct repo call instead of refresh() to avoid early-return when a
    // concurrent refresh is in progress. This ensures the UI reflects the
    // decision (approved/declined) as soon as the RPC completes.
    try {
      final newSnapshot = await _repo.getHome();
      _snapshot = newSnapshot;
      notifyListeners();
    } catch (e) {
      // If fetching fresh snapshot fails, fall back to the regular refresh
      // which respects concurrency and error handling.
      await refresh();
    }
  }

  void setSelectedChild(String? childId) {
    if (_selectedChildId == childId) return;
    _selectedChildId = childId;
    _transactionsLoaded = false; // Reset loaded flag when changing child
    notifyListeners();
    refreshTransactions();
  }

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    _transactionsLoaded = false; // Reset loaded flag when date range changes
    notifyListeners();
    refreshTransactions();
  }

  Future<void> refreshTransactions() async {
    if (_loadingTransactions) return;
    _loadingTransactions = true;
    notifyListeners();
    try {
      appLog(
        'GuardianVm: Loading transactions for child=$_selectedChildId',
      );
      _transactions = await _repo.getTransactionHistory(
        studentId: _selectedChildId,
        startDate: _startDate,
        endDate: _endDate,
      );
      _transactionsLoaded = true; // Mark as loaded even if empty
      appLog('GuardianVm: Loaded ${_transactions.length} transactions');
    } catch (e) {
      appLog('GuardianVm: Error loading transactions: $e');
      _transactions = []; // Clear transactions on error
      _transactionsLoaded =
          true; // Mark as loaded even on error to prevent retry loops
    } finally {
      _loadingTransactions = false;
      notifyListeners();
    }
  }

  Future<List<GuardianWithdrawal>> getPendingRequests({
    String? studentId,
  }) async {
    return await _repo.getPendingWithdrawals(studentId: studentId);
  }
}

class GuardianScope extends InheritedNotifier<GuardianVm> {
  const GuardianScope({
    super.key,
    required GuardianVm super.notifier,
    required super.child,
  });

  static GuardianVm of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<GuardianScope>();
      assert(
        scope != null,
        'GuardianScope.of() called with no GuardianScope in context',
      );
      return scope!.notifier!;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<GuardianScope>();
    final scope = element?.widget as GuardianScope?;
    assert(
      scope != null,
      'GuardianScope.of() called with no GuardianScope in context',
    );
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant GuardianScope oldWidget) =>
      notifier != oldWidget.notifier;
}
