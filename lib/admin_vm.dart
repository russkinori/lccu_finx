import 'package:flutter/widgets.dart';

import 'admin_repo.dart';
import 'roles.dart';
import 'app_logger.dart';
import 'friendly_error.dart';

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.userCount,
    required this.schoolCount,
    required this.creditUnionCount,
    required this.studentAccountCount,
    required this.totalStudentAccountValue,
    required this.totalSchoolAccountValue,
  });

  final int userCount;
  final int schoolCount;
  final int creditUnionCount;
  final int studentAccountCount;
  final double totalStudentAccountValue;
  final double totalSchoolAccountValue;
}

class AdminVm extends ChangeNotifier {
  AdminVm({required AdminRepo repo}) : _repo = repo;

  final AdminRepo _repo;

  bool _disposed = false;
  bool get isDisposed => _disposed;

  AdminDashboardMetrics? _dashboard;
  AdminDashboardMetrics? get dashboard => _dashboard;

  bool _dashboardLoading = false;
  bool get isDashboardLoading => _dashboardLoading;
  String? _dashboardError;
  String? get dashboardError => _dashboardError;

  bool _lookupsLoading = false;
  bool get isLookupsLoading => _lookupsLoading;

  List<IdName> _schools = const [];
  List<IdName> get schools => _schools;

  final Map<String, List<IdName>> _classesBySchool = {};

  List<IdName> _guardianTypes = const [];
  List<IdName> get guardianTypes => _guardianTypes;

  List<IdName> _creditUnions = const [];
  List<IdName> get creditUnions => _creditUnions;

  List<AdminUser> _searchResults = const [];
  List<AdminUser> get searchResults => _searchResults;
  bool _searchingUsers = false;
  bool get isSearchingUsers => _searchingUsers;
  String? _searchError;
  String? get searchError => _searchError;

  List<AdminUser> _guardianCache = const [];
  List<AdminUser> get guardianCache => _guardianCache;
  AdminUser? _selectedUser;
  AdminUser? get selectedUser => _selectedUser;

