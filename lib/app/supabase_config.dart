import 'package:supabase_flutter/supabase_flutter.dart';

// Credentials are injected at build time via --dart-define or --dart-define-from-file.
// Example: flutter run --dart-define-from-file=env.json
// See env.json.example for the required keys.
const _kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Call this during app startup before runApp.
Future<void> initSupabase() async {
  assert(
    _kSupabaseUrl.isNotEmpty && _kSupabaseAnonKey.isNotEmpty,
    'Missing Supabase credentials. Build with: flutter run --dart-define-from-file=env.json',
  );
  if (_kSupabaseUrl.isEmpty || _kSupabaseAnonKey.isEmpty) {
    throw StateError(
      'Supabase credentials not provided. '
      'Build with: flutter run --dart-define-from-file=env.json',
    );
  }
  await Supabase.initialize(
    url: _kSupabaseUrl,
    anonKey: _kSupabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

final supabase = Supabase.instance.client;
