import 'package:supabase_flutter/supabase_flutter.dart';

// Credentials are injected at build time via --dart-define-from-file=env.json.
// See env.json.example for the required keys. No default values are provided
// intentionally — a build missing the define-from-file flag will fail fast
// rather than silently connecting to production.
const _kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Call this during app startup before runApp.
/// Throws [AssertionError] in debug mode if the build defines are missing.
Future<void> initSupabase() async {
  assert(
    _kSupabaseUrl.isNotEmpty && _kSupabaseAnonKey.isNotEmpty,
    'Supabase credentials missing. Build with --dart-define-from-file=env.json',
  );
  await Supabase.initialize(
    url: _kSupabaseUrl,
    anonKey: _kSupabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

final supabase = Supabase.instance.client;
