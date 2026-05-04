import 'package:supabase_flutter/supabase_flutter.dart';

// Credentials are injected at build time via --dart-define or --dart-define-from-file.
// Example: flutter run --dart-define-from-file=env.json
// See env.json.example for the required keys.
const _kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://juzpizqbhxkncxfpdlxd.supabase.co',
);
const _kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_usOYNoES7RokrkzH01VvQA_b0-PN0V2',
);

/// Call this during app startup before runApp.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: _kSupabaseUrl,
    anonKey: _kSupabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

final supabase = Supabase.instance.client;
