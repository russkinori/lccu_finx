// lib/presentation/views/admin/admin_users_csv_import.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:lccu_finx/features/admin/data/admin_repo.dart'
    show AdminRepo, CreateUserRequest, IdName, UserSearchFilter;
import 'package:lccu_finx/app/roles.dart';
import 'package:lccu_finx/core/utils/download_helper.dart';
import 'package:lccu_finx/core/widgets/friendly_error.dart';

/// Admin CSV Import Page
///
/// - Pick a .csv file
/// - Validate headers and rows
/// - Create users one-by-one via AdminRepo.createUser
/// - If a guardian email is provided but the user doesn't exist, create the guardian
///   from guardian_* columns (guardian_first_name, guardian_last_name, guardian_mobile, guardian_address, guardian_password)
/// - Show progress and per-row results
/// - Export failures as CSV
class AdminUsersCsvImport extends StatefulWidget {
  final AdminRepo repo;
  const AdminUsersCsvImport({super.key, required this.repo});

  @override
  State<AdminUsersCsvImport> createState() => _AdminUsersCsvImportState();
}

class _AdminUsersCsvImportState extends State<AdminUsersCsvImport> {
  List<Map<String, String>> _rows = [];
  List<_ImportResult> _results = [];
  bool _parsing = false;
  bool _importing = false;
  int _done = 0;

  // Header mapping to index (lowercased)
  final Set<String> _required = {'email', 'first_name', 'last_name', 'role'};

  // Caches for name->id lookups to allow CSV to supply names instead of ids
  final Map<String, String> _schoolNameToId = {};
  final Map<String, List<IdName>> _classesCache = {};
  final Map<String, String> _guardianTypeNameToId = {};
  final Map<String, String> _creditUnionNameToId = {};

