// Tests for inline validation logic that is embedded in widgets but
// represents security-critical business rules.
//
// Each helper function below replicates the exact regex / logic used
// in production so that regressions are caught immediately.

import 'package:flutter_test/flutter_test.dart';
import 'package:lccu_finx/app/roles.dart';

// ── Email validator ────────────────────────────────────────────────────────
// Pattern used in login_page.dart and web_login.dart
bool _isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

// ── Password complexity ────────────────────────────────────────────────────
// Rule used in reset_password.dart and verify_otp_password.dart:
//   • at least 8 characters
//   • at least one letter  [A-Za-z]
//   • at least one digit   [0-9]
bool _isStrongPassword(String password) =>
    password.length >= 8 &&
    RegExp(r'[A-Za-z]').hasMatch(password) &&
    RegExp(r'[0-9]').hasMatch(password);

void main() {
  // ── Email format ──────────────────────────────────────────────────────────
  group('Email format validator', () {
    test('accepts well-formed email addresses', () {
      expect(_isValidEmail('user@example.com'), isTrue);
      expect(_isValidEmail('admin@school.edu.tt'), isTrue);
      expect(_isValidEmail('first.last+tag@domain.org'), isTrue);
      expect(_isValidEmail('x@y.z'), isTrue);
    });

    test('rejects empty string', () {
      expect(_isValidEmail(''), isFalse);
    });

    test('rejects address without @ symbol', () {
      expect(_isValidEmail('notanemail'), isFalse);
      expect(_isValidEmail('missingatsign.com'), isFalse);
    });

    test('rejects address without domain', () {
      expect(_isValidEmail('missing@'), isFalse);
    });

    test('rejects address without local part', () {
      expect(_isValidEmail('@nodomain.com'), isFalse);
    });

    test('rejects address without TLD dot', () {
      expect(_isValidEmail('nodot@domain'), isFalse);
    });

    test('rejects address containing whitespace', () {
      expect(_isValidEmail('has space@example.com'), isFalse);
      expect(_isValidEmail('user@exam ple.com'), isFalse);
    });

    test('rejects multiple @ symbols', () {
      expect(_isValidEmail('a@@b.com'), isFalse);
    });
  });

  // ── Password complexity ───────────────────────────────────────────────────
  group('Password complexity validator', () {
    test('accepts password with exactly 8 chars, a letter and a digit', () {
      expect(_isStrongPassword('abc12345'), isTrue);
    });

    test('accepts longer passwords with letters and digits', () {
      expect(_isStrongPassword('Password1'), isTrue);
      expect(_isStrongPassword('P@ssw0rd!'), isTrue);
      expect(_isStrongPassword('abcdefg1'), isTrue);
    });

    test('rejects password shorter than 8 characters', () {
      expect(_isStrongPassword('abc123'), isFalse); // 6 chars
      expect(_isStrongPassword('a1b2c3'), isFalse); // 6 chars
      expect(_isStrongPassword(''), isFalse);
    });

    test('rejects password with exactly 7 characters', () {
      expect(_isStrongPassword('abc1234'), isFalse); // 7 chars
    });

    test('rejects password with no letters', () {
      expect(_isStrongPassword('12345678'), isFalse);
      expect(_isStrongPassword('99999999'), isFalse);
    });

    test('rejects password with no digits', () {
      expect(_isStrongPassword('abcdefgh'), isFalse);
      expect(_isStrongPassword('ABCDEFGH'), isFalse);
    });

    test('accepts password with uppercase letters and digits', () {
      expect(_isStrongPassword('ABCD1234'), isTrue);
    });

    test('accepts password that starts with a digit', () {
      expect(_isStrongPassword('1password'), isTrue);
    });
  });

  // ── AppRoleX.tryParse ─────────────────────────────────────────────────────
  group('AppRoleX.tryParse', () {
    test('parses lowercase role strings', () {
      expect(AppRoleX.tryParse('admin'), AppRole.admin);
      expect(AppRoleX.tryParse('teacher'), AppRole.teacher);
      expect(AppRoleX.tryParse('principal'), AppRole.principal);
      expect(AppRoleX.tryParse('guardian'), AppRole.guardian);
      expect(AppRoleX.tryParse('student'), AppRole.student);
      expect(AppRoleX.tryParse('teller'), AppRole.teller);
    });

    test('parses role strings case-insensitively', () {
      expect(AppRoleX.tryParse('Admin'), AppRole.admin);
      expect(AppRoleX.tryParse('TEACHER'), AppRole.teacher);
      expect(AppRoleX.tryParse('Principal'), AppRole.principal);
      expect(AppRoleX.tryParse('GUARDIAN'), AppRole.guardian);
    });

    test('trims whitespace from input', () {
      expect(AppRoleX.tryParse(' admin '), AppRole.admin);
      expect(AppRoleX.tryParse('student '), AppRole.student);
    });

    test('returns null for null input', () {
      expect(AppRoleX.tryParse(null), isNull);
    });

    test('returns null for empty string', () {
      expect(AppRoleX.tryParse(''), isNull);
    });

    test('returns null for unrecognised role strings', () {
      expect(AppRoleX.tryParse('unknown'), isNull);
      expect(AppRoleX.tryParse('superadmin'), isNull);
      expect(AppRoleX.tryParse('cashier'), isNull);
      expect(AppRoleX.tryParse('123'), isNull);
    });
  });
}
