import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFilesUnder(String directory) sync* {
  final root = Directory(directory);
  if (!root.existsSync()) return;

  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

void main() {
  group('Security hardening regression checks', () {
    test('lib does not use direct Supabase table access', () {
      final offenders = <String>[];
      final directTablePattern = RegExp(r'\.from\s*\(');

      for (final file in _dartFilesUnder('lib')) {
        final contents = file.readAsStringSync();
        if (directTablePattern.hasMatch(contents)) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Sensitive data access should go through RPCs or Edge Functions, '
            'not direct Supabase .from(...) table calls.',
      );
    });

    test('lib does not use print or debugPrint outside app_logger.dart', () {
      final offenders = <String>[];
      final rawLoggingPattern = RegExp(r'\b(print|debugPrint)\s*\(');

      for (final file in _dartFilesUnder('lib')) {
        if (file.path.endsWith('app_logger.dart')) continue;

        final contents = file.readAsStringSync();
        if (rawLoggingPattern.hasMatch(contents)) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Use appLog/appLogError so logs are assert-only and stripped from '
            'release builds.',
      );
    });

    test('Phase 2 RPC migration files are present', () {
      const expectedMigrations = [
        'supabase/migrations/202605020001_teacher_withdrawals_list.sql',
        'supabase/migrations/202605020002_teller_read_rpcs.sql',
        'supabase/migrations/202605020003_principal_read_rpcs.sql',
        'supabase/migrations/202605020004_admin_read_role_rpcs.sql',
      ];

      final missing = expectedMigrations
          .where((path) => !File(path).existsSync())
          .toList();

      expect(missing, isEmpty);
    });

    test('current-user role resolution does not require admin RPCs', () {
      final file = File('lib/admin_repo.dart');
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      expect(
        contents,
        contains("rpc('current_user_role_names')"),
        reason:
            'Login for non-admin roles must use the existing current_user_role_names() RPC.',
      );
      expect(
        contents,
        contains("'admin_user_role_names'"),
        reason:
            'Admin views can still use admin_user_role_names() for other users.',
      );
    });

    test('new Phase 2 RPCs are documented in migration files', () {
      const expectedRpcNames = [
        'teacher_withdrawals_list',
        'teller_home_rows',
        'teller_school_deposit_snapshot',
        'teller_deposit_events_list',
        'teller_school_payouts_list',
        'principal_school_account_balance',
        'principal_student_balance',
        'principal_reconcile_week_data',
        'principal_teacher_deposit_history',
        'principal_school_outstanding_deposit_detail',
        'principal_teacher_outstanding_deposit_detail',
        'admin_user_role_names',
        'admin_schools_lookup',
        'admin_classes_for_school',
        'admin_guardian_types_lookup',
        'admin_credit_unions_lookup',
        'admin_user_profiles',
        'admin_school_deposits_report',
        'user_names_by_ids',
      ];

      final migrationDir = Directory('supabase/migrations');
      final migrationText = migrationDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      final missing = expectedRpcNames
          .where((name) => !migrationText.contains('function public.$name'))
          .toList();

      expect(missing, isEmpty);
    });
  });
}
