import 'dart:async';
import 'package:flutter/material.dart';
import 'admin_repo.dart';
import 'admin_vm.dart';
import 'common_repo.dart';
import 'supabase_config.dart';
import 'roles.dart';
import 'app_constants.dart';
import 'friendly_error.dart';

class AdminUpdate extends StatefulWidget {
  const AdminUpdate({super.key});

  @override
  State<AdminUpdate> createState() => _AdminUpdateState();
}

Widget buildAdminUpdate() => const AdminUpdate();

class _AdminUpdateState extends State<AdminUpdate> {
  String? _displayName;
  final _searchController = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  AppRole? _role;
  String? _schoolId;
  String? _classId;
  String? _guardianTypeId;
  String? _creditUnionId;
  String? _guardianUserId;
  String? _gender;
  String? _title;
  List<IdName> _classOptions = const <IdName>[];
  List<AdminUser> _guardianOptions = const <AdminUser>[];
  bool _loadingClasses = false;
  bool _loadingGuardians = false;
  bool _updating = false;
  bool _deleting = false;
  bool _showResults = true; // Hide results after selection until new search

  AdminUser? _selectedUser;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = AdminScope.of(context, listen: false);
      vm.ensureLookups();
      _loadGuardians();
      vm.searchUsers();
      // Load display name for teller-like header
      CommonRepository(supabase).getCurrentUserDisplayName(fallback: '').then((
        name,
      ) {
        if (!mounted) return;
        setState(() => _displayName = name);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _mobile.dispose();
    _address.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool get _needsSchool =>
      _role == AppRole.student ||
      _role == AppRole.teacher ||
      _role == AppRole.principal;
  bool get _needsClass => _role == AppRole.student;
  bool get _needsParent => _role == AppRole.student;
  bool get _needsTitle =>
      _role == AppRole.teacher ||
      _role == AppRole.principal ||
      _role == AppRole.guardian ||
      _role == AppRole.teller ||
      _role == AppRole.admin;
  bool get _needsGuardianFields => _role == AppRole.guardian;
  bool get _needsCreditUnion => _role == AppRole.teller;

  @override
  Widget build(BuildContext context) {
    final vm = AdminScope.of(context);
    final schools = vm.schools;
    final guardianTypes = vm.guardianTypes;
    final creditUnions = vm.creditUnions;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(
          child: Text(
            'Update Users',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        if ((_displayName ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(
                    text: 'Welcome ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: _displayName!,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Scrollable content area below the fixed header
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSearchBar(vm),
                const SizedBox(height: 16),
                _buildSearchResults(vm),
                const SizedBox(height: 24),
                if (_selectedUser != null)
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 32,
                          runSpacing: 18,
                          children: [
                            _FieldBox(
                              width: 320,
                              label: 'Role',
                              child: DropdownButtonFormField<AppRole>(
                                initialValue: _role,
                                items: AppRole.values
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (role) {
                                  setState(() {
                                    _role = role;
                                    if (!_needsSchool) {
                                      _schoolId = null;
                                      _classId = null;
                                      _classOptions = const <IdName>[];
                                    }
                                    if (!_needsParent) {
                                      _guardianUserId = null;
                                    }
                                    if (!_needsGuardianFields) {
                                      _guardianTypeId = null;
                                      _mobile.clear();
                                      _address.clear();
                                    }
                                    if (!_needsCreditUnion) {
                                      _creditUnionId = null;
                                    }
                                  });
                                  if (_needsSchool && _schoolId != null) {
                                    _loadClasses(_schoolId);
                                  }
                                },
                                validator: (value) =>
                                    value == null ? 'Required' : null,
                              ),
                            ),
                            _FieldBox(
                              width: 320,
                              label: 'First Name',
                              child: TextFormField(
                                controller: _firstName,
                                validator: _required,
                              ),
                            ),
                            _FieldBox(
                              width: 320,
                              label: 'Last Name',
                              child: TextFormField(
                                controller: _lastName,
                                validator: _required,
                              ),
                            ),
                            _FieldBox(
                              width: 320,
                              label: 'Gender',
                              child: DropdownButtonFormField<String>(
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Male',
                                    child: Text('Male'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Female',
                                    child: Text('Female'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Other',
                                    child: Text('Other'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Prefer not to say',
                                    child: Text('Prefer not to say'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _gender = value),
                                hint: const Text('Select gender'),
                              ),
                            ),
                            if (_needsTitle)
                              _FieldBox(
                                width: 320,
                                label: 'Title',
                                child: DropdownButtonFormField<String>(
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Mr',
                                      child: Text('Mr'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Miss',
                                      child: Text('Miss'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Ms',
                                      child: Text('Ms'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Mrs',
                                      child: Text('Mrs'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Dr',
                                      child: Text('Dr'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Prof',
                                      child: Text('Prof'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Other',
                                      child: Text('Other'),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _title = value),
                                  hint: const Text('Select title'),
                                ),
                              ),
                            if (_needsParent)
                              _FieldBox(
                                width: 320,
                                label: 'Link to Parent',
                                child: _loadingGuardians
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : DropdownButtonFormField<String>(
                                        initialValue: _guardianUserId,
                                        items: _guardianOptions
                                            .map(
                                              (g) => DropdownMenuItem(
                                                value: g.userId,
                                                child: Text(g.fullName),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) => setState(
                                          () => _guardianUserId = value,
                                        ),
                                        hint: const Text('Select guardian'),
                                      ),
                              ),
                            if (_needsParent)
                              _FieldBox(
                                width: 320,
                                label: 'Guardian Type',
                                child: DropdownButtonFormField<String>(
                                  initialValue: _guardianTypeId,
                                  items: guardianTypes
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g.id,
                                          child: Text(g.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _guardianTypeId = value),
                                  hint: const Text('Select guardian type'),
                                ),
                              ),
                            if (_needsParent)
                              _StudentGuardianInfo(user: _selectedUser!),
                            _FieldBox(
                              width: 320,
                              label: 'Email',
                              child: TextFormField(
                                controller: _email,
                                validator: _required,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            if (_needsSchool)
                              _FieldBox(
                                width: 320,
                                label: 'School',
                                child: DropdownButtonFormField<String>(
                                  initialValue: _schoolId,
                                  items: schools
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(s.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _schoolId = value;
                                      _classId = null;
                                    });
                                    _loadClasses(value);
                                  },
                                  hint: const Text('Select school'),
                                ),
                              ),
                            if (_needsClass)
                              _FieldBox(
                                width: 320,
                                label: 'Class',
                                child: _loadingClasses
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : DropdownButtonFormField<String>(
                                        initialValue: _classId,
                                        items: _classOptions
                                            .map(
                                              (c) => DropdownMenuItem(
                                                value: c.id,
                                                child: Text(c.name),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) =>
                                            setState(() => _classId = value),
                                        hint: const Text('Select class'),
                                      ),
                              ),
                            if (_needsGuardianFields)
                              _FieldBox(
                                width: 320,
                                label: 'Guardian Type',
                                child: DropdownButtonFormField<String>(
                                  initialValue: _guardianTypeId,
                                  items: guardianTypes
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g.id,
                                          child: Text(g.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _guardianTypeId = value),
                                  hint: const Text('Select guardian type'),
                                ),
                              ),
                            if (_needsGuardianFields) const _GuardianTypeInfo(),
                            if (_needsGuardianFields)
                              _FieldBox(
                                width: 320,
                                label: 'Mobile Number',
                                child: TextFormField(
                                  controller: _mobile,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            if (_needsGuardianFields)
                              _FieldBox(
                                width: 320,
                                label: 'Address',
                                child: TextFormField(controller: _address),
                              ),
                            if (_needsCreditUnion)
                              _FieldBox(
                                width: 320,
                                label: 'Credit Union Branch',
                                child: DropdownButtonFormField<String>(
                                  initialValue: _creditUnionId,
                                  items: creditUnions
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _creditUnionId = value),
                                  hint: const Text('Select branch'),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: _updating
                                  ? null
                                  : () => _submitUpdate(vm),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: _updating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save Changes'),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton(
                              onPressed: _deleting
                                  ? null
                                  : () => _confirmActivationToggle(vm),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _selectedUser?.isActive == true
                                    ? Colors.orange[700]
                                    : Colors.green[700],
                                foregroundColor: Colors.white,
                                side: BorderSide.none,
                              ),
                              child: _deleting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _selectedUser?.isActive == true
                                          ? 'Deactivate User'
                                          : 'Reactivate User',
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Select a user to edit details.',
                    style: TextStyle(color: Colors.black54),
                  ),
              ], // close inner Column children
            ), // close inner Column
          ), // close ConstrainedBox
        ), // close Center
      ], // close outer Column children
    ); // close outer Column (the content variable)

    // On mobile (inside DashboardShell's scroll view), return content directly
    // On web (inside WebShell's Expanded widget), wrap in SingleChildScrollView
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasMaxHeight = constraints.maxHeight != double.infinity;

        if (hasMaxHeight) {
          // Web layout: wrap in scroll view to handle overflow
          return SingleChildScrollView(child: content);
        } else {
          // Mobile layout: content flows in parent scroll view
          return content;
        }
      },
    );
  }

  Widget _buildSearchBar(AdminVm vm) {
    return TextField(
      controller: _searchController,
      autofillHints: const [AutofillHints.name, AutofillHints.email],
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            setState(() {
              _searchController.clear();
              _showResults = true;
              _selectedUser = null;
            });
            vm.searchUsers();
          },
        ),
        hintText: 'Search by name or email',
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        // New search initiated -> show results and clear current selection
        setState(() {
          _showResults = true;
          _selectedUser = null;
        });
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          vm.searchUsers(query: value.trim().isEmpty ? null : value.trim());
        });
      },
    );
  }

  Widget _buildSearchResults(AdminVm vm) {
    if (!_showResults) {
      return const SizedBox.shrink();
    }
    if (vm.isSearchingUsers && vm.searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.searchError != null) {
      return Text(
        vm.searchError!,
        style: const TextStyle(color: Colors.redAccent),
      );
    }
    if (vm.searchResults.isEmpty) {
      return const Text('No users found.');
    }
    return SizedBox(
      height: 400,
      child: ListView.separated(
        itemBuilder: (context, index) {
          final user = vm.searchResults[index];
          final isSelected = _selectedUser?.userId == user.userId;
          final roles = user.roles.map((r) => r.label).join(', ');
          // Build subtitle parts: email, roles, and (for students only) class name
          final subtitleParts = <String>[user.email, roles];
          final isStudent = user.roles.contains(AppRole.student);
          if (isStudent &&
              (user.className != null && user.className!.isNotEmpty)) {
            subtitleParts.add(user.className!);
          }
          return ListTile(
            selected: isSelected,
            title: Text(user.fullName),
            subtitle: Text(subtitleParts.join(' • ')),
            trailing: user.isActive
                ? const Chip(label: Text('Active'))
                : const Chip(
                    label: Text('Inactive'),
                    backgroundColor: Colors.grey,
                  ),
            onTap: () => _selectUser(user),
          );
        },
        separatorBuilder: (_, i_) => const Divider(height: 1),
        itemCount: vm.searchResults.length,
      ),
    );
  }

  Future<void> _selectUser(AdminUser user) async {
    setState(() {
      _selectedUser = user;
      _showResults = false; // Hide results after a user is selected
      _role = user.roles.isEmpty ? null : user.roles.first;
      _firstName.text = user.firstName;
      _lastName.text = user.lastName;
      _gender = user.gender;
      _title = user.title;
      _email.text = user.email;
      _mobile.text = user.mobile ?? '';
      _address.text = user.address ?? '';
      _schoolId = user.schoolId;
      _classId = user.classId;
      _guardianTypeId = user.guardianTypeId;
      _creditUnionId = user.creditUnionId;
      _guardianUserId = user.guardianUserId;
    });
    // Dismiss keyboard to focus on the edit form
    FocusScope.of(context).unfocus();

    if (_needsClass && _schoolId != null) {
      await _loadClasses(_schoolId);
    }
  }

  Future<void> _loadClasses(String? schoolId) async {
    if (!_needsClass) {
      setState(() => _classOptions = const <IdName>[]);
      return;
    }
    if (schoolId == null) {
      setState(() => _classOptions = const <IdName>[]);
      return;
    }
    setState(() => _loadingClasses = true);
    final vm = AdminScope.of(context, listen: false);
    try {
      final classes = await vm.classesForSchool(schoolId);
      if (!mounted) return;
      setState(() {
        _classOptions = classes;
        if (!_classOptions.any((c) => c.id == _classId)) {
          _classId = null;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loadingClasses = false);
      }
    }
  }

  Future<void> _loadGuardians() async {
    setState(() => _loadingGuardians = true);
    final vm = AdminScope.of(context, listen: false);
    try {
      final guardians = await vm.guardians();
      if (!mounted) return;
      setState(() {
        _guardianOptions = guardians;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingGuardians = false);
      }
    }
  }

  Future<void> _submitUpdate(AdminVm vm) async {
    if (_selectedUser == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _updating = true);
    try {
      await vm.updateUser(
        UpdateUserRequest(
          authUserId: _selectedUser!.userId,
          email: _email.text.trim().ifEmptyToNull() ?? _selectedUser!.email,
          firstName:
              _firstName.text.trim().ifEmptyToNull() ??
              _selectedUser!.firstName,
          lastName:
              _lastName.text.trim().ifEmptyToNull() ?? _selectedUser!.lastName,
          gender: _gender,
          title: _title,
          role: _role,
          schoolId: _needsSchool ? _schoolId : null,
          classId: _needsClass ? _classId : null,
          mobile: _needsGuardianFields
              ? _mobile.text.trim().ifEmptyToNull()
              : null,
          guardianTypeId: (_needsGuardianFields || _needsParent) ? _guardianTypeId : null,
          creditUnionId: _needsCreditUnion ? _creditUnionId : null,
          address: _needsGuardianFields
              ? _address.text.trim().ifEmptyToNull()
              : null,
          guardianUserId: _needsParent ? _guardianUserId : null,
        ),
      );
      if (!mounted) return;
      final query = _searchController.text.trim();
      vm.searchUsers(query: query.isEmpty ? null : query);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${_selectedUser!.fullName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Failed to update user.', e))));
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _confirmActivationToggle(AdminVm vm) async {
    if (_selectedUser == null) return;

    final isActive = _selectedUser!.isActive;
    final actionLabel = isActive ? 'deactivate' : 'reactivate';
    final title = isActive ? 'Deactivate User' : 'Reactivate User';
    final confirmLabel = isActive ? 'Deactivate User' : 'Reactivate User';
    final actionColor = isActive ? Colors.orange[700] : Colors.green[700];
    final warningText = isActive
        ? "This will remove the user's active roles and prevent them from using the app until they are reactivated."
        : "This will restore the user's previous roles and allow them to use the app again.";

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage(AppAssets.popupBg),
              fit: BoxFit.fill,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: actionColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Are you sure you want to $actionLabel:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_selectedUser!.fullName}\n${_selectedUser!.email}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        warningText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 12),
                        Text(
                          'This is a soft deactivation, not a permanent delete.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: actionColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: actionColor,
                      ),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      if (_selectedUser!.isActive) {
        await vm.deactivateUser(_selectedUser!.userId);
      } else {
        await vm.reactivateUser(_selectedUser!.userId);
      }
      if (!mounted) return;
      final query = _searchController.text.trim();
      await vm.searchUsers(query: query.isEmpty ? null : query);
      final refreshed = await vm.loadUser(_selectedUser!.userId);
      if (!mounted) return;
      setState(() {
        _selectedUser = refreshed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${refreshed?.fullName ?? 'User'} ${refreshed?.isActive == true ? 'reactivated' : 'deactivated'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Failed to update user status.', e))));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}

class _StudentGuardianInfo extends StatelessWidget {
  const _StudentGuardianInfo({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final count = user.studentGuardianLinkCount ?? 0;
    final note =
        user.studentGuardianSelectionNote ??
        'Primary guardian will be used if set; otherwise the most recent link.';
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'This student has $count guardian link(s). $note',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianTypeInfo extends StatelessWidget {
  const _GuardianTypeInfo();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdminUpdateState>();
    final user = state?._selectedUser;
    if (user == null || !user.roles.contains(AppRole.guardian)) {
      return const SizedBox.shrink();
    }
    final count = user.guardianLinkCount ?? 0;
    final source = user.guardianTypeSource == 'primary'
        ? 'Primary'
        : 'First available';
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Type is stored per student link. Currently derived from $source across $count link(s).',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.width,
    required this.label,
    required this.child,
  });

  final double width;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

extension StringNullX on String {
  String? ifEmptyToNull() {
    final v = trim();
    return v.isEmpty ? null : v;
  }
}
