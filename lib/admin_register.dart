import 'package:flutter/material.dart';
import 'admin_import.dart';
import 'admin_repo.dart';
import 'admin_vm.dart';
import 'common_repo.dart';
import 'supabase_config.dart';
import 'roles.dart';
import 'app_constants.dart';
import 'friendly_error.dart';

class AdminRegister extends StatefulWidget {
  const AdminRegister({super.key});

  @override
  State<AdminRegister> createState() => _AdminRegisterState();
}

Widget buildAdminRegister() => const AdminRegister();

class _AdminRegisterState extends State<AdminRegister> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _accNumber = TextEditingController();
  final _openingBal = TextEditingController();

  AppRole _role = AppRole.student;
  String? _schoolId;
  String? _classId;
  String? _guardianTypeId;
  String? _creditUnionId;
  String? _guardianUserId;
  String? _displayName;
  String? _gender;
  String? _title;

  List<IdName> _classOptions = const <IdName>[];
  List<AdminUser> _guardianOptions = const <AdminUser>[];
  bool _loadingClasses = false;
  bool _loadingGuardians = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = AdminScope.of(context, listen: false);
      vm.ensureLookups();
      _loadGuardians();
      // Load display name for header welcome line
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
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _mobile.dispose();
    _address.dispose();
    _accNumber.dispose();
    _openingBal.dispose();
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
  bool get _needsGuardianType => _needsParent && _guardianUserId != null;
  bool get _needsCreditUnion => _role == AppRole.teller;
  bool get _needsStudentAccount => _role == AppRole.student;

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
        // Fixed, top-centered header (non-scrolling)
        const Center(
          child: Text(
            'Register New Users',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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
        const SizedBox(height: 18),
        // Scrollable content below
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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
                            if (role == null) return;
                            setState(() {
                              _role = role;
                            });
                            if (_needsSchool && _schoolId != null) {
                              _loadClasses(_schoolId);
                            }
                          },
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
                          onChanged: (value) => setState(() => _gender = value),
                          hint: const Text('Select gender'),
                        ),
                      ),
                      if (_needsTitle)
                        _FieldBox(
                          width: 320,
                          label: 'Title',
                          child: DropdownButtonFormField<String>(
                            items: const [
                              DropdownMenuItem(value: 'Mr', child: Text('Mr')),
                              DropdownMenuItem(
                                value: 'Miss',
                                child: Text('Miss'),
                              ),
                              DropdownMenuItem(value: 'Ms', child: Text('Ms')),
                              DropdownMenuItem(
                                value: 'Mrs',
                                child: Text('Mrs'),
                              ),
                              DropdownMenuItem(value: 'Dr', child: Text('Dr')),
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
                              ? const Center(child: CircularProgressIndicator())
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
                                  onChanged: (value) =>
                                      setState(() => _guardianUserId = value),
                                  hint: const Text('Select guardian'),
                                ),
                        ),
                      _FieldBox(
                        width: 320,
                        label: 'Email',
                        child: TextFormField(
                          controller: _email,
                          validator: _required,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      _FieldBox(
                        width: 320,
                        label: 'Initial Password (optional)',
                        child: TextFormField(
                          controller: _password,
                          obscureText: true,
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
                              ? const Center(child: CircularProgressIndicator())
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
                      if (_needsGuardianType)
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
                            validator: (_needsParent && _guardianUserId != null)
                                ? (v) => v == null ? 'Required' : null
                                : null,
                          ),
                        ),
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
                          child: TextFormField(
                            controller: _address,
                            keyboardType: TextInputType.streetAddress,
                          ),
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
                      if (_needsStudentAccount)
                        _FieldBox(
                          width: 320,
                          label: 'Account Number',
                          child: TextFormField(
                            controller: _accNumber,
                            validator: _required,
                          ),
                        ),
                      if (_needsStudentAccount)
                        _FieldBox(
                          width: 320,
                          label: 'Opening Balance',
                          child: TextFormField(
                            controller: _openingBal,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _required,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton(
                      onPressed: _creating ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create User'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => _openCsvImportDialog(vm),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload CSV'),
                    ),
                  ),
                ], // close inner Column children array
              ), // close inner Column
            ), // close Form
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final vm = AdminScope.of(context, listen: false);
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final result = await vm.createUser(
        CreateUserRequest(
          email: _email.text.trim(),
          password: _password.text.isEmpty ? null : _password.text,
          firstName: _firstName.text.trim().ifEmptyToNull() ?? 'Unknown',
          lastName: _lastName.text.trim().ifEmptyToNull() ?? 'User',
          gender: _gender,
          title: _title,
          role: _role,
          schoolId: _needsSchool ? _schoolId : null,
          classId: _needsClass ? _classId : null,
          mobile: _needsGuardianFields
              ? _mobile.text.trim().ifEmptyToNull()
              : null,
          guardianTypeId: _needsGuardianType ? _guardianTypeId : null,
          guardianUserId: _needsParent ? _guardianUserId : null,
          address: _needsGuardianFields
              ? _address.text.trim().ifEmptyToNull()
              : null,
          creditUnionId: _needsCreditUnion ? _creditUnionId : null,
          accNumber: _needsStudentAccount
              ? _accNumber.text.trim().ifEmptyToNull()
              : null,
          openingBal: _needsStudentAccount && _openingBal.text.isNotEmpty
              ? double.tryParse(_openingBal.text.trim())
              : null,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${result.user.fullName} (${result.user.email})',
          ),
        ),
      );
      _clearForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Failed to create user.', e))));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _firstName.clear();
    _lastName.clear();
    _email.clear();
    _password.clear();
    _mobile.clear();
    _address.clear();
    _accNumber.clear();
    _openingBal.clear();
    setState(() {
      _schoolId = null;
      _classId = null;
      _guardianTypeId = null;
      _creditUnionId = null;
      _guardianUserId = null;
      _gender = null;
      _title = null;
    });
  }

  void _openCsvImportDialog(AdminVm vm) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 720,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AdminUsersCsvImport(repo: vm.repo),
            ),
          ),
        );
      },
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
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

extension on String {
  String? ifEmptyToNull() {
    final v = trim();
    return v.isEmpty ? null : v;
  }
}
