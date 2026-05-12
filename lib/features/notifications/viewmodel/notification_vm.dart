// lib/features/notifications/viewmodel/notification_vm.dart
//
// Single Responsibility : manages notification state for the UI.
// Open/Closed           : new refresh strategies (e.g. real-time) can be
//                         plugged in without touching the widget layer.
// DRY                   : error handling follows the same friendlyActionError
//                         pattern used by every other VM in the project.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lccu_finx/core/widgets/friendly_error.dart';
import 'package:lccu_finx/features/notifications/data/notification_repo.dart';

class NotificationVm extends ChangeNotifier {
  NotificationVm({required NotificationRepository repo}) : _repo = repo;

  final NotificationRepository _repo;

  List<NotificationRow> _items = const [];
  bool _loading = false;
  String? _error;

  List<NotificationRow> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Number of unread notifications — drives the badge count on the bell icon.
  int get unreadCount => _items.where((n) => !n.isRead).length;

  // -------------------------------------------------------------------------
  // Fetch
  // -------------------------------------------------------------------------
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repo
          .fetchAll()
          .timeout(
            const Duration(seconds: 8),
            onTimeout:
                () => throw TimeoutException('Notifications fetch timed out'),
          );
    } catch (e) {
      _error = friendlyActionError('Failed to load notifications.', e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Mark single read (optimistic update — revert on error)
  // -------------------------------------------------------------------------
  Future<void> markRead(String notificationId) async {
    final prev = List<NotificationRow>.from(_items);
    _items = _items
        .map((n) => n.notificationId == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    notifyListeners();
    try {
      await _repo.markRead(notificationId);
    } catch (_) {
      _items = prev; // revert
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Mark all read (optimistic update)
  // -------------------------------------------------------------------------
  Future<void> markAllRead() async {
    final prev = List<NotificationRow>.from(_items);
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    try {
      await _repo.markAllRead();
    } catch (_) {
      _items = prev; // revert
      notifyListeners();
    }
  }
}

// ---------------------------------------------------------------------------
// InheritedNotifier scope — Separation of Concerns:
// the scope owns widget-tree distribution; VM owns state.
// ---------------------------------------------------------------------------
class NotificationScope extends InheritedNotifier<NotificationVm> {
  const NotificationScope({
    super.key,
    required NotificationVm vm,
    required super.child,
  }) : super(notifier: vm);

  static NotificationVm of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NotificationScope>();
    assert(scope != null, 'No NotificationScope found in widget tree');
    return scope!.notifier!;
  }
}
