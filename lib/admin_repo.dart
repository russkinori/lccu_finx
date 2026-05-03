import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_client.dart';
import 'app_logger.dart';
import 'roles.dart';
import 'friendly_error.dart';

// ==================== VIEW MODELS / MODELS ====================

class IdName {
  final String id;
  final String name;
  final Map<String, dynamic>? meta;

  const IdName({required this.id, required this.name, this.meta});
}

class AdminHomeVm {
  final String activeUsers, schoolCount, creditUnionCount, studentAccountCount;
  final void Function()? onCreateUser;
  final void Function()? onOpenReports;
  final void Function()? onManageRoles;

  const AdminHomeVm({
    required this.activeUsers,
    required this.schoolCount,
    required this.creditUnionCount,
    required this.studentAccountCount,
    this.onCreateUser,
    this.onOpenReports,
    this.onManageRoles,
  });
}

class AdminUser {
  final String userId; // public.user.user_id (== auth uid)
  final String? authUserId; // same as userId in this schema
  final String firstName;
  final String lastName;
  final String? gender;
  final String? title;
  final String email;
  final String? mobile; // guardians: from v_guardian_profile
  final DateTime? createdAt;
  final DateTime? lastSignInAt; // not in schema
  final bool isActive;
  final List<AppRole> roles;
  final String? schoolId;
  final String? schoolName;
  final String? classId;
  final String? className;
  final String? guardianTypeId; // guardians: derived from v_guardian_links
  final String? creditUnionId; // teller.branch_id
  final String? address; // guardians: from v_guardian_profile
  final DateTime? dateOfBirth;
  final String? guardianUserId; // students: the selected guardian user link

  // --- guardrail metadata for UI ---
  final int? guardianLinkCount; // for guardians: number of links they have
  final String? guardianTypeSource; // 'primary' or 'first'
  final int?
  studentGuardianLinkCount; // for students: how many guardians linked
  final bool? studentHasPrimaryGuardian; // for students: is there a primary?
  final String? studentGuardianSelectionNote;

  const AdminUser({
    required this.userId,
    this.authUserId,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.title,
    required this.email,
    this.mobile,
    this.createdAt,
    this.lastSignInAt,
    required this.isActive,
    required this.roles,
    this.schoolId,
    this.schoolName,
    this.classId,
    this.className,
    this.guardianTypeId,
    this.creditUnionId,
    this.address,
    this.dateOfBirth,
    this.guardianUserId,
    this.guardianLinkCount,
    this.guardianTypeSource,
    this.studentGuardianLinkCount,
    this.studentHasPrimaryGuardian,
    this.studentGuardianSelectionNote,
  });

  String get fullName => '$firstName $lastName';
  String get roleNames => roles.map((r) => r.name).join(', ');
}

class UserSearchFilter {
  final String? searchQuery;
  final AppRole? role;
  final String? schoolId;
  final bool? isActive;
  final int limit;
  final int offset;

  const UserSearchFilter({
    this.searchQuery,
    this.role,
    this.schoolId,
    this.isActive,
    this.limit = 50,
    this.offset = 0,
  });
}

class UserSearchResult {
  final List<AdminUser> users;
  final int totalCount;
  final bool hasMore;

  const UserSearchResult({
    required this.users,
    required this.totalCount,
    required this.hasMore,
  });
}

class CreateUserRequest {
  final String email;
  final String? password;
  final String firstName;
  final String lastName;
  final String? gender;
  final String? title;
  final AppRole role;
  final String? schoolId;
  final String? classId;
  final String? mobile;
  final String? dateOfBirth;
  final String? guardianTypeId;
  final String? creditUnionId;
  final String? address;
  final String? guardianUserId;
  final String? accNumber;
  final double? openingBal;

  const CreateUserRequest({
    required this.email,
    this.password,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.title,
    required this.role,
    this.schoolId,
    this.classId,
    this.mobile,
    this.dateOfBirth,
    this.guardianTypeId,
    this.creditUnionId,
    this.address,
    this.guardianUserId,
    this.accNumber,
    this.openingBal,
  });
}

class UpdateUserRequest {
  final String authUserId; // == public.user.user_id
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? title;
  final AppRole? role;
  final String? schoolId;
  final String? classId;
  final String? mobile;
  final String? dateOfBirth;
  final String? guardianTypeId;
  final String? creditUnionId;
  final String? address;
  final String? guardianUserId;

