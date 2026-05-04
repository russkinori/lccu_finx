// lib/data/repositories/principal_repo.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/core/clients/rpc_client.dart';
import 'package:lccu_finx/core/utils/app_logger.dart';

final _sb = Supabase.instance.client;
final RpcClient _rpc = RpcClient(_sb);

class PIdName {
  final String id;
  final String name;
  final Map<String, dynamic>? meta;

  const PIdName({
    required this.id,
    required this.name,
    this.meta,
  });
}

class PrincipalSummaryRow {
  final DateTime date;
  final String teacherId;
  final String classId;
  final String className;
  final String studentId;
  final String studentName;
  final String type;
  final double amount;

  const PrincipalSummaryRow({
    required this.date,
    required this.teacherId,
    required this.classId,
    required this.className,
    required this.studentId,
    required this.studentName,
    required this.type,
    required this.amount,
  });
}

class PrincipalHomeVM {
  final String principalName;
  final List<PIdName> teachers;
  final List<PIdName> classes;
  final List<PIdName> students;
  final double contributionForPeriod;
  final double fundsOnSite;
  final List<PrincipalSummaryRow> rows;

  const PrincipalHomeVM({
    required this.principalName,
    required this.teachers,
    required this.classes,
    required this.students,
    required this.contributionForPeriod,
    required this.fundsOnSite,
    required this.rows,
  });
}

class TeacherCollectionItem {
  final String teacherId;
  final String teacherName;
  final DateTime weekStart;
  final DateTime weekEnd;
  final double collectedAmount;
  final double addedAmount;
  final double depositedAmount;
  final double batchedPendingAmount;
  final double remainingAmount;
  final String status;

  const TeacherCollectionItem({
    required this.teacherId,
    required this.teacherName,
    required this.weekStart,
    required this.weekEnd,
    required this.collectedAmount,
    required this.addedAmount,
    required this.depositedAmount,
    required this.batchedPendingAmount,
    required this.remainingAmount,
    required this.status,
  });
}

class DepositRecord {
  final DateTime date;
  final double amount;
  final double discrepancy;
  final String notes;

  const DepositRecord({
    required this.date,
    required this.amount,
    required this.discrepancy,
    required this.notes,
  });
}

class TeacherDepositRecord {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double amount;
  final String teacherName;

  const TeacherDepositRecord({
    required this.weekStart,
    required this.weekEnd,
    required this.amount,
    required this.teacherName,
  });
}

