import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/app/id_name.dart';
import 'package:lccu_finx/core/clients/rpc_client.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';


class TellerSchoolRow {
  final String schoolId;
  final String schoolName;
  final double accountBalance;
  final double pendingDeposit;
  final double latestDiscrepancy;

  const TellerSchoolRow({
    required this.schoolId,
    required this.schoolName,
    required this.accountBalance,
    required this.pendingDeposit,
    required this.latestDiscrepancy,
  });
}

class CuDepositRow {
  final String schoolId;
  final String teacherId;
  final String postedByTellerId;
  final DateTime postedAt;
  final double amount;
  final double discrepancy;
  final String status;
  final String notes;

  const CuDepositRow({
    required this.schoolId,
    required this.teacherId,
    required this.postedByTellerId,
    required this.postedAt,
    required this.amount,
    required this.discrepancy,
    required this.status,
    required this.notes,
  });
}

class CuPayoutRow {
  final String schoolId;
  final String requestId;
  final String postedByTellerId;
  final DateTime postedAt;
  final double amount;
  final String note;
  final String? requestedByRole;
  final String? requestedByTeacherId;
  final String? requestedByPrincipalId;

  const CuPayoutRow({
    required this.schoolId,
    required this.requestId,
    required this.postedByTellerId,
    required this.postedAt,
    required this.amount,
    required this.note,
    required this.requestedByRole,
    required this.requestedByTeacherId,
    required this.requestedByPrincipalId,
  });
}

class DepositBatchRow {
  final String batchId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final double expectedAmount;
  final double depositedAmount;
  final double remainingAmount;
  final String note;

  const DepositBatchRow({
    required this.batchId,
    required this.weekStart,
    required this.weekEnd,
    required this.expectedAmount,
    required this.depositedAmount,
    required this.remainingAmount,
    this.note = '',
  });
}

abstract class TellerRepository {
  Future<List<TellerSchoolRow>> getTellerHomeRows();
  Future<List<IdName>> getTeachersForSchool(String schoolId);

  Future<(double depositDue, double deposited, double discrepancy)>
  getSchoolDepositSnapshot(String schoolId);

  Future<(double, double, double)> getTeacherDepositDetails(
    String schoolId,
    String teacherId,
  );

  Future<List<CuDepositRow>> fetchCreditUnionDeposits({
    required DateTime from,
    required DateTime to,
    String? schoolId,
    String? teacherId,
    int limit,
  });

  Future<List<CuPayoutRow>> fetchSchoolPayouts({
    required DateTime from,
    required DateTime to,
    String? schoolId,
    int limit,
  });

  Future<void> confirmDeposit({
    required String schoolId,
    required String teacherId,
    required double amount,
    required double discrepancy,
    String? notes,
    List<String>? batchIds,
  });

  Future<List<DepositBatchRow>> fetchPendingDepositBatches(String schoolId);

  Future<DepositBatchRow?> getBatchMatch({
    required String schoolId,
    required String batchId,
    required double amount,
  });

  Future<String> postSchoolPayout({
    required String schoolId,
    required String requestId,
    required double amount,
    String? note,
    String? requestedByTeacherId,
    String? requestedByPrincipalId,
  });
}

class SupabaseTellerRepository implements TellerRepository {
  final SupabaseClient _sb;
  final CommonRepository _common;
  final RpcClient _rpc;

  SupabaseTellerRepository(this._sb, this._common)
      : _rpc = RpcClient(_sb);

