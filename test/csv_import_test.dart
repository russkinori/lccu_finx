// Unit tests for the CSV parsing and row-validation logic that lives inside
// admin_import.dart (_parseCsvText / _startImport).
//
// The helpers below replicate the exact logic from those private methods so
// that edge-cases and security-relevant validations (required columns, blank
// row skipping, role validation) are covered without spinning up a full widget.

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lccu_finx/app/roles.dart';

// ---------------------------------------------------------------------------
// Header + row parsing (mirrors _parseCsvText)
// ---------------------------------------------------------------------------

const _kRequired = {'email', 'first_name', 'last_name', 'role'};

/// Returns (rows, error).  error is non-null when parsing fails.
(List<Map<String, String>>, String?) _parseCsvText(String text) {
  final table = Csv().decode(text);

  if (table.isEmpty) {
    return ([], 'Empty CSV file.');
  }

  final header = table.first.map((e) => e.toString().trim()).toList();
  final headerLower = header.map((e) => e.toLowerCase()).toList();

  final missing =
      _kRequired.where((h) => !headerLower.contains(h)).toList()..sort();
  if (missing.isNotEmpty) {
    return ([], 'Missing required column(s): ${missing.join(', ')}');
  }

  final rows = <Map<String, String>>[];
  for (int i = 1; i < table.length; i++) {
    final raw = table[i];
    if (raw.isEmpty) continue;

    final map = <String, String>{};
    for (int c = 0; c < header.length; c++) {
      final key = headerLower[c];
      final val = c < raw.length ? (raw[c]?.toString() ?? '') : '';
      map[key] = val.trim();
    }

    // Skip entirely blank lines
    final blank =
        (map['email'] ?? '').isEmpty &&
        (map['first_name'] ?? '').isEmpty &&
        (map['last_name'] ?? '').isEmpty &&
        (map['role'] ?? '').isEmpty;
    if (!blank) rows.add(map);
  }

  return (rows, null);
}

// ---------------------------------------------------------------------------
// Row validation (mirrors the per-row loop in _startImport)
// ---------------------------------------------------------------------------

String? _validateRow(Map<String, String> row) {
  for (final key in _kRequired) {
    if ((row[key] ?? '').trim().isEmpty) {
      return 'Missing required "$key"';
    }
  }

  final role = AppRoleX.tryParse((row['role'] ?? '').trim().toLowerCase());
  if (role == null) {
    return 'Invalid role "${row['role']}". '
        'Allowed: student, teacher, principal, guardian, teller, admin';
  }

  return null; // valid
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CSV header parsing', () {
    test('returns error for completely empty input', () {
      final (rows, error) = _parseCsvText('');
      expect(error, isNotNull);
      expect(rows, isEmpty);
    });

    test('returns error when all required columns are missing', () {
      final csv = 'name,age\nAlice,30\n';
      final (_, error) = _parseCsvText(csv);
      expect(error, isNotNull);
      expect(error, contains('email'));
      expect(error, contains('role'));
    });

    test('returns error listing only the actually missing columns', () {
      // Has email and role but not first_name / last_name
      final csv = 'email,role\ntest@x.com,student\n';
      final (_, error) = _parseCsvText(csv);
      expect(error, isNotNull);
      expect(error, contains('first_name'));
      expect(error, contains('last_name'));
      expect(error, isNot(contains('email')));
      expect(error, isNot(contains('role')));
    });

    test('accepts header row with all required columns', () {
      final csv = 'email,first_name,last_name,role\n'
          'alice@example.com,Alice,Smith,student\n';
      final (rows, error) = _parseCsvText(csv);
      expect(error, isNull);
      expect(rows, hasLength(1));
    });

    test('header matching is case-insensitive', () {
      final csv = 'EMAIL,First_Name,LAST_NAME,Role\n'
          'bob@example.com,Bob,Jones,teacher\n';
      final (rows, error) = _parseCsvText(csv);
      expect(error, isNull);
      expect(rows.first['email'], 'bob@example.com');
      expect(rows.first['first_name'], 'Bob');
      expect(rows.first['role'], 'teacher');
    });

    test('extra columns beyond the required set are preserved', () {
      final csv = 'email,first_name,last_name,role,school_name\n'
          'c@x.com,Carol,Brown,principal,Happy Hill\n';
      final (rows, error) = _parseCsvText(csv);
      expect(error, isNull);
      expect(rows.first['school_name'], 'Happy Hill');
    });
  });

  group('CSV row parsing', () {
    test('parses a valid data row into a Map keyed by lower-case header', () {
      final csv = 'email,first_name,last_name,role\n'
          'dave@example.com,Dave,Taylor,teller\n';
      final (rows, _) = _parseCsvText(csv);
      final row = rows.first;
      expect(row['email'], 'dave@example.com');
      expect(row['first_name'], 'Dave');
      expect(row['last_name'], 'Taylor');
      expect(row['role'], 'teller');
    });

    test('trims whitespace from cell values', () {
      final csv = 'email,first_name,last_name,role\n'
          ' eve@x.com , Eve , Hill , admin \n';
      final (rows, _) = _parseCsvText(csv);
      expect(rows.first['email'], 'eve@x.com');
      expect(rows.first['first_name'], 'Eve');
      expect(rows.first['role'], 'admin');
    });

    test('skips blank rows (all required fields empty)', () {
      final csv = 'email,first_name,last_name,role\n'
          'real@x.com,Real,Person,guardian\n'
          ',,,\n' // blank row
          'other@x.com,Other,User,student\n';
      final (rows, _) = _parseCsvText(csv);
      expect(rows, hasLength(2));
      expect(rows.map((r) => r['email']), containsAll(['real@x.com', 'other@x.com']));
    });

    test('handles header-only CSV (no data rows) without error', () {
      final csv = 'email,first_name,last_name,role\n';
      final (rows, error) = _parseCsvText(csv);
      expect(error, isNull);
      expect(rows, isEmpty);
    });

    test('parses multiple data rows', () {
      final csv = 'email,first_name,last_name,role\n'
          'a@x.com,A,One,student\n'
          'b@x.com,B,Two,teacher\n'
          'c@x.com,C,Three,principal\n';
      final (rows, _) = _parseCsvText(csv);
      expect(rows, hasLength(3));
    });
  });

  group('Row-level validation', () {
    Map<String, String> validRow({String role = 'student'}) => {
      'email': 'x@example.com',
      'first_name': 'Test',
      'last_name': 'User',
      'role': role,
    };

    test('returns null (valid) for a complete, correctly-typed row', () {
      expect(_validateRow(validRow()), isNull);
    });

    test('returns error when email is missing', () {
      final row = validRow()..['email'] = '';
      expect(_validateRow(row), contains('email'));
    });

    test('returns error when first_name is missing', () {
      final row = validRow()..['first_name'] = '';
      expect(_validateRow(row), contains('first_name'));
    });

    test('returns error when last_name is missing', () {
      final row = validRow()..['last_name'] = '';
      expect(_validateRow(row), contains('last_name'));
    });

    test('returns error when role is missing', () {
      final row = validRow()..['role'] = '';
      expect(_validateRow(row), contains('role'));
    });

    test('returns error for an invalid role value', () {
      final row = validRow(role: 'cashier');
      final error = _validateRow(row);
      expect(error, isNotNull);
      expect(error, contains('cashier'));
    });

    test('accepts all valid AppRole values', () {
      for (final role in AppRole.values) {
        final row = validRow(role: role.label.toLowerCase());
        expect(_validateRow(row), isNull, reason: 'role: ${role.label}');
      }
    });
  });
}
