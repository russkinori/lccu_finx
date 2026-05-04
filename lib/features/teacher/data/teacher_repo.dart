// lib/data/repositories/teacher_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/app/id_name.dart';
import 'package:lccu_finx/core/clients/rpc_client.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';

final _sb = Supabase.instance.client;
final RpcClient _rpc = RpcClient(_sb);

class TeacherTxRow {
  final String transactionId;
  final DateTime date;
  final String className;
  final String studentName;
  final String type;
  final double amount;
  const TeacherTxRow({
    required this.transactionId,
    required this.date,
    required this.className,
    required this.studentName,
    required this.type,
    required this.amount,
  });
}

class TeacherPendingWithdrawal {
  final String requestId;
  final DateTime requestedAt;
  final String studentName;
  final String? className;
  final double amount;
  final String? classId;
  final String? studentId;
  final String status; // Pending, Approved, Declined, Completed, etc.
  const TeacherPendingWithdrawal({
    required this.requestId,
    required this.requestedAt,
    required this.studentName,
    required this.className,
    required this.amount,
    this.classId,
    this.studentId,
    this.status = 'Pending',
  });
}

class TeacherHomeVM {
  final String teacherId;
  final String schoolId;
  final String teacherName;
  // Interpreted as "Funds In-Hand" on Teacher Home: sum of DEPOSIT tx for the current week
  final double scopedBalance;
  // Sum of current balances of the scoped students (after filters)
  final double accountBalanceTotal;
  final List<IdName> classes;
  final List<IdName> students;
  final List<TeacherTxRow> transactions;
  const TeacherHomeVM({
    required this.teacherId,
    required this.schoolId,
    required this.teacherName,
    required this.scopedBalance,
    required this.accountBalanceTotal,
    required this.classes,
    required this.students,
    required this.transactions,
  });
}

abstract class TeacherRepository {
  Future<TeacherHomeVM> getTeacherHome({String? classId, String? studentId});
  Future<List<IdName>> getClassesForSchool();
  Future<List<IdName>> getStudentsForSchool({String? classId});

  Future<List<TeacherPendingWithdrawal>> getPendingWithdrawals({
    String? classId,
    String? studentId,
  });
  Future<void> postWithdrawal({required String requestId});
  Future<List<TeacherPendingWithdrawal>> getAllWithdrawals({
    String? classId,
    String? studentId,
  });
  Future<void> completeWithdrawal({required String requestId});

  Future<void> createDeposit({
    required String studentId,
    required double amount,
    String? note,
  });

  Future<void> submitWithdrawalForStudent({
    required String studentId,
    required double amount,
    String? note,
  });
}

class SupabaseTeacherRepository implements TeacherRepository {
  final SupabaseClient _sb;
  final CommonRepository _common;
  SupabaseTeacherRepository(this._sb, this._common);

  Future<(String teacherId, String teacherName, String schoolId)>
  _getTeacherIdentity() async {
    final vm = await _rpc.single('f_me_teacher');
    if (vm != null) {
      // Resolve display name from the current user row
      final name = await _common.getCurrentUserDisplayName(fallback: 'Teacher');
      return (
        vm['teacher_id'] as String,
        name.isEmpty ? 'Teacher' : name,
        vm['school_id'] as String,
      );
    }

    final teacherId = await _sb.rpc('current_teacher_id');
    final schoolId = await _sb.rpc('current_teacher_school_id');
    if (teacherId == null || schoolId == null) {
      throw Exception('Teacher not found for current user');
    }

    final name = await _common.getCurrentUserDisplayName(fallback: 'Teacher');
    return (teacherId as String, name.isEmpty ? 'Teacher' : name, schoolId as String);
  }

