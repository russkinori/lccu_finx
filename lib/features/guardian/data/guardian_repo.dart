import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/core/clients/rpc_client.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';

final _sb = Supabase.instance.client;
final RpcClient _rpc = RpcClient(_sb);

class GuardianChildRow {
  final String studentId;
  final String name;
  final double balance;
  final int pendingRequests;

  const GuardianChildRow({
    required this.studentId,
    required this.name,
    this.balance = 0,
    this.pendingRequests = 0,
  });

  GuardianChildRow copyWith({double? balance, int? pendingRequests}) {
    return GuardianChildRow(
      studentId: studentId,
      name: name,
      balance: balance ?? this.balance,
      pendingRequests: pendingRequests ?? this.pendingRequests,
    );
  }
}

class GuardianWithdrawal {
  final String requestId;
  final String studentId;
  final String studentName;
  final double amount;
  final DateTime requestedAt;
  final String status;
  final String? note;

  const GuardianWithdrawal({
    required this.requestId,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.requestedAt,
    required this.status,
    this.note,
  });
}

class GuardianHomeVm {
  final String guardianName;
  final List<GuardianChildRow> children;
  final GuardianWithdrawal? highlightedRequest;

  const GuardianHomeVm({
    required this.guardianName,
    required this.children,
    required this.highlightedRequest,
  });
}

class GuardianTransaction {
  final String txId;
  final String studentId;
  final String studentName;
  final DateTime date;
  final String type;
  final double amount;

  const GuardianTransaction({
    required this.txId,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.type,
    required this.amount,
  });
}

abstract class GuardianRepository {
  Future<GuardianHomeVm> getHome();
  Future<void> decideWithdrawal({
    required String requestId,
    required bool approve,
    String? note,
  });
  Future<List<GuardianTransaction>> getTransactionHistory({
    String? studentId,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<List<GuardianWithdrawal>> getPendingWithdrawals({String? studentId});
}

class SupabaseGuardianRepository implements GuardianRepository {
  SupabaseGuardianRepository(this._client, this._common);

  final SupabaseClient _client;
  final CommonRepository _common;

  Future<(String guardianId, String name)> _guardianIdentity() async {
    // Avoid direct reads of guardian table to prevent RLS recursion.
    // Use the function-backed RPC f_me_guardian to resolve current guardian_id.
    final guardianRow = await _rpc.single('f_me_guardian');
    if (guardianRow == null) {
      throw StateError('Guardian record not found for current user');
    }
    final name = await _common.getCurrentUserDisplayName(fallback: 'Guardian');
    return (guardianRow['guardian_id'] as String, name);
  }

  @override
  Future<GuardianHomeVm> getHome() async {
    final (_, guardianName) = await _guardianIdentity();

    final childrenRows = await _client.rpc('guardian_children_list');

    final children = <GuardianChildRow>[];
    for (final raw in (childrenRows as List? ?? const [])) {
      final row = (raw as Map).cast<String, dynamic>();
      children.add(
        GuardianChildRow(
          studentId: row['student_id'] as String,
          name: row['student_name'] as String? ?? 'Student',
          balance: (row['balance'] as num?)?.toDouble() ?? 0.0,
          pendingRequests: (row['pending_requests'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    GuardianWithdrawal? highlighted;
    final allPending = await getPendingWithdrawals();
    if (allPending.isNotEmpty) {
      // Show the most recent pending request first (server may return
      // an arbitrary ordering). Sort by `requestedAt` descending so the
      // latest request becomes the highlighted one.
      allPending.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      highlighted = allPending.first;
    }

    return GuardianHomeVm(
      guardianName: guardianName,
      children: children,
      highlightedRequest: highlighted,
    );
  }

  @override
  Future<void> decideWithdrawal({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    final decision = approve ? 'APPROVED' : 'DECLINED';
    try {
      await _client.rpc(
        'guardian_decide_withdrawal',
        params: {
          'p_request_id': requestId,
          'p_decision': decision,
          if (note != null && note.isNotEmpty) 'p_note': note,
        },
      );
    } catch (e) {
      // Normalize DB errors into a friendly error for the UI. The database
      // may raise a PostgresException when the current user is not the
      // guardian of the target student — surface a clear message instead of
      // the raw exception stack.
      final msg = e.toString();
      appLogError('guardian_decide_withdrawal RPC failed');
      if (msg.contains('not a guardian') ||
          msg.toLowerCase().contains('not a guardian')) {
        throw StateError('You are not a guardian of this student');
      }
      rethrow;
    }
  }

  @override
  Future<List<GuardianTransaction>> getTransactionHistory({
    String? studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final txRows = await _client.rpc(
      'guardian_transaction_history',
      params: {
        'p_student_id': studentId,
        'p_limit': 200,
      },
    );

    final transactions = <GuardianTransaction>[];
    for (final raw in (txRows as List? ?? const [])) {
      final row = (raw as Map).cast<String, dynamic>();

      transactions.add(
        GuardianTransaction(
          txId: row['transaction_id'] as String? ?? '',
          studentId: row['student_id'] as String? ?? '',
          studentName: row['student_name'] as String? ?? 'Student',
          date:
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
          type: row['tx_type'] as String? ?? '',
          amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }
    return transactions;
  }

  @override
  Future<List<GuardianWithdrawal>> getPendingWithdrawals({
    String? studentId,
  }) async {
    final rows = await _client.rpc(
      'guardian_pending_withdrawals',
      params: {
        'p_student_id': studentId,
      },
    );

    final withdrawals = <GuardianWithdrawal>[];
    for (final raw in (rows as List? ?? const [])) {
      final row = (raw as Map).cast<String, dynamic>();

      withdrawals.add(
        GuardianWithdrawal(
          requestId: row['request_id'] as String,
          studentId: row['student_id'] as String,
          studentName: row['student_name'] as String? ?? 'Student',
          amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
          requestedAt:
              DateTime.tryParse(row['requested_at'] as String? ?? '') ??
              DateTime.now(),
          status: row['status'] as String? ?? 'PENDING',
          note: row['notes'] as String?,
        ),
      );
    }
    return withdrawals;
  }
}
