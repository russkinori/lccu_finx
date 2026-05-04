import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lccu_finx/core/clients/rpc_client.dart';

import 'package:lccu_finx/app/roles.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';

final _sb = Supabase.instance.client;
final RpcClient _rpc = RpcClient(_sb);

/// Shared utilities for repositories that need access to the authenticated user
/// or cross-cutting lookups. Keeping these helpers in one place helps our
/// MVVM layers stay DRY and avoids leaking raw Supabase calls throughout the
/// feature repositories.
class CommonRepository {
  CommonRepository(this._client);

  final SupabaseClient _client;

  /// Returns the authenticated user's Supabase UID or throws if there is no
  /// active session.
  Future<String> requireAuthUserId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException('Not authenticated');
    }
    return user.id;
  }

  /// Loads the row from `public.user` that matches the current auth user. By
  /// default we fetch the common columns needed across dashboards, but callers
  /// can request additional fields via [columns].
  Future<Map<String, dynamic>> getCurrentUserRow({
    List<String>? columns,
  }) async {
    final authUserId = await requireAuthUserId();
    final row = await _rpc.single('f_me');

    if (row == null) {
      throw StateError('User row not found for auth id $authUserId');
    }

    if (columns == null || columns.isEmpty) {
      return row;
    }

    return <String, dynamic>{
      for (final column in columns) column: row[column],
    };
  }

  /// Convenience helper for fetching the authenticated user's full name. Falls
  /// back to a role label when the name fields are blank so the UI can always
  /// render something friendly.
  Future<String> getCurrentUserDisplayName({String fallback = 'User'}) async {
    try {
      final row = await getCurrentUserRow(columns: ['first_name', 'last_name']);
      final first = (row['first_name'] as String?)?.trim() ?? '';
      final last = (row['last_name'] as String?)?.trim() ?? '';
      final combined = '$first $last'.trim();
      return combined.isEmpty ? fallback : combined;
    } catch (e) {
      appLog('Warning: Unable to fetch user display name: $e');
      return fallback;
    }
  }

  /// Fetches the [AppRole] assignments for the authenticated user. When a role
  /// stored in the database is unknown to the client, it is silently ignored so
  /// that new roles can be rolled out server-side without breaking the app.
  Future<List<AppRole>> getCurrentUserRoles() async {
    await requireAuthUserId();
    final rows = await _rpc.list('f_me_role');

    final list = <AppRole>[];
    for (final row in rows) {
      final role = AppRoleX.tryParse(row['role_name'] as String?);
      if (role != null) {
        list.add(role);
      }
    }
    return list;
  }

  /// Returns the current week's start and end dates (UTC).
  /// Returns the current week's start and end dates (UTC), where the week
  /// starts on Sunday 00:00:00 and ends on Saturday 23:59:59.999999 (inclusive).
  ///
  /// Implementation notes:
  /// - Uses the current UTC date to compute boundaries so callers always
  ///   receive UTC-aligned values regardless of local timezone.
  /// - Dart `DateTime.weekday` is 1=Monday .. 7=Sunday; taking `weekday % 7`
  ///   maps Sunday -> 0, Monday -> 1, ..., Saturday -> 6 which yields the
  ///   number of days to subtract to reach the most recent Sunday.
  (DateTime start, DateTime end) getCurrentIsoWeek() {
    final nowUtc = DateTime.now().toUtc();

    // Midnight (00:00:00) at UTC for 'today'
    final todayMidnightUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

    // Map Sunday -> 0, Monday -> 1, ..., Saturday -> 6
    final daysToSubtract = nowUtc.weekday % 7;

    // Start is the most recent Sunday at 00:00:00 UTC
    final startUtc = todayMidnightUtc.subtract(Duration(days: daysToSubtract));

    // Inclusive end: next Sunday's midnight minus 1 microsecond (Saturday 23:59:59.999999)
    final endUtc = startUtc.add(const Duration(days: 7)).subtract(const Duration(microseconds: 1));

    return (startUtc, endUtc);
  }

  /// Formats a user's full name from first_name and last_name fields.
  /// Returns [fallback] if the combined name is empty.
  String formatUserName({
    required String? firstName,
    required String? lastName,
    String fallback = 'User',
  }) {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    final combined = '$first $last'.trim();
    return combined.isEmpty ? fallback : combined;
  }

  /// Batch lookup user names by user IDs.
  /// Returns a map of user_id -> formatted name.
  Future<Map<String, String>> getUserNamesByIds(
    List<String> userIds, {
    String fallback = 'User',
  }) async {
    if (userIds.isEmpty) return {};

    final rows = await _client.rpc(
      'user_names_by_ids',
      params: {'p_user_ids': userIds},
    );

    final nameByUser = <String, String>{};
    for (final r in (rows as List? ?? [])) {
      final userId = r['user_id'] as String;
      final name = formatUserName(
        firstName: r['first_name'] as String?,
        lastName: r['last_name'] as String?,
        fallback: fallback,
      );
      nameByUser[userId] = name;
    }
    return nameByUser;
  }
}