  @override
  Future<List<TellerSchoolRow>> getTellerHomeRows() async {
    final (weekStartDt, weekEndDt) = _common.getCurrentIsoWeek();

    final rows = await _rpc.list(
      'teller_home_rows',
      params: {
        'p_week_start': weekStartDt.toUtc().toIso8601String(),
        'p_week_end': weekEndDt.toUtc().toIso8601String(),
      },
    );

    final out = <TellerSchoolRow>[];
    for (final row in rows) {
      final schoolId = row['school_id'] as String?;
      if (schoolId == null) continue;

      out.add(
        TellerSchoolRow(
          schoolId: schoolId,
          schoolName: (row['school_name'] as String?) ?? 'School',
          accountBalance: (row['account_balance'] as num?)?.toDouble() ?? 0.0,
          pendingDeposit: (row['pending_deposit'] as num?)?.toDouble() ?? 0.0,
          latestDiscrepancy:
              (row['latest_discrepancy'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    out.sort((a, b) => a.schoolName.compareTo(b.schoolName));
    return out;
  }

  @override
  Future<List<IdName>> getTeachersForSchool(String schoolId) async {
    final rows = await _rpc.list(
      'teller_list_teachers_for_school',
      params: {'p_school_id': schoolId},
    );

    final out = <IdName>[];
    for (final row in rows) {
      final teacherId = row['teacher_id'] as String?;
      if (teacherId == null) continue;

      final firstName = (row['first_name'] as String?) ?? '';
      final lastName = (row['last_name'] as String?) ?? '';
      final name = ('$firstName $lastName').trim();

      out.add(IdName(id: teacherId, name: name.isEmpty ? 'Teacher' : name));
    }

    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<(double depositDue, double deposited, double discrepancy)>
  getSchoolDepositSnapshot(String schoolId) async {
    final (weekStartDt, weekEndDt) = _common.getCurrentIsoWeek();

    final row = await _rpc.single(
      'teller_school_deposit_snapshot',
      params: {
        'p_school_id': schoolId,
        'p_week_start': weekStartDt.toUtc().toIso8601String(),
        'p_week_end': weekEndDt.toUtc().toIso8601String(),
      },
    );

    if (row == null || row.isEmpty) return (0.0, 0.0, 0.0);

    // deposit_due = full batch expected_amount (can include already-deposited
    // amounts when a DEPOSITED batch is re-opened).
    // discrepancy = remaining_amount = expected minus already posted — the
    // number the teller actually still needs to collect.
    return (
      (row['deposit_due'] as num?)?.toDouble() ?? 0.0,
      (row['deposited'] as num?)?.toDouble() ?? 0.0,
      (row['disparity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  Future<(double, double, double)> getTeacherDepositDetails(
    String schoolId,
    String teacherId,
  ) async {
    try {
      final detail = await _rpc.single(
        'teller_teacher_deposit_details',
        params: {'p_school_id': schoolId, 'p_teacher_id': teacherId},
      );

      if (detail == null || detail.isEmpty) return (0.0, 0.0, 0.0);

      final due = (detail['deposit_due'] as num?)?.toDouble() ?? 0.0;
      final dep = (detail['deposited'] as num?)?.toDouble() ?? 0.0;
      final diff = (detail['difference'] as num?)?.toDouble() ?? 0.0;
      return (due, dep, diff);
    } catch (e) {
      appLogError(e);
      rethrow;
    }
  }

  @override
  Future<List<CuDepositRow>> fetchCreditUnionDeposits({
    required DateTime from,
    required DateTime to,
    String? schoolId,
    String? teacherId,
    int limit = 5000,
  }) async {
    final rows = await _rpc.list(
      'teller_deposit_events_list',
      params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
        'p_school_id': nullableId(schoolId),
        'p_teacher_id': nullableId(teacherId),
        'p_limit': limit,
      },
    );

    final out = <CuDepositRow>[];
    for (final row in rows) {
      final postedAtRaw = row['posted_at'];
      final postedAt = postedAtRaw is String
          ? (DateTime.tryParse(postedAtRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0))
          : DateTime.fromMillisecondsSinceEpoch(0);

      out.add(
        CuDepositRow(
          schoolId: (row['school_id'] as String?) ?? '',
          teacherId: (row['teacher_id'] as String?) ?? '',
          postedByTellerId: (row['posted_by_teller_id'] as String?) ?? '',
          postedAt: postedAt,
          amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
          discrepancy: (row['discrepancy'] as num?)?.toDouble() ?? 0.0,
          status: (row['status'] as String?) ?? '',
          notes: (row['notes'] as String?) ?? '',
        ),
      );
    }

    return out;
  }

  @override
  Future<List<CuPayoutRow>> fetchSchoolPayouts({
    required DateTime from,
    required DateTime to,
    String? schoolId,
    int limit = 5000,
  }) async {
    final rows = await _rpc.list(
      'teller_school_payouts_list',
      params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
        'p_school_id': nullableId(schoolId),
        'p_limit': limit,
      },
    );

    final out = <CuPayoutRow>[];
    for (final row in rows) {
      final postedAtRaw = row['posted_at'];
      final postedAt = postedAtRaw is String
          ? (DateTime.tryParse(postedAtRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0))
          : DateTime.fromMillisecondsSinceEpoch(0);

      out.add(
        CuPayoutRow(
          schoolId: (row['school_id'] as String?) ?? '',
          requestId: (row['request_id'] as String?) ?? '',
          postedByTellerId: (row['posted_by_teller_id'] as String?) ?? '',
          postedAt: postedAt,
          amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
          note: (row['note'] as String?) ?? '',
          requestedByRole: row['requested_by_role'] as String?,
          requestedByTeacherId: row['requested_by_teacher_id'] as String?,
          requestedByPrincipalId: row['requested_by_principal_id'] as String?,
        ),
      );
    }

    return out;
  }

  @override
  Future<List<DepositBatchRow>> fetchPendingDepositBatches(
    String schoolId,
  ) async {
    try {
      final rows = await _rpc.list(
        'teller_pending_deposit_batches',
        params: {'p_school_id': schoolId},
      );

      final out = <DepositBatchRow>[];
      for (final row in rows) {
        out.add(
          DepositBatchRow(
            batchId: (row['batch_id'] as String?) ?? '',
            weekStart: DateTime.parse(row['week_start'] as String),
            weekEnd: DateTime.parse(row['week_end'] as String),
            expectedAmount: (row['deposit_due'] as num?)?.toDouble() ?? 0.0,
            depositedAmount:
                (row['deposited_amount'] as num?)?.toDouble() ?? 0.0,
            remainingAmount:
                (row['remaining_amount'] as num?)?.toDouble() ?? 0.0,
            note: (row['note'] as String?) ?? '',
          ),
        );
      }
      return out;
    } catch (e) {
      appLogError(e);
      return const <DepositBatchRow>[];
    }
  }

  @override
  Future<DepositBatchRow?> getBatchMatch({
    required String schoolId,
    required String batchId,
    required double amount,
  }) async {
    try {
      final batches = await _rpc.list(
        'teller_pending_deposit_batches',
        params: {'p_school_id': schoolId},
      );

      final matched = batches.firstWhere(
        (r) => (r['batch_id'] as String?) == batchId,
        orElse: () => {},
      );

      if (matched.isEmpty) return null;

      final remaining =
          (matched['remaining_amount'] as num?)?.toDouble() ?? 0.0;
      if (amount > remaining) return null;

      return DepositBatchRow(
        batchId: (matched['batch_id'] as String?) ?? '',
        weekStart: DateTime.parse(matched['week_start'] as String),
        weekEnd: DateTime.parse(matched['week_end'] as String),
        expectedAmount: (matched['deposit_due'] as num?)?.toDouble() ?? 0.0,
        depositedAmount:
            (matched['deposited_amount'] as num?)?.toDouble() ?? 0.0,
        remainingAmount: remaining,
        note: (matched['note'] as String?) ?? '',
      );
    } catch (e) {
      appLogError(e);
      return null;
    }
  }

  @override
  Future<void> confirmDeposit({
    required String schoolId,
    required String teacherId,
    required double amount,
    required double discrepancy,
    String? notes,
    List<String>? batchIds,
  }) async {
    final targets = batchIds ?? [];

    if (targets.isNotEmpty) {
      // Delegate allocation to a single server-side function so all
      // per-batch inserts execute within one PostgreSQL transaction.
      // A failure on any batch automatically rolls back the entire deposit.
      await _sb.rpc(
        'teller_confirm_multi_batch_deposit',
        params: {
          'p_school_id': schoolId,
          'p_batch_ids': targets,
          'p_amount': amount,
          'p_teacher_id': teacherId,
          'p_note': notes,
        },
      );
      return;
    }

    final (weekStartDt, _) = _common.getCurrentIsoWeek();
    final priorWeekStart = weekStartDt.subtract(const Duration(days: 7));
    final weekStartStr = priorWeekStart.toIso8601String().split('T').first;

    final batchResult = await _sb.rpc(
      'submit_dep_batch',
      params: {
        'p_school_id': schoolId,
        'p_week_start': weekStartStr,
        'p_note': null,
      },
    );

    String batchId;
    if (batchResult is String && batchResult.isNotEmpty) {
      batchId = batchResult;
    } else if (batchResult is Map && batchResult['batch_id'] is String) {
      batchId = batchResult['batch_id'] as String;
    } else {
      throw Exception('Failed to create or obtain deposit batch');
    }

    await _sb.rpc(
      'teller_post_school_deposit_event',
      params: {
        'p_batch_id': batchId,
        'p_amount': amount,
        'p_deposited_by_teacher_id': teacherId,
        'p_note': notes,
      },
    );
  }

  @override
  Future<String> postSchoolPayout({
    required String schoolId,
    required String requestId,
    required double amount,
    String? note,
    String? requestedByTeacherId,
    String? requestedByPrincipalId,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be > 0');
    }

    final result = await _sb.rpc(
      'teller_post_school_payout',
      params: {
        'p_school_id': schoolId,
        'p_request_id': requestId,
        'p_amount': amount,
        'p_note': note,
        'p_requested_by_teacher_id': requestedByTeacherId,
        'p_requested_by_principal_id': requestedByPrincipalId,
      },
    );

    if (result is String && result.isNotEmpty) {
      return result;
    }
    if (result is Map && result['bank_payout_id'] is String) {
      return result['bank_payout_id'] as String;
    }

    throw Exception('Failed to post school payout');
  }
}