  const UpdateUserRequest({
    required this.authUserId,
    this.email,
    this.firstName,
    this.lastName,
    this.gender,
    this.title,
    this.role,
    this.schoolId,
    this.classId,
    this.mobile,
    this.dateOfBirth,
    this.guardianTypeId,
    this.creditUnionId,
    this.address,
    this.guardianUserId,
  });
}

class AdminUserCreateResult {
  final AdminUser user;
  final bool inviteSent;

  const AdminUserCreateResult({required this.user, required this.inviteSent});
}

// ==================== REPOSITORY API ====================

abstract class AdminRepo {
  Future<AdminHomeVm> getAdminHome();
  Future<int> getUserCount();
  Future<int> getSchoolCount();
  Future<int> getCreditUnionCount();
  Future<int> getStudentAccountCount();
  Future<double> getTotalStudentAccountValue();
  Future<double> getTotalSchoolAccountValue();

  // User Management
  Future<UserSearchResult> searchUsers(UserSearchFilter filter);
  Future<AdminUser?> getUserById(String userId);
  Future<AdminUser?> getUserByAuthId(String authUserId);
  Future<AdminUserCreateResult> createUser(CreateUserRequest request);
  Future<void> updateUser(UpdateUserRequest request);
  Future<void> deleteUser(String authUserId);
  Future<void> deactivateUser(String authUserId);
  Future<void> reactivateUser(String authUserId);
  Future<String> resetUserPassword(String authUserId);

  // Roles
  Future<void> assignRole(String authUserId, AppRole role);
  Future<void> removeRole(String authUserId, AppRole role);
  Future<List<AppRole>> getUserRoles(String authUserId);

  // Lookups
  Future<List<IdName>> getSchoolsForDropdown();
  Future<List<IdName>> getClassesForSchool(String schoolId);
  Future<List<IdName>> getGuardianTypes();
  Future<List<IdName>> getCreditUnions();

  // Debug
  Future<Map<String, dynamic>> debugTableInfo();

  // Reports
  Future<List<Map<String, dynamic>>> fetchTransactionReport({
    DateTime? from,
    DateTime? to,
    String? schoolId,
    String? classId,
    String? teacherNameLike,
    String? studentNameLike,
    String type = 'all', // 'deposit' | 'withdrawal' | 'count' | 'all'
    int limit = 5000,
  });

  // School deposits report (from cu_dep_event table - school to credit union)
  Future<List<Map<String, dynamic>>> fetchSchoolDepositsReport({
    DateTime? from,
    DateTime? to,
    String? schoolId,
    String type = 'all', // 'deposit' | 'count' | 'all'
    int limit = 5000,
  });
}

// ==================== IMPLEMENTATION ====================

class SupabaseAdminRepo implements AdminRepo {
  SupabaseAdminRepo(this._client);

  final SupabaseClient _client;
  // Use the Supabase edge function that handles privileged admin actions.
  // This function handles create_user, update_user, and delete_user operations.
  static const _edgeFunction = 'user-admin';

  String _snakeToCamel(String value) {
    final parts = value.split('_');
    if (parts.isEmpty) return value;
    final buffer = StringBuffer(parts.first);
    for (final part in parts.skip(1)) {
      if (part.isEmpty) continue;
      buffer.write(part[0].toUpperCase());
      if (part.length > 1) {
        buffer.write(part.substring(1));
      }
    }
    return buffer.toString();
  }

  void _maybeAdd(Map<String, dynamic> target, String key, dynamic value) {
    if (value == null) return;
    target[key] = value;
  }

  void _maybeAddDual(
    Map<String, dynamic> target,
    String snakeKey,
    dynamic value,
  ) {
    if (value == null) return;
    target[snakeKey] = value;
    target[_snakeToCamel(snakeKey)] = value;
  }

  Future<Map<String, dynamic>> _invokeAdminEdge(
    String action,
    Map<String, dynamic> payload,
  ) async {
    return await invokeAdminEdge(_client, _edgeFunction, action, payload);
  }

  // ---------- helpers: roles ----------

  List<AppRole> _parseRoleNames(dynamic raw) {
    return ((raw as List?) ?? const [])
        .map((name) => AppRoleX.tryParse(name.toString()))
        .whereType<AppRole>()
        .toList();
  }