double _asDouble(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

abstract class PrincipalRepository {
  Future<PrincipalHomeVM> getPrincipalHome({
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? classId,
    String? studentId,
  });

  Future<List<TeacherCollectionItem>> getTeacherCollectionsForReconciliation({
    required String schoolId,
    DateTime? weekStart,
  });

  Future<String> submitDepositBatch({
    required String schoolId,
    required DateTime weekStart,
    String? note,
  });

  Future<(double fundsOnSite, double depositedFunds)> getSchoolWeeklySummary(
    String schoolId,
  );

  Future<(double depositDue, double deposited, double difference)>
  getSchoolDepositDetails(String schoolId);

  Future<(double depositDue, double deposited, double difference)>
  getAllTeachersDepositDetails(String schoolId);

  Future<(double depositDue, double deposited, double difference)>
  getTeacherDepositDetails(String schoolId, String teacherId);

  Future<double> getSchoolAccountBalance(String schoolId);

  Future<double> getFilteredAccountBalance({
    required String schoolId,
    String? teacherId,
    String? classId,
    String? studentId,
  });

  Future<double> getFilteredAccountBalanceForPeriod({
    required String schoolId,
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? classId,
    String? studentId,
  });

  Future<List<DepositRecord>> getSchoolDepositHistory(String schoolId);

  Future<List<TeacherDepositRecord>> getTeacherDepositHistory(
    String schoolId, {
    String? teacherId,
  });
}

class SupabasePrincipalRepository implements PrincipalRepository {
  final SupabaseClient _sb;
  final CommonRepository _common;

  SupabasePrincipalRepository(this._sb, this._common);

  Future<(String principalId, String principalName, String schoolId)>
  getPrincipalIdentity() async {
    final userRow = await _common.getCurrentUserRow();
    final principalId = await _sb.rpc('current_principal_id') as String?;
    final schoolId = await _sb.rpc('current_principal_school_id') as String?;

    if (principalId == null || schoolId == null) {
      throw Exception('Principal not found for current user');
    }

    final name = _common.formatUserName(
      firstName: userRow['first_name'] as String?,
      lastName: userRow['last_name'] as String?,
      fallback: 'Principal',
    );

    return (principalId, name, schoolId);
  }

  Future<List<PIdName>> _teachersForSchool() async {
    final rpcRows = await _sb.rpc('principal_teachers_list');
    final list = <PIdName>[];

    for (final raw in (rpcRows as List? ?? const [])) {
      final r = (raw as Map).cast<String, dynamic>();
      final id = r['teacher_id'] as String?;
      if (id == null) {
        continue;
      }
      final name = (r['teacher_name'] as String?)?.trim();
      list.add(
        PIdName(
          id: id,
          name: (name == null || name.isEmpty) ? 'Teacher' : name,
        ),
      );
    }

    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<PIdName>> _studentsForScope({
    String? teacherId,
    String? classId,
  }) async {
    final rpcRows = await _sb.rpc(
      'principal_students_list',
      params: {
        'p_teacher_id': teacherId,
        'p_class_id': classId,
      },
    );

    final out = <PIdName>[];
    for (final raw in (rpcRows as List? ?? const [])) {
      final r = (raw as Map).cast<String, dynamic>();
      final studentId = r['student_id'] as String?;
      if (studentId == null) {
        continue;
      }

      final studentName = (r['student_name'] as String?)?.trim();
      final classIdValue = r['class_id'] as String?;
      final className = (r['class_name'] as String?)?.trim();

      out.add(
        PIdName(
          id: studentId,
          name: (studentName == null || studentName.isEmpty) ? 'Student' : studentName,
          meta: {
            'class_id': classIdValue,
            'class_name': className ?? '—',
          },
        ),
      );
    }

    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  List<PIdName> _classesFromStudents(List<PIdName> students) {
    final seen = <String>{};
    final classes = <PIdName>[];

    for (final s in students) {
      final meta = s.meta ?? const <String, dynamic>{};
      final classId = meta['class_id'] as String?;
      final className = (meta['class_name'] as String?)?.trim() ?? '—';
      if (classId == null || classId.isEmpty) {
        continue;
      }
      if (seen.add(classId)) {
        classes.add(PIdName(id: classId, name: className));
      }
    }

    classes.sort((a, b) => a.name.compareTo(b.name));
    return classes;
  }

  @override
  Future<PrincipalHomeVM> getPrincipalHome({
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? classId,
    String? studentId,
  }) async {
    final (_, principalName, schoolId) = await getPrincipalIdentity();

    final teachers = await _teachersForSchool();

    // Important:
    // - student options are teacher/class scoped
    // - studentId should NOT shrink the student option list to only itself
    final students = await _studentsForScope(
      teacherId: teacherId,
      classId: classId,
    );
    final classes = _classesFromStudents(students);

    final rows = await _rpc.list(
      'principal_transaction_history',
      params: {
        'p_teacher_id': nullableId(teacherId),
        'p_class_id': nullableId(classId),
        'p_student_id': nullableId(studentId),
        'p_limit': 200,
      },
    );

    final txRows = (rows as List? ?? const [])
        .map((raw) => (raw as Map).cast<String, dynamic>())
        .map(
          (r) => PrincipalSummaryRow(
            date: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
            teacherId: (r['teacher_id'] as String?) ?? '',
            classId: (r['class_id'] as String?) ?? '',
            className: (r['class_name'] as String?)?.trim().isNotEmpty == true
                ? (r['class_name'] as String)
                : '—',
            studentId: (r['student_id'] as String?) ?? '',
            studentName: ((r['student_name'] as String?) ?? '').trim().isNotEmpty
                ? (r['student_name'] as String).trim()
                : '—',
            type: (r['tx_type'] as String?) ?? 'Unknown',
            amount: _asDouble(r['amount']),
          ),
        )
        .toList(growable: false);

    double contribution = 0.0;
    for (final row in txRows) {
      if (row.type.toUpperCase() == 'DEPOSIT') {
        contribution += row.amount;
      }
    }

    final (fundsOnSite, _) = await getSchoolWeeklySummary(schoolId);

    return PrincipalHomeVM(
      principalName: principalName,
      teachers: teachers,
      classes: classes,
      students: students,
      contributionForPeriod: contribution,
      fundsOnSite: fundsOnSite,
      rows: txRows,
    );
  }

  @override
  Future<(double fundsOnSite, double depositedFunds)> getSchoolWeeklySummary(
    String schoolId,
  ) async {
    double fundsOnSite = 0.0;
    double depositedFunds = 0.0;

    try {
      final funds = await _rpc.single('principal_funds_on_site');
      if (funds != null) {
        fundsOnSite = _asDouble(funds['funds_on_site']);
      }
    } catch (e) {
      appLog('Principal getSchoolWeeklySummary fundsOnSite warning: $e');
    }

    try {
      final total = await _rpc.single('principal_school_deposited_total');
      if (total != null) {
        depositedFunds = _asDouble(total['deposited_total'] ?? total['total_deposited']);
      }
    } catch (e) {
      appLog('Principal getSchoolWeeklySummary deposited warning: $e');
    }

    return (fundsOnSite, depositedFunds);
  }

  @override
  Future<(double depositDue, double deposited, double difference)>
  getSchoolDepositDetails(String schoolId) async {
    try {
      final detail = await _rpc.single(
        'principal_school_outstanding_deposit_detail',
      );
      if (detail != null && (detail['school_id'] as String?) == schoolId) {
        final depositDue = _asDouble(detail['deposit_due']);
        final deposited = _asDouble(detail['deposited']);
        final difference = _asDouble(detail['difference']);
        return (depositDue, deposited, difference);
      }
    } catch (e) {
      appLog('Warning: school outstanding deposit detail unavailable: $e');
    }

    return _pendingDepositFallback(schoolId);
  }

  @override
  Future<(double depositDue, double deposited, double difference)>
  getAllTeachersDepositDetails(String schoolId) async {
    return getTeacherDepositDetails(schoolId, 'ALL');
  }

  @override
  Future<(double depositDue, double deposited, double difference)>
  getTeacherDepositDetails(String schoolId, String teacherId) async {
    try {
      final detail = await _rpc.single(
        'principal_teacher_outstanding_deposit_detail',
        params: {'p_teacher_id': nullableId(teacherId)},
      );
      if (detail != null && (detail['school_id'] as String?) == schoolId) {
        final depositDue = _asDouble(detail['deposit_due']);
        final deposited = _asDouble(detail['deposited']);
        final difference = _asDouble(detail['difference']);
        return (depositDue, deposited, difference);
      }
    } catch (e) {
      appLog('Warning: teacher outstanding deposit detail unavailable: $e');
    }

    if (teacherId == 'ALL') {
      return _pendingDepositFallback(schoolId);
    }

    return (0.0, 0.0, 0.0);
  }

  Future<(double depositDue, double deposited, double difference)>
  _pendingDepositFallback(String schoolId) async {
    double depositDue = 0.0;
    try {
      final pending = await _rpc.single('principal_pending_deposit_summary');
      if (pending != null && (pending['school_id'] as String?) == schoolId) {
        depositDue = _asDouble(pending['pending_deposit']);
      }
    } catch (e) {
      appLog('Warning: pending deposit fallback unavailable: $e');
    }

    return (depositDue, 0.0, depositDue);
  }

  @override
  Future<double> getSchoolAccountBalance(String schoolId) async {
    final balance = await _sb.rpc(
      'principal_school_account_balance',
      params: {'p_school_id': schoolId},
    );
    return _asDouble(balance);
  }

  Future<List<String>> _scopedStudentIds({
    required String schoolId,
    String? teacherId,
    String? classId,
    String? studentId,
  }) async {
    if (studentId != null && studentId.isNotEmpty && studentId != 'ALL') {
      return [studentId];
    }

    final students = await _studentsForScope(
      teacherId: teacherId,
      classId: classId,
    );

    return students.map((e) => e.id).where((e) => e.isNotEmpty).toList(growable: false);
  }

  @override
  Future<double> getFilteredAccountBalance({
    required String schoolId,
    String? teacherId,
    String? classId,
    String? studentId,
  }) async {
    final scopedIds = await _scopedStudentIds(
      schoolId: schoolId,
      teacherId: teacherId,
      classId: classId,
      studentId: studentId,
    );

    if (scopedIds.isEmpty) {
      return 0.0;
    }

    double total = 0.0;
    for (final studentId in scopedIds) {
      final balance = await _sb.rpc(
        'principal_student_balance',
        params: {'p_student_id': studentId},
      );
      total += _asDouble(balance);
    }
    return total;
  }

  @override
  Future<double> getFilteredAccountBalanceForPeriod({
    required String schoolId,
    required DateTime from,
    required DateTime to,
    String? teacherId,
    String? classId,
    String? studentId,
  }) async {
    final txRows = await _sb.rpc(
      'principal_transaction_history',
      params: {
        'p_teacher_id': (teacherId == null || teacherId == 'ALL') ? null : teacherId,
        'p_class_id': (classId == null || classId == 'ALL') ? null : classId,
        'p_student_id': (studentId == null || studentId == 'ALL') ? null : studentId,
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
        'p_limit': 1000,
      },
    );
    double total = 0.0;
    for (final r in (txRows as List? ?? const [])) {
      total += _asDouble((r as Map).cast<String, dynamic>()['amount']);
    }
    return total;
  }

  @override
  Future<List<TeacherCollectionItem>> getTeacherCollectionsForReconciliation({
    required String schoolId,
    DateTime? weekStart,
  }) async {
    final (weekStartDt, _) = _common.getCurrentIsoWeek();
    final week = weekStart ?? weekStartDt;
    final weekStartStr = week.toIso8601String().split('T').first;

    final rows = await _sb.rpc(
      'principal_reconcile_week_data',
      params: {'p_week_start': weekStartStr},
    );

    final data = (rows as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    if (data.isEmpty) {
      return const [];
    }

    final teacherIds = data
        .map((r) => r['teacher_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final teacherNames = <String, String>{};
    if (teacherIds.isNotEmpty) {
      final rpcRows = await _sb.rpc('principal_teachers_list');
      for (final raw in (rpcRows as List? ?? const [])) {
        final r = (raw as Map).cast<String, dynamic>();
        final tid = r['teacher_id'] as String?;
        if (tid == null || !teacherIds.contains(tid)) {
          continue;
        }
        final name = (r['teacher_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          teacherNames[tid] = name;
        }
      }
    }

    return data.map((r) {
      final teacherId = (r['teacher_id'] as String?) ?? '';
      return TeacherCollectionItem(
        teacherId: teacherId,
        teacherName: teacherNames[teacherId] ?? teacherId,
        weekStart: DateTime.parse(r['week_start'] as String),
        weekEnd: DateTime.parse(r['week_end'] as String),
        collectedAmount: _asDouble(r['collected_amount']),
        addedAmount: _asDouble(r['batched_amount']),
        depositedAmount: _asDouble(r['deposited_amount']),
        batchedPendingAmount: _asDouble(r['batched_pending_amount']),
        remainingAmount: _asDouble(r['remaining_amount']),
        status: (r['recon_status'] as String?) ?? 'PENDING',
      );
    }).toList(growable: false);
  }

  @override
  Future<String> submitDepositBatch({
    required String schoolId,
    required DateTime weekStart,
    String? note,
  }) async {
    final weekStartStr = weekStart.toIso8601String().split('T').first;

    final result = await _sb.rpc(
      'submit_dep_batch',
      params: {
        'p_school_id': schoolId,
        'p_week_start': weekStartStr,
        'p_note': note,
      },
    );

    if (result is String && result.isNotEmpty) {
      return result;
    }
    if (result is Map && result['batch_id'] is String) {
      return result['batch_id'] as String;
    }
    // List return (SETOF/TABLE): extract batch_id from first row if present
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map && first['batch_id'] is String) {
        return first['batch_id'] as String;
      }
    }
    // null, void, or empty-string return: function succeeded but returned no id
    if (result == null || (result is String && result.isEmpty)) {
      return '';
    }
    throw Exception('Failed to submit deposit batch');
  }

  @override
  Future<List<DepositRecord>> getSchoolDepositHistory(String schoolId) async {
    final rows = await _rpc.list('principal_school_deposit_history', params: {'p_limit': 200});
    final filtered = (rows as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((r) => (r['school_id'] as String?) == schoolId)
        .toList();
    filtered.sort((a, b) => (b['deposit_date'] as String?)
        .toString()
        .compareTo((a['deposit_date'] as String?)?.toString() ?? ''));

    final limited = filtered.take(100).toList(growable: false);

    return limited
        .map(
          (r) => DepositRecord(
            date: DateTime.parse(r['deposit_date'] as String),
            amount: _asDouble(r['deposited_amount'] ?? r['amount']),
            discrepancy: _asDouble(r['discrepancy']),
            notes: '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TeacherDepositRecord>> getTeacherDepositHistory(
    String schoolId, {
    String? teacherId,
  }) async {
    final rows = await _sb.rpc(
      'principal_teacher_deposit_history',
      params: {
        'p_teacher_id': (teacherId == null || teacherId.isEmpty || teacherId == 'ALL') ? null : teacherId,
        'p_limit': 200,
      },
    );

    return (rows as List? ?? const []).map((r) {
      final ws = r['week_start'] != null
          ? DateTime.parse(r['week_start'] as String)
          : DateTime.parse(r['deposit_date'] as String);

      final we = r['week_end'] != null
          ? DateTime.parse(r['week_end'] as String)
          : DateTime.parse(r['deposit_date'] as String);

      return TeacherDepositRecord(
        weekStart: ws,
        weekEnd: we,
        amount: _asDouble(r['amount']),
        teacherName: (r['teacher_name'] as String?) ?? 'Unknown',
      );
    }).toList(growable: false);
  }
}