  Future<void> _pickFile() async {
    setState(() {
      _rows = [];
      _results = [];
      _done = 0;
    });

    final res = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    try {
      // Prefer bytes if present (web/desktop)
      if (f.bytes != null) {
        final text = utf8.decode(f.bytes!);
        await _parseCsvText(text, suggestedName: f.name);
      } else if (f.path != null) {
        final file = File(f.path!);
        final text = await file.readAsString();
        await _parseCsvText(text, suggestedName: f.name);
      } else {
        throw const FormatException('No file data.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Failed to read CSV.', e))));
    }
  }

  Future<void> _parseCsvText(String text, {String? suggestedName}) async {
    setState(() {
      _parsing = true;
      _rows = [];
      _results = [];
      _done = 0;
    });

    try {
      final table = Csv().decode(text);
      if (table.isEmpty) {
        throw const FormatException('Empty CSV file.');
      }

      // Read header row (case-insensitive) and map column indices
      final header = table.first.map((e) => e.toString().trim()).toList();
      final headerLower = header.map((e) => e.toLowerCase()).toList();
      final missing = _required.where((h) => !headerLower.contains(h)).toList();
      if (missing.isNotEmpty) {
        throw FormatException(
          'Missing required column(s): ${missing.join(', ')}',
        );
      }

      // Build rows as Map<header, value>
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

        // Skip entirely blank lines (no email + no names)
        final blank =
            (map['email'] ?? '').isEmpty &&
            (map['first_name'] ?? '').isEmpty &&
            (map['last_name'] ?? '').isEmpty &&
            (map['role'] ?? '').isEmpty;
        if (!blank) rows.add(map);
      }

      setState(() {
        _rows = rows;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parsed ${rows.length} row(s). Ready to import.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _startImport() async {
    if (_rows.isEmpty || _importing) return;

    setState(() {
      _importing = true;
      _results = [];
      _done = 0;
    });

    final results = <_ImportResult>[];

    // Prepare lookups so CSV can use human-readable names (school, class, guardian type, credit union)
    try {
      final schools = await widget.repo.getSchoolsForDropdown();
      _schoolNameToId.clear();
      for (final s in schools) {
        _schoolNameToId[s.name.toLowerCase()] = s.id;
      }

      final gtypes = await widget.repo.getGuardianTypes();
      _guardianTypeNameToId.clear();
      for (final g in gtypes) {
        _guardianTypeNameToId[g.name.toLowerCase()] = g.id;
      }

      final cus = await widget.repo.getCreditUnions();
      _creditUnionNameToId.clear();
      for (final c in cus) {
        _creditUnionNameToId[c.name.toLowerCase()] = c.id;
      }
    } catch (_) {
      // ignore lookup failures; we'll surface per-row errors if names can't be resolved
    }

    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      String? error;

      // Validate required fields
      for (final key in _required) {
        if ((r[key] ?? '').trim().isEmpty) {
          error = 'Missing required "$key"';
          break;
        }
      }

      // Parse role
      AppRole? role;
      if (error == null) {
        role = AppRoleX.tryParse((r['role'] ?? '').trim().toLowerCase());
        if (role == null) {
          error =
              'Invalid role "${r['role']}". Allowed: student, teacher, principal, guardian, teller, admin';
        }
      }

      if (error == null) {
        // Resolve human-friendly names to IDs when possible
        String schoolId = (r['school_id'] ?? '').trim();
        if (schoolId.isEmpty) {
          final sname = (r['school'] ?? r['school_name'] ?? '').trim();
          if (sname.isNotEmpty) {
            final id = _schoolNameToId[sname.toLowerCase()];
            if (id == null) {
              error = 'Unknown school "$sname"';
            } else {
              schoolId = id;
            }
          }
        }

        String classId = (r['class_id'] ?? '').trim();
        if (classId.isEmpty) {
          final cname = (r['class'] ?? r['class_name'] ?? '').trim();
          if (cname.isNotEmpty) {
            if (schoolId.isEmpty) {
              error = 'Class provided but school is missing or unknown';
            } else {
              // load classes for this school (cached)
              var classes = _classesCache[schoolId];
              if (classes == null) {
                try {
                  classes = await widget.repo.getClassesForSchool(schoolId);
                } catch (_) {
                  classes = <IdName>[];
                }
                _classesCache[schoolId] = classes;
              }
              final matches = classes
                  .where((c) => c.name.toLowerCase() == cname.toLowerCase())
                  .toList();
              if (matches.length == 1) {
                classId = matches.first.id;
              } else if (matches.isEmpty) {
                error =
                    'Unknown class "$cname" for school ${r['school'] ?? r['school_name'] ?? ''}';
              } else {
                error =
                    'Ambiguous class "$cname" for school ${r['school'] ?? r['school_name'] ?? ''}';
              }
            }
          }
        }

        String guardianTypeId = (r['guardian_type_id'] ?? '').trim();
        if (guardianTypeId.isEmpty) {
          final gname = (r['guardian_type'] ?? r['guardian_type_name'] ?? '')
              .trim();
          if (gname.isNotEmpty) {
            final id = _guardianTypeNameToId[gname.toLowerCase()];
            if (id == null) {
              error = 'Unknown guardian type "$gname"';
            } else {
              guardianTypeId = id;
            }
          }
        }

        String creditUnionId = (r['credit_union_id'] ?? '').trim();
        if (creditUnionId.isEmpty) {
          final cuname = (r['credit_union'] ?? r['credit_union_name'] ?? '')
              .trim();
          if (cuname.isNotEmpty) {
            final id = _creditUnionNameToId[cuname.toLowerCase()];
            if (id == null) {
              error = 'Unknown credit union "$cuname"';
            } else {
              creditUnionId = id;
            }
          }
        }

        // Guardian user: allow providing guardian_user_id or guardian_user_email.
        // If guardian email is provided but not found, allow creating the guardian if full guardian_* details are present.
        String guardianUserId = (r['guardian_user_id'] ?? '').trim();
        final guEmail = (r['guardian_user_email'] ?? r['guardian_user'] ?? '')
            .trim();
        if (guardianUserId.isEmpty && guEmail.isNotEmpty) {
          if (!guEmail.contains('@')) {
            error = 'Invalid guardian email "$guEmail"';
          } else {
            try {
              final search = await widget.repo.searchUsers(
                UserSearchFilter(searchQuery: guEmail, limit: 10),
              );
              final matches = search.users
                  .where((u) => u.email.toLowerCase() == guEmail.toLowerCase())
                  .toList();
              if (matches.length == 1) {
                guardianUserId = matches.first.userId;
              } else if (matches.isEmpty) {
                // Not found — attempt to create guardian if details are present
                final guFirst = (r['guardian_first_name'] ?? '').trim();
                final guLast = (r['guardian_last_name'] ?? '').trim();
                if (guFirst.isEmpty || guLast.isEmpty) {
                  error =
                      'No guardian user found with email "$guEmail" and no guardian_first_name/guardian_last_name provided to create one.';
                } else {
                  // Build guardian create request — password is intentionally
                  // omitted; Supabase will auto-generate a secure one server-side.
                  final guMobile =
                      (r['guardian_mobile'] ?? r['guardian_phone'] ?? '')
                          .trim();
                  final guAddress = (r['guardian_address'] ?? '').trim();

                  try {
                    final gReq = CreateUserRequest(
                      email: guEmail,
                      password: null,
                      firstName: guFirst,
                      lastName: guLast,
                      role: AppRole.guardian,
                      guardianTypeId: guardianTypeId.isEmpty
                          ? null
                          : guardianTypeId,
                      mobile: guMobile.isEmpty ? null : guMobile,
                      address: guAddress.isEmpty ? null : guAddress,
                    );

                    final created = await widget.repo.createUser(gReq);
                    guardianUserId = created.user.userId;
                  } catch (e) {
                    error = 'Could not create guardian for $guEmail. ${friendlyErrorMessage(e)}';
                  }
                }
              } else {
                error = 'Multiple users found for guardian email "$guEmail"';
              }
            } catch (e) {
              error = 'Could not resolve guardian user for "$guEmail". ${friendlyErrorMessage(e)}';
            }
          }
        }

        if (error == null) {
          try {
            // Parse student account fields (acc_number, opening_bal)
            String accNumber = (r['acc_number'] ?? r['account_number'] ?? '')
                .trim();
            double? openingBal;
            final openingBalRaw =
                (r['opening_bal'] ?? r['opening_balance'] ?? '').trim();
            if (openingBalRaw.isNotEmpty) {
              try {
                openingBal = double.parse(openingBalRaw);
              } catch (_) {
                error =
                    'Invalid opening_bal "$openingBalRaw" - must be a number';
              }
            }

            if (error == null) {
              final req = CreateUserRequest(
                email: r['email']!.trim(),
                password: (r['password'] ?? '').isEmpty ? null : r['password'],
                firstName: r['first_name']!.trim(),
                lastName: r['last_name']!.trim(),
                role: role!,
                schoolId: schoolId.isEmpty ? null : schoolId,
                classId: classId.isEmpty ? null : classId,
                mobile: (r['mobile'] ?? '').isEmpty ? null : r['mobile'],
                guardianTypeId: guardianTypeId.isEmpty ? null : guardianTypeId,
                guardianUserId: guardianUserId.isEmpty ? null : guardianUserId,
                address: (r['address'] ?? '').isEmpty ? null : r['address'],
                creditUnionId: creditUnionId.isEmpty ? null : creditUnionId,
                accNumber: accNumber.isEmpty ? null : accNumber,
                openingBal: openingBal,
              );

              await widget.repo.createUser(req);

              results.add(
                _ImportResult(
                  idx: i + 2, // +2 for 1-based + header row
                  row: r,
                  ok: true,
                  error: null,
                ),
              );
            }
          } catch (e) {
            results.add(
              _ImportResult(idx: i + 2, row: r, ok: false, error: friendlyErrorMessage(e)),
            );
          }
        } else {
          results.add(
            _ImportResult(idx: i + 2, row: r, ok: false, error: error),
          );
        }
      }

      if (mounted) {
        setState(() => _done = i + 1);
      }
    }

    if (!mounted) return;
    setState(() {
      _results = results;
      _importing = false;
    });

    final okCount = results.where((r) => r.ok).length;
    final failCount = results.length - okCount;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Import complete: $okCount succeeded, $failCount failed.',
        ),
      ),
    );
  }

  Future<void> _exportFailures() async {
    if (_results.isEmpty) return;
    final failed = _results.where((r) => !r.ok).toList();
    if (failed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No failures to export.')));
      return;
    }

    try {
      // Get all unique column headers from failed rows
      final headers = <String>{};
      for (final f in failed) {
        headers.addAll(f.row.keys);
      }
      final headerList = headers.toList()..sort();
      // Add error column
      headerList.add('import_error');

      // Build CSV rows
      final rows = <List<String>>[
        headerList, // header row
        ...failed.map(
          (f) => [
            ...headerList
                .where((h) => h != 'import_error')
                .map((h) => f.row[h] ?? ''),
            f.error ?? '',
          ],
        ),
      ];

      final csvString = Csv().encode(rows);
      final fileName =
          'import_failures_${DateTime.now().millisecondsSinceEpoch}.csv';

      final success = await downloadOrShareCsv(csvString, fileName);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${failed.length} failed rows')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export failures')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Export failed.', e))));
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      // Define all possible columns in logical order
      final headers = [
        'email',
        'password',
        'first_name',
        'last_name',
        'role',
        'send_invite',
        'mobile',
        'address',
        'school_id',
        'school',
        'class_id',
        'class',
        'guardian_type_id',
        'guardian_type',
        'guardian_user_id',
        'guardian_user_email',
        'guardian_first_name',
        'guardian_last_name',
        'guardian_mobile',
        'guardian_address',
        'credit_union_id',
        'credit_union',
        'acc_number',
        'opening_bal',
      ];

      // Create example rows for each role.
      // password: leave blank to have Supabase send a magic-link invite instead.
      // school/class/guardian_type/credit_union: supply the NAME (not the id);
      //   the importer resolves names to ids automatically.
      // guardian_user_email: if the guardian doesn't exist yet, also supply
      //   guardian_first_name / guardian_last_name / guardian_mobile / guardian_address
      //   and the importer will create the guardian account automatically.
      final rows = <List<String>>[
        headers, // header row

        // ── STUDENT ────────────────────────────────────────────────────────
        // Required: email, first_name, last_name, role, school, class,
        //           guardian_type, guardian_user_email
        // Optional: password, mobile, acc_number, opening_bal
        [
          'anika.ramsay@students.lccu.edu', // email
          '', // password (blank → invite email sent)
          'Anika', // first_name
          'Ramsay', // last_name
          'student', // role
          'true', // send_invite
          '', // mobile
          '', // address
          '', // school_id (leave blank — use school name)
          'Sunshine Primary School', // school
          '', // class_id (leave blank — use class name)
          'Grade 4B', // class
          '', // guardian_type_id
          'Mother', // guardian_type
          '', // guardian_user_id
          'diana.ramsay@email.com', // guardian_user_email (existing guardian)
          '', // guardian_first_name (only needed if creating guardian)
          '', // guardian_last_name
          '', // guardian_mobile
          '', // guardian_address
          '', // credit_union_id
          '', // credit_union
          'STU-2024-001', // acc_number
          '25.00', // opening_bal
        ],

        // ── STUDENT (new guardian created inline) ─────────────────────────
        [
          'marcus.pierre@students.lccu.edu',
          '',
          'Marcus',
          'Pierre',
          'student',
          'true',
          '',
          '',
          '',
          'Sunshine Primary School',
          '',
          'Grade 5A',
          '',
          'Father',
          '', // guardian_user_id — blank, will look up by email
          'tony.pierre@email.com', // guardian email — not yet in system
          'Tony', // guardian_first_name — triggers auto-create
          'Pierre', // guardian_last_name
          '868-555-0121', // guardian_mobile
          '45 Hibiscus Drive, San Fernando', // guardian_address
          '',
          '',
          'STU-2024-002',
          '0.00',
        ],

        // ── GUARDIAN ───────────────────────────────────────────────────────
        // Required: email, first_name, last_name, role, guardian_type
        // Optional: password, mobile, address
        [
          'diana.ramsay@email.com',
          '',
          'Diana',
          'Ramsay',
          'guardian',
          'true',
          '868-555-0110',
          '12 Poinsettia Lane, Couva',
          '',
          '',
          '',
          '',
          '',
          '',
          'Mother',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ],

        // ── TEACHER ────────────────────────────────────────────────────────
        // Required: email, first_name, last_name, role, school
        // Optional: password, mobile, address, class
        [
          'sandra.ali@sunshine.edu',
          '',
          'Sandra',
          'Ali',
          'teacher',
          'true',
          '868-555-0201',
          '7 Jacaranda Ave, Chaguanas',
          '',
          '',
          'Sunshine Primary School',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ],

        // ── PRINCIPAL ──────────────────────────────────────────────────────
        // Required: email, first_name, last_name, role, school
        // Optional: password, mobile, address
        [
          'victor.charles@sunshine.edu',
          '',
          'Victor',
          'Charles',
          'principal',
          'true',
          '868-555-0301',
          '1 School Road, Chaguanas',
          '',
          '',
          'Sunshine Primary School',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ],

        // ── TELLER ─────────────────────────────────────────────────────────
        // Required: email, first_name, last_name, role, credit_union
        // Optional: password, mobile, address
        [
          'kezia.james@lccu.org',
          '',
          'Kezia',
          'James',
          'teller',
          'true',
          '868-555-0401',
          '10 Independence Square, Port of Spain',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'LCCU Main Branch',
          '',
          '',
        ],

        // ── ADMIN ───────────────────────────────────────────────────────────
        // Required: email, first_name, last_name, role
        // Optional: password, mobile
        [
          'nadine.baptiste@lccu.org',
          '',
          'Nadine',
          'Baptiste',
          'admin',
          'true',
          '868-555-0501',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ],
      ];

      final csvString = Csv().encode(rows);
      final fileName = 'user_import_template.csv';

      final success = await downloadOrShareCsv(csvString, fileName);
      if (!mounted) return;

      if (success) {
        final msg = kIsWeb
            ? 'Template download started — check your browser downloads.'
            : 'Template downloaded successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download template')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Template download failed.', e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final importing = _importing;
    final parsed = _rows.isNotEmpty;
    final done = _done;
    final total = _rows.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Users'),
        actions: [
          IconButton(
            tooltip: 'Download CSV template',
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _HelpBox(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: importing ? null : _downloadTemplate,
                icon: const Icon(Icons.download),
                label: const Text('Download Template CSV'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: importing ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose CSV'),
                ),
                const SizedBox(width: 8),
                if (_parsing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const Spacer(),
                if (parsed)
                  FilledButton.icon(
                    onPressed: importing ? null : _startImport,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Import'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (importing) ...[
              LinearProgressIndicator(value: total == 0 ? null : done / total),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Importing $done / $total...'),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _results.isEmpty
                  ? _PreviewTable(rows: _rows)
                  : _ResultsTable(results: _results),
            ),
            const SizedBox(height: 12),
            if (_results.isNotEmpty)
              Row(
                children: [
                  Text(
                    'Completed: ${_results.where((r) => r.ok).length} ok, '
                    '${_results.where((r) => !r.ok).length} failed',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _exportFailures,
                    icon: const Icon(Icons.error_outline),
                    label: const Text('Export Failures'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final List<Map<String, String>> rows;
  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text('No CSV loaded. Choose a file to begin.'),
      );
    }

    // Build a small preview of up to 200 rows and common columns
    final cols = <String>{
      'email',
      'first_name',
      'last_name',
      'role',
      'school_id',
      'class_id',
    };
    final headers = cols.where((c) => rows.first.containsKey(c)).toList();

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('#')),
            ...headers.map((h) => DataColumn(label: Text(h))),
          ],
          rows: [
            for (int i = 0; i < rows.length && i < 200; i++)
              DataRow(
                cells: [
                  DataCell(Text('${i + 2}')), // row number in original CSV
                  ...headers.map((h) => DataCell(Text(rows[i][h] ?? ''))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultsTable extends StatelessWidget {
  final List<_ImportResult> results;
  const _ResultsTable({required this.results});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('email')),
            DataColumn(label: Text('first_name')),
            DataColumn(label: Text('last_name')),
            DataColumn(label: Text('role')),
            DataColumn(label: Text('status')),
            DataColumn(label: Text('error')),
          ],
          rows: results
              .map(
                (r) => DataRow(
                  cells: [
                    DataCell(Text(r.idx.toString())),
                    DataCell(Text(r.row['email'] ?? '')),
                    DataCell(Text(r.row['first_name'] ?? '')),
                    DataCell(Text(r.row['last_name'] ?? '')),
                    DataCell(Text(r.row['role'] ?? '')),
                    DataCell(Text(r.ok ? 'OK' : 'FAILED')),
                    DataCell(Text(r.error ?? '')),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _HelpBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tip: Download the CSV template first, fill in the required columns, then choose the completed CSV file.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportResult {
  final int idx; // CSV row number (1-based incl header)
  final Map<String, String> row;
  final bool ok;
  final String? error;

  _ImportResult({
    required this.idx,
    required this.row,
    required this.ok,
    required this.error,
  });
}
