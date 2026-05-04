import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Repository RPC contract checks', () {
    test('student repository uses student RPC boundary', () {
      final source = _read('lib/features/student/data/student_repo.dart');

      expect(source, contains("'student_home'"));
      expect(source, contains("'student_transaction_history'"));
      expect(source, contains("'request_withdrawal'"));
      expect(source, isNot(contains(".from('student'")));
      expect(source, isNot(contains(".from('student_acc'")));
      expect(source, isNot(contains(".from('withdrawal_req'")));
    });

    test('guardian repository uses guardian RPC boundary', () {
      final source = _read('lib/features/guardian/data/guardian_repo.dart');

      expect(source, contains("'f_me_guardian'"));
      expect(source, contains("'guardian_children_list'"));
      expect(source, contains("'guardian_pending_withdrawals'"));
      expect(source, contains("'guardian_transaction_history'"));
      expect(source, contains("'guardian_decide_withdrawal'"));
      expect(source, isNot(contains(".from('guardian'")));
      expect(source, isNot(contains(".from('student_guardian'")));
      expect(source, isNot(contains(".from('withdrawal_req'")));
    });

    test('teacher repository uses teacher RPC boundary', () {
      final source = _read('lib/features/teacher/data/teacher_repo.dart');

      const requiredRpcs = [
        'f_me_teacher',
        'current_teacher_id',
        'current_teacher_school_id',
        'teacher_classes_list',
        'teacher_students_list',
        'teacher_transaction_history',
        'teacher_home_metrics',
        'teacher_pending_withdrawals',
        'teacher_post_withdrawal',
        'teacher_create_deposit',
        'teacher_submit_withdrawal_for_student',
        'teacher_withdrawals_list',
      ];

      for (final rpc in requiredRpcs) {
        expect(source, contains("'$rpc'"), reason: 'Missing RPC: $rpc');
      }
      expect(source, isNot(contains(".from('withdrawal_req'")));
      expect(source, isNot(contains(".from('teacher_coll'")));
      expect(source, isNot(contains(".from('transactions'")));
      expect(source, isNot(contains(".from('student'")));
    });

    test('teller repository uses teller RPC boundary', () {
      final source = _read('lib/features/teller/data/teller_repo.dart');

      const requiredRpcs = [
        'teller_home_rows',
        'teller_school_deposit_snapshot',
        'teller_deposit_events_list',
        'teller_school_payouts_list',
        'teller_list_teachers_for_school',
        'teller_pending_deposit_batches',
        'teller_teacher_deposit_details',
        'teller_post_school_deposit_event',
        'teller_post_school_payout',
      ];

      for (final rpc in requiredRpcs) {
        expect(source, contains("'$rpc'"), reason: 'Missing RPC: $rpc');
      }
      expect(source, isNot(contains(".from('school'")));
      expect(source, isNot(contains(".from('school_acc'")));
      expect(source, isNot(contains(".from('cu_dep_event'")));
      expect(source, isNot(contains(".from('cu_payout'")));
    });

    test('principal repository uses principal RPC boundary', () {
      final source = _read('lib/features/principal/data/principal_repo.dart');

      const requiredRpcs = [
        'current_principal_id',
        'current_principal_school_id',
        'principal_teachers_list',
        'principal_students_list',
        'principal_transaction_history',
        'principal_school_account_balance',
        'principal_student_balance',
        'principal_reconcile_week_data',
        'principal_teacher_deposit_history',
        'principal_school_outstanding_deposit_detail',
        'principal_teacher_outstanding_deposit_detail',
      ];

      for (final rpc in requiredRpcs) {
        expect(source, contains("'$rpc'"), reason: 'Missing RPC: $rpc');
      }
      expect(source, isNot(contains(".from('principal'")));
      expect(source, isNot(contains(".from('teacher'")));
      expect(source, isNot(contains(".from('student'")));
      expect(source, isNot(contains(".from('school_acc'")));
    });

    test('admin repository keeps admin-wide reads behind RPC or Edge Function', () {
      final source = _read('lib/features/admin/data/admin_repo.dart');

      const requiredRpcs = [
        'admin_dashboard_metrics',
        'admin_user_profiles',
        'admin_user_role_names',
        'admin_assign_role',
        'admin_remove_role',
        'admin_schools_lookup',
        'admin_classes_for_school',
        'admin_guardian_types_lookup',
        'admin_credit_unions_lookup',
        'admin_school_deposits_report',
        'admin_transaction_report',
      ];

      for (final rpc in requiredRpcs) {
        expect(source, contains("'$rpc'"), reason: 'Missing RPC: $rpc');
      }
      expect(source, contains('functions.invoke'));
      expect(source, isNot(contains('.from(')));
    });
  });
}
