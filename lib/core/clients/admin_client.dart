import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lccu_finx/core/utils/app_logger.dart';

/// Helper to invoke the central admin edge function and normalize responses.
///
/// This is a thin wrapper around `SupabaseClient.functions.invoke` that handles
/// common string/json normalization and error bubbling so callers can work with
/// a `Map<String, dynamic>` result.
Future<Map<String, dynamic>> invokeAdminEdge(
  SupabaseClient client,
  String functionName,
  String action,
  Map<String, dynamic> payload,
) async {
  final response = await client.functions.invoke(
    functionName,
    body: {'action': action, ...payload, 'payload': payload},
  );

  appLog('Edge function $functionName returned status ${response.status}');
  appLog('Edge function $functionName response received');

  dynamic raw = response.data;
  if (raw == null) {
    return <String, dynamic>{};
  }

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};
    final startsLikeJson =
        (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'));
    if (startsLikeJson) {
      raw = json.decode(trimmed);
    } else {
      return <String, dynamic>{'message': raw};
    }
  }

  if (raw is Map) {
    final map = raw.cast<String, dynamic>();
    final edgeError = map['error'];
    if (edgeError != null) {
      throw StateError('Edge function "$action" error: $edgeError');
    }
    if (map['data'] is Map) {
      final nested = (map['data'] as Map).cast<String, dynamic>();
      final merged = <String, dynamic>{...map, ...nested};
      merged.remove('data');
      return merged;
    }
    return map;
  }

  if (raw is List) {
    return <String, dynamic>{'data': raw};
  }

  throw StateError('Unexpected response from "$action": $raw');
}
