import 'package:supabase_flutter/supabase_flutter.dart';

import 'common_repo.dart';
import 'rpc_client.dart';

final _sb = Supabase.instance.client;
final RpcClient _rpc = RpcClient(_sb);

class StudentTransactionRow {
  final String transactionId;
  final DateTime createdAt;
  final String transaction;
  final double amount;

  const StudentTransactionRow({
    required this.transactionId,
    required this.createdAt,
    required this.transaction,
    required this.amount,
  });
}

class StudentWithdrawalRow {
  final String requestId;
  final DateTime requestedAt;
  final String status;
  final double amount;
  final String? note;

  const StudentWithdrawalRow({
    required this.requestId,
    required this.requestedAt,
    required this.status,
    required this.amount,
    this.note,
  });
}

class StudentHomeVm {
  final String studentId;
  final String accountId;
  final String studentName;
  final double balance;
  final List<StudentTransactionRow> transactions;
  final StudentWithdrawalRow? latestWithdrawal;

  const StudentHomeVm({
    required this.studentId,
    required this.accountId,
    required this.studentName,
    required this.balance,
    required this.transactions,
    required this.latestWithdrawal,
  });
}

abstract class StudentRepository {
  Future<StudentHomeVm> getHome();
  Future<void> requestWithdrawal({
    required String accountId,
    required String studentId,
    required double amount,
    String? reason,
    String? note,
  });
}

class SupabaseStudentRepository implements StudentRepository {
  SupabaseStudentRepository(this._client, this._common);

  final SupabaseClient _client;
  final CommonRepository _common;

  @override
  Future<StudentHomeVm> getHome() async {
    final studentName = await _common.getCurrentUserDisplayName(
      fallback: 'Student',
    );

    final home = await _rpc.single('student_home');
    if (home == null) {
      throw StateError('Student home record not found for current user');
    }

    final studentId = home['student_id'] as String?;
    final accountId = home['account_id'] as String?;
    if (studentId == null || studentId.isEmpty) {
      throw StateError('Student record not found for current user');
    }
    if (accountId == null || accountId.isEmpty) {
      throw StateError('No student account found for current user');
    }

    final balance = (home['balance'] as num?)?.toDouble() ?? 0.0;

    final txRows = await _client.rpc(
      'student_transaction_history',
      params: {'p_limit': 25},
    );

    final transactions = <StudentTransactionRow>[];
    for (final raw in (txRows as List? ?? const [])) {
      final row = (raw as Map).cast<String, dynamic>();
      transactions.add(
        StudentTransactionRow(
          transactionId: row['transaction_id'] as String,
          createdAt:
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
          transaction: row['tx_type'] as String? ?? 'Transaction',
          amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    StudentWithdrawalRow? withdrawal;
    final latestRequestId = home['latest_request_id'] as String?;
    if (latestRequestId != null && latestRequestId.isNotEmpty) {
      withdrawal = StudentWithdrawalRow(
        requestId: latestRequestId,
        requestedAt:
            DateTime.tryParse(
              home['latest_request_requested_at'] as String? ?? '',
            ) ??
            DateTime.now(),
        status: home['latest_request_status'] as String? ?? 'Pending',
        amount: (home['latest_request_amount'] as num?)?.toDouble() ?? 0.0,
        note: home['latest_request_notes'] as String?,
      );
    }

    return StudentHomeVm(
      studentId: studentId,
      accountId: accountId,
      studentName: studentName,
      balance: balance,
      transactions: transactions,
      latestWithdrawal: withdrawal,
    );
  }

  @override
  Future<void> requestWithdrawal({
    required String accountId,
    required String studentId,
    required double amount,
    String? reason,
    String? note,
  }) async {
    // Always pass both p_reason and p_notes (explicit null allowed) to avoid
    // ambiguity when PostgREST/Postgres resolves overloaded functions.
    await _client.rpc(
      'request_withdrawal',
      params: {
        'p_student_id': studentId,
        'p_amount': amount,
        'p_reason': reason,
        'p_notes': note,
      },
    );
  }
}
