// lib/features/notifications/data/notification_repo.dart
//
// Single Responsibility : owns all notification data access.
// Dependency Inversion  : callers depend on NotificationRepository (abstract),
//                         not on SupabaseNotificationRepository (concrete).
// DRY                   : reuses the project-wide RpcClient; no raw .from() calls.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lccu_finx/core/clients/rpc_client.dart';

final _sb = Supabase.instance.client;
final RpcClient _rpc = RpcClient(_sb);

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class NotificationRow {
  final String notificationId;
  final String title;
  final String message;
  final bool isRead;
  final String? entityType;
  final String? entityId;
  final DateTime createdAt;

  const NotificationRow({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.isRead,
    this.entityType,
    this.entityId,
    required this.createdAt,
  });

  NotificationRow copyWith({bool? isRead}) => NotificationRow(
    notificationId: notificationId,
    title: title,
    message: message,
    isRead: isRead ?? this.isRead,
    entityType: entityType,
    entityId: entityId,
    createdAt: createdAt,
  );

  factory NotificationRow.fromMap(Map<String, dynamic> m) => NotificationRow(
    notificationId: m['notification_id'] as String,
    title: m['title'] as String? ?? '',
    message: m['message'] as String? ?? '',
    isRead: m['is_read'] as bool? ?? false,
    entityType: m['entity_type'] as String?,
    entityId: m['entity_id'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

// ---------------------------------------------------------------------------
// Abstract interface (Dependency Inversion)
// ---------------------------------------------------------------------------
abstract class NotificationRepository {
  /// Returns the current user's notifications, newest first.
  Future<List<NotificationRow>> fetchAll({int limit = 50});

  /// Marks a single notification as read.
  Future<void> markRead(String notificationId);

  /// Marks all unread notifications as read.
  Future<void> markAllRead();
}

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<NotificationRow>> fetchAll({int limit = 50}) async {
    final rows = await _rpc.list(
      'my_notifications',
      params: {'p_limit': limit},
    );
    return rows.map(NotificationRow.fromMap).toList();
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }

  @override
  Future<void> markAllRead() async {
    await _client.rpc('mark_all_notifications_read');
  }
}