  Future<List<AppRole>> _rolesOfUser(String userId) async {
    // Login/bootstrap should never depend on admin-only migration functions.
    // When resolving the currently authenticated user's own role, use the
    // existing self-scoped database function that is already present in the
    // current Supabase export.
    if (_client.auth.currentUser?.id == userId) {
      final raw = await _client.rpc('current_user_role_names');
      return _parseRoleNames(raw);
    }

    final raw = await _client.rpc(
      'admin_user_role_names',
      params: {'p_user_id': userId},
    );
    return _parseRoleNames(raw);
  }

  // ---------- dashboard counts ----------

  @override
  Future<int> getStudentAccountCount() async {
    final m = await _getAdminDashboardCounts();
    final val =
        m['student_account_count'] ?? m['student_acc_count'] ?? m['studentAccountCount'];
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  @override
  Future<double> getTotalStudentAccountValue() async {
    final m = await _getAdminDashboardCounts();
    final val = m['total_student_account_value'] ?? m['totalStudentAccountValue'];
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Future<double> getTotalSchoolAccountValue() async {
    final m = await _getAdminDashboardCounts();
    final val = m['total_school_account_value'] ?? m['totalSchoolAccountValue'];
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Future<int> getUserCount() async {
    final m = await _getAdminDashboardCounts();
    final val = m['user_count'] ?? m['userCount'];
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  @override
  Future<int> getSchoolCount() async {
    final m = await _getAdminDashboardCounts();
    final val = m['school_count'] ?? m['schoolCount'];
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  @override
  Future<int> getCreditUnionCount() async {
    final m = await _getAdminDashboardCounts();
    final val = m['credit_union_count'] ?? m['cu_branch_count'] ?? m['creditUnionCount'];
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  @override
  Future<AdminHomeVm> getAdminHome() async {
    final m = await _getAdminDashboardCounts();
    final users = (m['user_count'] ?? m['userCount'])?.toString() ?? '0';
    final schools = (m['school_count'] ?? m['schoolCount'])?.toString() ?? '0';
    final cus = (m['credit_union_count'] ?? m['cu_branch_count'] ?? m['creditUnionCount'])?.toString() ?? '0';
    final studentAccounts = (m['student_account_count'] ?? m['student_acc_count'] ?? m['studentAccountCount'])?.toString() ?? '0';

    return AdminHomeVm(
      activeUsers: users,
      schoolCount: schools,
      creditUnionCount: cus,
      studentAccountCount: studentAccounts,
      onCreateUser: () {},
      onOpenReports: () {},
      onManageRoles: () {},
    );
  }

  // ---------- user search / get ----------

  @override
  Future<UserSearchResult> searchUsers(UserSearchFilter filter) async {
    try {
      final raw = await _client.rpc(
        'admin_user_profiles',
        params: {
          'p_user_id': null,
          'p_search': filter.searchQuery,
          'p_role': filter.role?.name,
          'p_school_id': filter.schoolId,
          'p_is_active': filter.isActive,
          'p_limit': filter.limit,
          'p_offset': filter.offset,
        },
      );

      final users = ((raw as List?) ?? const [])
          .map((e) => _mapAdminProfileRow((e as Map).cast<String, dynamic>()))
          .toList();

      return UserSearchResult(
        users: users,
        totalCount: users.length,
        hasMore: users.length == filter.limit,
      );
    } catch (e) {
      throw StateError(friendlyActionError('Failed to search users.', e));
    }
  }

  @override
  Future<AdminUser?> getUserById(String userId) async {
    try {
      final raw = await _client.rpc(
        'admin_user_profiles',
        params: {
          'p_user_id': userId,
          'p_search': null,
          'p_role': null,
          'p_school_id': null,
          'p_is_active': null,
          'p_limit': 1,
          'p_offset': 0,
        },
      );
      final list = (raw as List?) ?? const [];
      if (list.isEmpty) return null;
      return _mapAdminProfileRow((list.first as Map).cast<String, dynamic>());
    } catch (e) {
      throw StateError(friendlyActionError('Failed to load user details.', e));
    }
  }

  @override
  Future<AdminUser?> getUserByAuthId(String authUserId) async {
    // In this schema, auth UID == public.user.user_id
    return getUserById(authUserId);
  }

  // ---------- create / update / delete ----------

  @override
  Future<AdminUserCreateResult> createUser(CreateUserRequest request) async {
    final payload = <String, dynamic>{
      'email': request.email,
      'role': request.role.name,
    };

    _maybeAdd(payload, 'password', request.password);
    _maybeAddDual(payload, 'first_name', request.firstName);
    _maybeAddDual(payload, 'last_name', request.lastName);
    _maybeAddDual(payload, 'gender', request.gender);
    _maybeAddDual(payload, 'title', request.title);
    _maybeAddDual(payload, 'school_id', request.schoolId);
    _maybeAddDual(payload, 'class_id', request.classId);
    _maybeAddDual(payload, 'mobile', request.mobile);
    _maybeAddDual(payload, 'date_of_birth', request.dateOfBirth);
    _maybeAddDual(payload, 'guardian_type_id', request.guardianTypeId);
    _maybeAddDual(payload, 'credit_union_id', request.creditUnionId);
    _maybeAddDual(payload, 'address', request.address);
    // Send as guardian_id for edge function compatibility
    if (request.guardianUserId != null) {
      payload['guardian_id'] = request.guardianUserId;
      payload['guardianId'] = request.guardianUserId;
      payload['guardian_user_id'] = request.guardianUserId;
      payload['guardianUserId'] = request.guardianUserId;
    }
    _maybeAddDual(payload, 'acc_number', request.accNumber);
    if (request.openingBal != null) {
      payload['opening_bal'] = request.openingBal;
      payload['openingBal'] = request.openingBal;
    }

    appLog('createUser payload prepared');

    try {
      final result = await _invokeAdminEdge('create_user', payload);
      appLog('createUser result received');

      AdminUser? user;
      String? userId;

      // Try to extract user ID from various possible response keys
      userId = result['authUserId'] as String?;
      userId ??= result['auth_user_id'] as String?;
      userId ??= result['user_id'] as String?;
      userId ??= result['userId'] as String?;

      // Try to get user data from response
      final userRaw = result['user'];
      if (userRaw is Map) {
        final userMap = userRaw.cast<String, dynamic>();
        if (userMap.containsKey('user_id')) {
          try {
            user = await _mapRowToAdminUserWithDetails(userMap);
          } catch (e) {
            appLogError(e);
          }
        }
      }

      // If no user data in response, fetch it using the user ID
      if (user == null && userId != null) {
        try {
          user = await getUserById(userId);
        } catch (e) {
          appLogError(e);
        }
      }

      if (user == null) {
        throw StateError(
          'Create user succeeded but no user data was returned.',
        );
      }

      final inviteSent =
          result['invite_sent'] as bool? ??
          result['inviteSent'] as bool? ??
          false;

      return AdminUserCreateResult(user: user, inviteSent: inviteSent);
    } catch (e) {
      appLogError(e);
      rethrow;
    }
  }

  @override
  Future<void> updateUser(UpdateUserRequest request) async {
    final payload = <String, dynamic>{
      'auth_user_id': request.authUserId,
      'authUserId': request.authUserId,
      'user_id': request.authUserId,
      'userId': request.authUserId,
    };

    _maybeAdd(payload, 'email', request.email);
    _maybeAddDual(payload, 'first_name', request.firstName);
    _maybeAddDual(payload, 'last_name', request.lastName);
    _maybeAddDual(payload, 'gender', request.gender);
    _maybeAddDual(payload, 'title', request.title);
    if (request.role != null) {
      payload['role'] = request.role!.name;
    }
    _maybeAddDual(payload, 'school_id', request.schoolId);
    _maybeAddDual(payload, 'class_id', request.classId);
    _maybeAddDual(payload, 'mobile', request.mobile);
    _maybeAddDual(payload, 'date_of_birth', request.dateOfBirth);
    _maybeAddDual(payload, 'guardian_type_id', request.guardianTypeId);
    _maybeAddDual(payload, 'credit_union_id', request.creditUnionId);
    _maybeAddDual(payload, 'address', request.address);

    // Send guardian link request to the admin Edge Function. The backend
    // validates that the target user is a guardian before persisting it.
    if (request.guardianUserId != null) {
      final guardianUserId = request.guardianUserId!;
      payload['guardian_id'] = guardianUserId;
      payload['guardianId'] = guardianUserId;
      payload['guardian_user_id'] = guardianUserId;
      payload['guardianUserId'] = guardianUserId;
    }

    appLog('updateUser started');
    appLog('updateUser payload prepared');
    try {
      await _invokeAdminEdge('update_user', payload);
      appLog('updateUser succeeded');
    } catch (e) {
      appLog('updateUser failed');
      appLogError(e);
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(String authUserId) async {
    final payload = <String, dynamic>{
      'auth_user_id': authUserId,
      'authUserId': authUserId,
      'user_id': authUserId,
      'userId': authUserId,
    };

    await _invokeAdminEdge('delete_user', payload);
  }

  @override
  Future<String> resetUserPassword(String authUserId) async {
    try {
      final response = await _client.functions.invoke(
        'reset-passwords',
        body: {
          'userIds': [authUserId],
        },
      );

      appLog('Reset password response status ${response.status}');
      appLog('Reset password response data received');

      if (response.status != 200) {
        throw StateError('Failed to reset password: HTTP ${response.status}');
      }

      dynamic raw = response.data;
      if (raw is String) {
        raw = json.decode(raw);
      }

      if (raw is! Map) {
        throw StateError('Unexpected response format');
      }

      final results = raw['results'] as List?;
      if (results == null || results.isEmpty) {
        throw StateError('No results returned from password reset');
      }

      final result = results.first as Map<String, dynamic>;
      if (result['ok'] != true) {
        final error = result['error'] ?? 'Unknown error';
        throw StateError(friendlyActionError('Password reset failed.', error));
      }

      final newPassword = result['newPassword'] as String?;
      if (newPassword == null) {
        throw StateError('No password returned from reset');
      }

      return newPassword;
    } catch (e) {
      appLogError(e);
      rethrow;
    }
  }

  @override
  Future<void> deactivateUser(String authUserId) async {
    await deleteUser(authUserId);
  }

  @override
  Future<void> reactivateUser(String authUserId) async {
    final payload = <String, dynamic>{
      'auth_user_id': authUserId,
      'authUserId': authUserId,
      'user_id': authUserId,
      'userId': authUserId,
    };
    await _invokeAdminEdge('reactivate_user', payload);
  }

  // ---------- roles ----------

  @override
  Future<void> assignRole(String authUserId, AppRole role) async {
    await _client.rpc(
      'admin_assign_role',
      params: {'p_user_id': authUserId, 'p_role_name': role.name},
    );
  }

  @override
  Future<void> removeRole(String authUserId, AppRole role) async {
    await _client.rpc(
      'admin_remove_role',
      params: {'p_user_id': authUserId, 'p_role_name': role.name},
    );
  }

  @override
  Future<List<AppRole>> getUserRoles(String authUserId) async {
    return _rolesOfUser(authUserId);
  }

  // ---------- lookups ----------

  @override
  Future<List<IdName>> getSchoolsForDropdown() async {
    final data = await _client.rpc('admin_schools_lookup');
    return ((data as List?) ?? const [])
        .map(
          (r) => IdName(
            id: r['school_id'] as String,
            name: (r['name'] ?? '-') as String,
            meta: {'level': r['level']},
          ),
        )
        .toList();
  }

  @override
  Future<List<IdName>> getClassesForSchool(String schoolId) async {
    final data = await _client.rpc(
      'admin_classes_for_school',
      params: {'p_school_id': schoolId},
    );
    return ((data as List?) ?? const [])
        .map(
          (r) => IdName(
            id: r['class_id'] as String,
            name: (r['name'] ?? 'Class') as String,
            meta: {'level_id': r['level_id']},
          ),
        )
        .toList();
  }

  @override
  Future<List<IdName>> getGuardianTypes() async {
    final data = await _client.rpc('admin_guardian_types_lookup');
    return ((data as List?) ?? const [])
        .map(
          (r) => IdName(
            id: r['type_id'] as String,
            name: (r['name'] ?? '-') as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<IdName>> getCreditUnions() async {
    final data = await _client.rpc('admin_credit_unions_lookup');
    return ((data as List?) ?? const [])
        .map(
          (r) => IdName(
            id: r['branch_id'] as String,
            name: (r['branch'] ?? '-') as String,
          ),
        )
        .toList();
  }

  // ---------- debug ----------

  @override
  Future<Map<String, dynamic>> debugTableInfo() async {
    final results = <String, dynamic>{};
    final rpcChecks = [
      'admin_dashboard_metrics',
      'admin_user_profiles',
      'admin_schools_lookup',
      'admin_classes_for_school',
      'admin_guardian_types_lookup',
      'admin_credit_unions_lookup',
      'admin_transaction_report',
      'admin_school_deposits_report',
    ];
    for (final fn in rpcChecks) {
      try {
        final result = fn == 'admin_classes_for_school'
            ? await _client.rpc(fn, params: {'p_school_id': null})
            : await _client.rpc(fn);
        results['rpc $fn (ok)'] = result.runtimeType.toString();
      } catch (e) {
        results['rpc $fn (err)'] = e.toString();
      }
    }

    return results;
  }

  // ---------- map user profile row ----------

  AdminUser _mapAdminProfileRow(Map<String, dynamic> row) {
    final userId = row['user_id'].toString();
    final roleNames = ((row['role_names'] as List?) ?? const [])
        .map((r) => AppRoleX.tryParse(r.toString()))
        .whereType<AppRole>()
        .toList();

    DateTime? parseDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return AdminUser(
      userId: userId,
      authUserId: userId,
      firstName: (row['first_name'] ?? '').toString(),
      lastName: (row['last_name'] ?? '').toString(),
      gender: row['gender'] as String?,
      title: row['title'] as String?,
      email: (row['email'] ?? '').toString(),
      mobile: row['mobile'] as String?,
      createdAt: parseDateTime(row['created_at']),
      lastSignInAt: null,
      isActive: (row['is_active'] as bool?) ?? true,
      roles: roleNames,
      schoolId: row['school_id'] as String?,
      schoolName: row['school_name'] as String?,
      classId: row['class_id'] as String?,
      className: row['class_name'] as String?,
      guardianTypeId: row['guardian_type_id'] as String?,
      creditUnionId: row['credit_union_id'] as String?,
      address: row['address'] as String?,
      dateOfBirth: parseDate(row['date_of_birth']),
      guardianUserId: row['guardian_user_id'] as String?,
      guardianLinkCount: (row['guardian_link_count'] as num?)?.toInt(),
      guardianTypeSource: row['guardian_type_source'] as String?,
      studentGuardianLinkCount:
          (row['student_guardian_link_count'] as num?)?.toInt(),
      studentHasPrimaryGuardian:
          row['student_has_primary_guardian'] as bool?,
      studentGuardianSelectionNote:
          row['student_guardian_selection_note'] as String?,
    );
  }

  Future<AdminUser> _mapRowToAdminUserWithDetails(
    Map<String, dynamic> row,
  ) async {
    if (row.containsKey('role_names')) {
      return _mapAdminProfileRow(row);
    }
    final userId = row['user_id'] as String;
    final user = await getUserById(userId);
    if (user == null) {
      throw StateError('User not found: $userId');
    }
    return user;
  }

  // Fetch consolidated dashboard counts and totals from RPC
  Future<Map<String, dynamic>> _getAdminDashboardCounts() async {
    try {
      final raw = await _client.rpc('admin_dashboard_metrics');
      dynamic row;
      if (raw is List && raw.isNotEmpty) {
        row = raw.first;
      } else if (raw is Map) {
        row = raw;
      } else {
        return <String, dynamic>{};
      }

      return (row as Map).cast<String, dynamic>();
    } catch (e) {
      appLogError(e);
      return <String, dynamic>{};
    }
  }

  // ---------- reports: transaction history ----------

  @override
  Future<List<Map<String, dynamic>>> fetchTransactionReport({
    DateTime? from,
    DateTime? to,
    String? schoolId,
    String? classId,
    String? teacherNameLike,
    String? studentNameLike,
    String type = 'all',
    int limit = 5000,
  }) async {
    final raw = await _client.rpc(
      'admin_transaction_report',
      params: {
        'p_from': from?.toUtc().toIso8601String(),
        'p_to': to?.toUtc().toIso8601String(),
        'p_school_id': schoolId != null && schoolId.isNotEmpty ? schoolId : null,
        'p_class_id': classId != null && classId.isNotEmpty ? classId : null,
        'p_teacher_name_like': teacherNameLike,
        'p_student_name_like': studentNameLike,
        'p_type': type,
        'p_limit': limit,
      },
    );
    return ((raw as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSchoolDepositsReport({
    DateTime? from,
    DateTime? to,
    String? schoolId,
    String type = 'all',
    int limit = 5000,
  }) async {
    final raw = await _client.rpc(
      'admin_school_deposits_report',
      params: {
        'p_from': from?.toUtc().toIso8601String(),
        'p_to': to?.toUtc().toIso8601String(),
        'p_school_id': schoolId != null && schoolId.isNotEmpty ? schoolId : null,
        'p_type': type,
        'p_limit': limit,
      },
    );

    return ((raw as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

}
