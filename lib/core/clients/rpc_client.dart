import 'package:supabase_flutter/supabase_flutter.dart';

class RpcClient {
  final SupabaseClient client;
  const RpcClient(this.client);

  Future<List<Map<String, dynamic>>> list(
    String fn, {
    Map<String, dynamic>? params,
  }) async {
    final res = await client.rpc(fn, params: params);
    return (res as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>?> single(
    String fn, {
    Map<String, dynamic>? params,
  }) async {
    final rows = await list(fn, params: params);
    return rows.isEmpty ? null : rows.first;
  }
}

String? nullableId(String? value) {
  if (value == null || value.isEmpty || value == 'ALL') return null;
  return value;
}