  AdminRepo get repo => _repo;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Future<void> refreshDashboard() async {
    if (_disposed || _dashboardLoading) return;
    _dashboardLoading = true;
    _dashboardError = null;
    notifyListeners();
    try {
      // Use the repo's consolidated admin home RPC for counts (string-based),
      // then fetch totals separately as doubles.
      final home = await _repo.getAdminHome();
      if (_disposed) return;
      final users = int.tryParse(home.activeUsers.replaceAll(',', '')) ?? 0;
      final schools = int.tryParse(home.schoolCount.replaceAll(',', '')) ?? 0;
      final cus = int.tryParse(home.creditUnionCount.replaceAll(',', '')) ?? 0;
      final studentAccounts = int.tryParse(home.studentAccountCount.replaceAll(',', '')) ?? 0;

      final totalStudentValue = await _repo.getTotalStudentAccountValue();
      if (_disposed) return;
      final totalSchoolValue = await _repo.getTotalSchoolAccountValue();
      if (_disposed) return;

      _dashboard = AdminDashboardMetrics(
        userCount: users,
        schoolCount: schools,
        creditUnionCount: cus,
        studentAccountCount: studentAccounts,
        totalStudentAccountValue: totalStudentValue,
        totalSchoolAccountValue: totalSchoolValue,
      );
    } catch (e) {
      if (_disposed) return;
      _dashboardError = friendlyActionError('Failed to load dashboard metrics.', e);
    } finally {
      if (!_disposed) {
        _dashboardLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> ensureLookups() async {
    if (_disposed || _lookupsLoading) return;
    if (_schools.isNotEmpty &&
        _guardianTypes.isNotEmpty &&
        _creditUnions.isNotEmpty) {
      return;
    }
    _lookupsLoading = true;
    notifyListeners();
    try {
      _schools = await _repo.getSchoolsForDropdown();
      if (_disposed) return;
      _guardianTypes = await _repo.getGuardianTypes();
      if (_disposed) return;
      _creditUnions = await _repo.getCreditUnions();
      if (_disposed) return;
    } catch (e) {
      if (_disposed) return;
      // Bubble up via notification; widgets can check lists and display errors.
      _dashboardError = friendlyActionError('Failed to load lookup data.', e);
    } finally {
      if (!_disposed) {
        _lookupsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<List<AdminUser>> guardians() async {
    if (_disposed) return const [];
    if (_guardianCache.isNotEmpty) {
      return _guardianCache;
    }
    try {
      final result = await _repo.searchUsers(
        const UserSearchFilter(role: AppRole.guardian, limit: 200),
      );
      if (_disposed) return const [];
      _guardianCache = result.users;
      appLog('AdminVm: Loaded ${_guardianCache.length} guardians');
    } catch (e) {
      if (_disposed) return const [];
      appLog('AdminVm: Error loading guardians: $e');
      _guardianCache = const [];
    }
    notifyListeners();
    return _guardianCache;
  }

  Future<List<IdName>> classesForSchool(String schoolId) async {
    if (_disposed) return const [];
    if (_classesBySchool.containsKey(schoolId)) {
      return _classesBySchool[schoolId]!;
    }
    final classes = await _repo.getClassesForSchool(schoolId);
    if (_disposed) return const [];
    _classesBySchool[schoolId] = classes;
    notifyListeners();
    return classes;
  }

  Future<void> searchUsers({
    String? query,
    AppRole? role,
    bool? isActive,
  }) async {
    if (_disposed) return;
    _searchingUsers = true;
    _searchError = null;
    notifyListeners();
    try {
      final result = await _repo.searchUsers(
        UserSearchFilter(
          searchQuery: query,
          role: role,
          isActive: isActive,
          limit: 50,
        ),
      );
      if (_disposed) return;
      _searchResults = result.users;
    } catch (e) {
      if (_disposed) return;
      _searchError = friendlyActionError('Search failed.', e);
      _searchResults = const [];
    } finally {
      if (!_disposed) {
        _searchingUsers = false;
        notifyListeners();
      }
    }
  }

  Future<void> clearSearch() async {
    if (_disposed) return;
    _searchResults = const [];
    _searchError = null;
    notifyListeners();
  }

  Future<AdminUser?> loadUser(String userId) async {
    if (_disposed) return null;
    try {
      _selectedUser = await _repo.getUserById(userId);
      if (_disposed) return null;
      notifyListeners();
      return _selectedUser;
    } catch (e) {
      if (_disposed) return null;
      _searchError = friendlyActionError('Failed to load user.', e);
      notifyListeners();
      rethrow;
    }
  }

  void clearSelectedUser() {
    if (_disposed) return;
    _selectedUser = null;
    notifyListeners();
  }

  Future<AdminUserCreateResult> createUser(CreateUserRequest request) async {
    final result = await _repo.createUser(request);
    if (!_disposed) {
      await refreshDashboard();
    }
    return result;
  }

  Future<void> updateUser(UpdateUserRequest request) async {
    await _repo.updateUser(request);
    if (_disposed) return;
    if (_selectedUser != null && _selectedUser!.userId == request.authUserId) {
      _selectedUser = await _repo.getUserById(request.authUserId);
      if (_disposed) return;
    }
    await refreshDashboard();
    notifyListeners();
  }

  Future<void> deleteUser(String authUserId) async {
    await _repo.deleteUser(authUserId);
    if (_disposed) return;
    if (_selectedUser?.userId == authUserId) {
      _selectedUser = null;
    }
    await refreshDashboard();
    await searchUsers();
  }

  Future<String> resetUserPassword(String authUserId) async {
    return await _repo.resetUserPassword(authUserId);
  }

  Future<void> deactivateUser(String authUserId) async {
    await _repo.deactivateUser(authUserId);
    if (_disposed) return;
    if (_selectedUser?.userId == authUserId) {
      _selectedUser = await _repo.getUserById(authUserId);
      if (_disposed) return;
    }
    await refreshDashboard();
    await searchUsers();
    notifyListeners();
  }

  Future<void> reactivateUser(String authUserId) async {
    await _repo.reactivateUser(authUserId);
    if (_disposed) return;
    if (_selectedUser?.userId == authUserId) {
      _selectedUser = await _repo.getUserById(authUserId);
      if (_disposed) return;
    }
    await refreshDashboard();
    await searchUsers();
    notifyListeners();
  }
}

class AdminScope extends InheritedNotifier<AdminVm> {
  const AdminScope({
    super.key,
    required AdminVm super.notifier,
    required super.child,
  });

  static AdminVm of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<AdminScope>();
      assert(
        scope != null,
        'AdminScope.of() called with no AdminScope in context',
      );
      return scope!.notifier!;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<AdminScope>();
    final scope = element?.widget as AdminScope?;
    assert(
      scope != null,
      'AdminScope.of() called with no AdminScope in context',
    );
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant AdminScope oldWidget) => true;
}
