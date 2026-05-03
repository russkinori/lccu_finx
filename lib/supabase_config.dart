import 'package:supabase_flutter/supabase_flutter.dart';

/// Call this during app startup before runApp.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://juzpizqbhxkncxfpdlxd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1enBpenFiaHhrbmN4ZnBkbHhkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU4MDEzODUsImV4cCI6MjA3MTM3NzM4NX0.9ShR3u3JbP8_qNac9_LlfW1Y52y4wTlzsdstWitvLUA',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

final supabase = Supabase.instance.client;
