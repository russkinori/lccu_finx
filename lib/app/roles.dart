enum AppRole { admin, teacher, principal, guardian, student, teller }

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.admin:
        return 'Admin';
      case AppRole.teacher:
        return 'Teacher';
      case AppRole.principal:
        return 'Principal';
      case AppRole.guardian:
        return 'Guardian';
      case AppRole.student:
        return 'Student';
      case AppRole.teller:
        return 'Teller';
    }
  }

  static AppRole? tryParse(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    for (final role in AppRole.values) {
      if (role.label.toLowerCase() == value) {
        return role;
      }
    }
    return null;
  }
}