  Future<List<IdName>> _getClassesUsedInSchool(String schoolId) async {
    // Use RPC to fetch teacher-scoped classes and map expected fields
    final rows = await _sb.rpc('teacher_classes_list');
    final seen = <String>{};
    final list = <IdName>[];
    for (final raw in (rows as List? ?? [])) {
      final r = (raw as Map).cast<String, dynamic>();
      final id = r['class_id'] as String?;
      if (id != null && seen.add(id)) {
        final name = (r['class_name'] as String?) ?? (r['name'] as String?) ?? '—';
        list.add(IdName(id: id, name: name));
      }
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<List<IdName>> getClassesForSchool() async {
    final (_, _, schoolId) = await _getTeacherIdentity();
    return _getClassesUsedInSchool(schoolId);
  }

  @override
  Future<List<IdName>> getStudentsForSchool({String? classId}) async {
    // Use RPC to fetch teacher-scoped students, passing optional class filter
    final rows = await _sb.rpc(
      'teacher_students_list',
      params: {
        'p_class_id':
            (classId != null && classId.isNotEmpty && classId != 'ALL')
                ? classId
                : null,
      },
    );

    final byId = <String, String>{};
    for (final raw in (rows as List? ?? [])) {
      final r = (raw as Map).cast<String, dynamic>();
      final sid = r['student_id'] as String?;
      if (sid == null) continue;
      final firstName = (r['first_name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final lastName = (r['last_name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final nm = '$firstName $lastName'.trim();
      byId[sid] = nm.isEmpty ? 'Student' : nm;
    }

    final students =
        byId.entries.map((e) => IdName(id: e.key, name: e.value)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  // Note: Account balances can be computed via student_acc.closing_bal if needed.

  @override
  Future<TeacherHomeVM> getTeacherHome({
    String? classId,
    String? studentId,
  }) async {
    final (teacherId, teacherName, schoolId) = await _getTeacherIdentity();
    appLog('TeacherRepo identity resolved');

    final classes = await _getClassesUsedInSchool(schoolId);
    appLog('TeacherRepo classes loaded');

    final students = await getStudentsForSchool(classId: classId);
    appLog('TeacherRepo students loaded');

    // Transactions - use RPC to fetch teacher transaction history
    final rows = await _sb.rpc(
      'teacher_transaction_history',
      params: {
        'p_class_id':
            (classId != null && classId.isNotEmpty && classId != 'ALL')
                ? classId
                : null,
        'p_student_id':
            (studentId != null && studentId.isNotEmpty && studentId != 'ALL')
                ? studentId
                : null,
        'p_limit': 200,
      },
    );

    final fetched = (rows as List? ?? [])
        .map((m) => (m as Map).cast<String, dynamic>())
        .toList();
    appLog('TeacherRepo transactions loaded');
    if (fetched.isNotEmpty) {
      appLog('TeacherRepo first transaction row keys available');
      appLog('TeacherRepo first transaction row sample suppressed');
    }

    // Deduplicate by transaction_id if present (some views may duplicate rows due to joins)
    final seen = <String>{};
    final txs = <TeacherTxRow>[];
    for (final r in fetched) {
      final tid = (r['transaction_id'] ?? r['tx_id'] ?? r['id'])?.toString();
      // If we have an explicit transaction id, use it to dedupe. Otherwise, fall back
      // to a composite key of created_at+student+amount to avoid obvious duplicates.
      final key =
          tid ??
          '${r['created_at'] ?? ''}::${r['student_id'] ?? r['student_first_name'] ?? ''}::${r['amount'] ?? ''}';
      if (!seen.add(key)) continue;

      final firstName = (r['student_first_name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final lastName = (r['student_last_name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final sname = '$firstName $lastName'.trim();
      final clsName = (r['class_name'] ?? r['name'] ?? '—') as String;

      txs.add(
        TeacherTxRow(
          transactionId: tid ?? key,
          date:
              DateTime.tryParse(r['created_at'] as String? ?? '') ??
              DateTime.now(),
          className: clsName,
          studentName: sname.isEmpty ? '—' : sname,
          type: (r['tx_type'] ?? 'Unknown') as String,
          amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    // Fetch teacher home aggregated metrics (funds in-hand and account balance total)
    final metrics = await _rpc.single(
      'teacher_home_metrics',
      params: {
        'p_class_id': nullableId(classId),
        'p_student_id': nullableId(studentId),
      },
    );

    final scopedBalance = (metrics?['funds_in_hand'] as num?)?.toDouble() ?? 0.0;
    final accountBalanceTotal =
        (metrics?['account_balance_total'] as num?)?.toDouble() ?? 0.0;

    return TeacherHomeVM(
      teacherId: teacherId,
      schoolId: schoolId,
      teacherName: teacherName,
      scopedBalance: scopedBalance,
      accountBalanceTotal: accountBalanceTotal,
      classes: classes,
      students: students,
      transactions: txs,
    );
  }

  @override
  Future<List<TeacherPendingWithdrawal>> getPendingWithdrawals({
    String? classId,
    String? studentId,
  }) async {
    // Try to filter server-side first. If the view does not expose `class_id`
    // (Postgres error 42703), fall back to fetching rows and applying a
    // client-side class filter using `vw_teacher_students` to derive class ids.
    // Use RPC to fetch teacher pending withdrawals with optional filters.
    final rows = await _rpc.list(
      'teacher_pending_withdrawals',
      params: {
        'p_class_id': nullableId(classId),
        'p_student_id': nullableId(studentId),
      },
    );

    final listRows = (rows as List? ?? []).map((r) {
      return (r as Map).cast<String, dynamic>();
    }).toList();

    return listRows.map((r) {
      return TeacherPendingWithdrawal(
        requestId: r['request_id'] as String,
        requestedAt: DateTime.tryParse(r['requested_at'] as String? ?? '') ??
            DateTime.now(),
        studentName: (r['student_name'] ?? r['name'] ?? '—') as String,
        className: (r['class_name'] ?? r['class']) as String?,
        amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
        classId: (r['class_id'] ?? r['classId']) as String?,
        studentId: (r['student_id'] ?? r['studentId']) as String?,
        status: (r['status'] as String?) ?? 'PENDING',
      );
    }).toList();
  }

  @override
  Future<void> postWithdrawal({required String requestId}) async {
    // Resolve teacher identity and try RPC with several parameter encodings to
    // handle function signature/name variations in different DB deployments.
    final (teacherId, _, _) = await _getTeacherIdentity();
    await _rpcWithFallback('teacher_post_withdrawal', [
      {'p_request_id': requestId, 'p_teacher_id': teacherId},
      {'request_id': requestId, 'teacher_id': teacherId},
      [requestId, teacherId],
    ]);
  }

  @override
  Future<void> completeWithdrawal({required String requestId}) async {
    // If your API uses a different RPC name for completing, adjust here.
    // We reuse post call as "Complete" action per current backend naming.
    final (teacherId, _, _) = await _getTeacherIdentity();
    await _rpcWithFallback('teacher_post_withdrawal', [
      {'p_request_id': requestId, 'p_teacher_id': teacherId},
      {'request_id': requestId, 'teacher_id': teacherId},
      [requestId, teacherId],
    ]);
  }

  // Helper: try calling an RPC using multiple parameter formats until one works.
  Future<dynamic> _rpcWithFallback(
    String name,
    List<dynamic> paramVariants,
  ) async {
    dynamic lastError;
    for (final params in paramVariants) {
      try {
        return await _sb.rpc(name, params: params);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        // If it's a signature mismatch / function not found, try next variant.
        if (msg.contains('could not find the function') ||
            msg.contains('no matches were found') ||
            msg.contains('parameter')) {
          lastError = e;
          continue;
        }
        rethrow;
      }
    }
    if (lastError != null) throw lastError;
    return null;
  }

  @override
  Future<void> createDeposit({
    required String studentId,
    required double amount,
    String? note,
  }) async {
    // Call server RPC using parameter names that match the DB function signature.
    try {
      await _sb.rpc(
        'teacher_create_deposit',
        params: {'p_student_id': studentId, 'p_amount': amount, 'p_note': note},
      );
      appLog('TeacherRepo createDeposit RPC completed');
    } catch (e, st) {
      appLogError(e, st);
      rethrow;
    }
  }

  @override
  Future<void> submitWithdrawalForStudent({
    required String studentId,
    required double amount,
    String? note,
  }) async {
    await _sb.rpc(
      'teacher_submit_withdrawal_for_student',
      params: {
        'p_student_id': studentId,
        'p_amount': amount,
        'p_reason': null,
        'p_notes': note,
      },
    );
  }

  @override
  Future<List<TeacherPendingWithdrawal>> getAllWithdrawals({
    String? classId,
    String? studentId,
  }) async {
    final rows = await _rpc.list(
      'teacher_withdrawals_list',
      params: {
        'p_class_id': nullableId(classId),
        'p_student_id': nullableId(studentId),
        'p_limit': 500,
      },
    );

    return rows.map((r) {
      return TeacherPendingWithdrawal(
        requestId: r['request_id'] as String,
        requestedAt: DateTime.tryParse(r['requested_at'] as String? ?? '') ??
            DateTime.now(),
        studentName: (r['student_name'] as String?)?.trim().isNotEmpty == true
            ? (r['student_name'] as String).trim()
            : 'Student',
        className: r['class_name'] as String?,
        amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
        classId: r['class_id'] as String?,
        studentId: r['student_id'] as String?,
        status: (r['status'] as String?) ?? 'PENDING',
      );
    }).toList();
  }

}
