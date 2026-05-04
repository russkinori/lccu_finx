import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/core/utils/download_helper.dart';
import 'package:lccu_finx/app/supabase_config.dart';
import 'package:lccu_finx/features/teller/viewmodel/teller_vm.dart';
import 'package:lccu_finx/features/teller/data/teller_repo.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/app/app_utils.dart';
import 'package:lccu_finx/core/widgets/friendly_error.dart';

class TellerReportScreen extends StatefulWidget {
  const TellerReportScreen({super.key});

  @override
  State<TellerReportScreen> createState() => _TellerReportScreenState();
}

class _TellerReportScreenState extends State<TellerReportScreen> {
  String? _displayName;

  String _scope = 'all';
  String? _selectedSchoolId;

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  String? _error;

  _ReportAllSchools? _allSchools;
  _ReportSingleSchool? _singleSchool;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWelcome();
      final vm = TellerScope.of(context, listen: false);
      if (_selectedSchoolId == null && vm.schools.isNotEmpty) {
        setState(() => _selectedSchoolId = vm.schools.first.schoolId);
      }
    });
  }

  Future<void> _loadWelcome() async {
    try {
      final name = await CommonRepository(
        supabase,
      ).getCurrentUserDisplayName(fallback: '');
      if (!mounted) return;
      setState(() => _displayName = name);
    } catch (_) {}
  }

  Future<void> _generate() async {
    if (_loading) return;

    final vm = TellerScope.of(context, listen: false);
    final repo = vm.repo;

    if (_scope == 'school' &&
        (_selectedSchoolId == null || _selectedSchoolId!.isEmpty)) {
      setState(() => _error = 'Select a school');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _allSchools = null;
      _singleSchool = null;
    });

    try {
      final from = DateTime(
        _fromDate.year,
        _fromDate.month,
        _fromDate.day,
      );
      final to = DateTime(
        _toDate.year,
        _toDate.month,
        _toDate.day,
        23,
        59,
        59,
      );

      if (_scope == 'all') {
        final deposits = await repo.fetchCreditUnionDeposits(
          from: from,
          to: to,
          limit: 5000,
        );
        final payouts = await repo.fetchSchoolPayouts(
          from: from,
          to: to,
          limit: 5000,
        );

        final teacherNameBySchool = await _teacherNamesForSchools(
          repo,
          vm.schools.map((s) => s.schoolId).toList(),
        );

        final report = _computeAllSchoolsReport(
          deposits: deposits,
          payouts: payouts,
          schools: vm.schools,
          teacherNameBySchool: teacherNameBySchool,
        );

        if (!mounted) return;
        setState(() {
          _allSchools = report;
          _loading = false;
        });
        return;
      }

      final schoolId = _selectedSchoolId!;
      final deposits = await repo.fetchCreditUnionDeposits(
        from: from,
        to: to,
        schoolId: schoolId,
        limit: 5000,
      );
      final payouts = await repo.fetchSchoolPayouts(
        from: from,
        to: to,
        schoolId: schoolId,
        limit: 5000,
      );

      final teacherRows = await repo.getTeachersForSchool(schoolId);
      final teacherNames = {
        for (final t in teacherRows) t.id: t.name,
      };

      final report = _computeSingleSchoolReport(
        schoolId: schoolId,
        deposits: deposits,
        payouts: payouts,
        schools: vm.schools,
        teacherNames: teacherNames,
      );

      if (!mounted) return;
      setState(() {
        _singleSchool = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyActionError('Failed to generate report.', e);
        _loading = false;
      });
    }
  }

  Future<Map<String, Map<String, String>>> _teacherNamesForSchools(
    TellerRepository repo,
    List<String> schoolIds,
  ) async {
    final out = <String, Map<String, String>>{};
    for (final schoolId in schoolIds) {
      try {
        final teachers = await repo.getTeachersForSchool(schoolId);
        out[schoolId] = {for (final t in teachers) t.id: t.name};
      } catch (_) {
        out[schoolId] = {};
      }
    }
    return out;
  }

  _ReportAllSchools _computeAllSchoolsReport({
    required List<CuDepositRow> deposits,
    required List<CuPayoutRow> payouts,
    required List<TellerSchoolRow> schools,
    required Map<String, Map<String, String>> teacherNameBySchool,
  }) {
    final bySchool = <String, _SchoolAgg>{};
    final schoolNameById = {for (final s in schools) s.schoolId: s.schoolName};
    final allTransactions = <_TransactionLogEntry>[];

    for (final d in deposits) {
      final agg = bySchool.putIfAbsent(d.schoolId, () => _SchoolAgg());
      agg.deposits += d.amount;
      agg.transactionCount += 1;
      if (d.discrepancy != 0) {
        agg.discrepancyTotal += d.discrepancy;
        agg.discrepancyCount += 1;
      }

      final teacherName = d.teacherId.isNotEmpty
          ? (teacherNameBySchool[d.schoolId]?[d.teacherId] ?? 'Teacher')
          : 'Teacher';

      if (d.teacherId.isNotEmpty) {
        final t = agg.byActor.putIfAbsent(
          'teacher:${d.teacherId}',
          () => _ActorAgg(name: teacherName),
        );
        t.deposits += d.amount;
        t.transactionCount += 1;
        t.lastActivity = d.postedAt;
        if (d.discrepancy != 0) {
          t.discrepancyTotal += d.discrepancy;
          t.discrepancyCount += 1;
        }
      }

      allTransactions.add(_TransactionLogEntry(
        date: d.postedAt,
        schoolName: schoolNameById[d.schoolId] ?? 'School',
        type: 'Deposit',
        submittedBy: teacherName,
        amount: d.amount,
        discrepancy: d.discrepancy,
        status: d.status,
        notes: d.notes,
      ));
    }

    for (final p in payouts) {
      final agg = bySchool.putIfAbsent(p.schoolId, () => _SchoolAgg());
      agg.withdrawals += p.amount;
      agg.transactionCount += 1;

      final actorKey = _payoutActorKey(p);
      final actorName = _payoutActorName(
        payout: p,
        teacherNames: teacherNameBySchool[p.schoolId] ?? const {},
      );

      final a = agg.byActor.putIfAbsent(
        actorKey,
        () => _ActorAgg(name: actorName),
      );
      a.withdrawals += p.amount;
      a.transactionCount += 1;
      a.lastActivity = p.postedAt;

      allTransactions.add(_TransactionLogEntry(
        date: p.postedAt,
        schoolName: schoolNameById[p.schoolId] ?? 'School',
        type: 'Withdrawal',
        submittedBy: actorName,
        amount: p.amount,
        notes: p.note,
      ));
    }

    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    final rows = <_SchoolRowReport>[];
    for (final school in schools) {
      final agg = bySchool[school.schoolId];

      String topDepositor = '-';
      double topDepositorDeposits = 0.0;

      if (agg != null && agg.byActor.isNotEmpty) {
        _ActorAgg? best;
        for (final actor in agg.byActor.values) {
          if (actor.deposits <= 0) continue;
          if (best == null || actor.deposits > best.deposits) {
            best = actor;
          }
        }
        if (best != null) {
          topDepositor = best.name;
          topDepositorDeposits = best.deposits;
        }
      }

      rows.add(
        _SchoolRowReport(
          schoolId: school.schoolId,
          schoolName: school.schoolName,
          balance: school.accountBalance,
          deposits: agg?.deposits ?? 0.0,
          withdrawals: agg?.withdrawals ?? 0.0,
          transactionCount: agg?.transactionCount ?? 0,
          topDepositorName: topDepositor,
          topDepositorDeposits: topDepositorDeposits,
          discrepancyTotal: agg?.discrepancyTotal ?? 0.0,
          discrepancyCount: agg?.discrepancyCount ?? 0,
        ),
      );
    }

    rows.sort((a, b) => a.schoolName.compareTo(b.schoolName));

    double totalBalance = 0.0;
    double totalDeposits = 0.0;
    double totalWithdrawals = 0.0;
    int totalTransactions = 0;
    double totalDiscrepancy = 0.0;
    int totalDiscrepancyCount = 0;

    for (final r in rows) {
      totalBalance += r.balance;
      totalDeposits += r.deposits;
      totalWithdrawals += r.withdrawals;
      totalTransactions += r.transactionCount;
      totalDiscrepancy += r.discrepancyTotal;
      totalDiscrepancyCount += r.discrepancyCount;
    }

    return _ReportAllSchools(
      rows: rows,
      totalBalance: totalBalance,
      totalDeposits: totalDeposits,
      totalWithdrawals: totalWithdrawals,
      totalTransactions: totalTransactions,
      totalDiscrepancy: totalDiscrepancy,
      totalDiscrepancyCount: totalDiscrepancyCount,
      transactions: allTransactions,
    );
  }

  _ReportSingleSchool _computeSingleSchoolReport({
    required String schoolId,
    required List<CuDepositRow> deposits,
    required List<CuPayoutRow> payouts,
    required List<TellerSchoolRow> schools,
    required Map<String, String> teacherNames,
  }) {
    final school = schools.cast<TellerSchoolRow?>().firstWhere(
      (s) => s?.schoolId == schoolId,
      orElse: () => null,
    );

    final schoolName = school?.schoolName ?? 'School';
    final balance = school?.accountBalance ?? 0.0;

    double totalDeposits = 0.0;
    double totalWithdrawals = 0.0;
    int transactionCount = 0;
    double discrepancyTotal = 0.0;
    int discrepancyCount = 0;
    final txLog = <_TransactionLogEntry>[];

    final byActor = <String, _ActorAgg>{};

    for (final d in deposits) {
      totalDeposits += d.amount;
      transactionCount += 1;
      if (d.discrepancy != 0) {
        discrepancyTotal += d.discrepancy;
        discrepancyCount += 1;
      }

      final actorName = teacherNames[d.teacherId] ?? 'Teacher';
      final actor = byActor.putIfAbsent(
        'teacher:${d.teacherId}',
        () => _ActorAgg(name: actorName),
      );
      actor.deposits += d.amount;
      actor.transactionCount += 1;
      actor.lastActivity = d.postedAt;
      if (d.discrepancy != 0) {
        actor.discrepancyTotal += d.discrepancy;
        actor.discrepancyCount += 1;
      }

      txLog.add(_TransactionLogEntry(
        date: d.postedAt,
        schoolName: schoolName,
        type: 'Deposit',
        submittedBy: actorName,
        amount: d.amount,
        discrepancy: d.discrepancy,
        status: d.status,
        notes: d.notes,
      ));
    }

    for (final p in payouts) {
      totalWithdrawals += p.amount;
      transactionCount += 1;

      final key = _payoutActorKey(p);
      final name = _payoutActorName(
        payout: p,
        teacherNames: teacherNames,
      );

      final actor = byActor.putIfAbsent(
        key,
        () => _ActorAgg(name: name),
      );
      actor.withdrawals += p.amount;
      actor.transactionCount += 1;
      actor.lastActivity = p.postedAt;

      txLog.add(_TransactionLogEntry(
        date: p.postedAt,
        schoolName: schoolName,
        type: 'Withdrawal',
        submittedBy: name,
        amount: p.amount,
        notes: p.note,
      ));
    }

    txLog.sort((a, b) => b.date.compareTo(a.date));

    _ActorAgg? best;
    for (final actor in byActor.values) {
      if (actor.deposits <= 0) continue;
      if (best == null || actor.deposits > best.deposits) {
        best = actor;
      }
    }

    final actors = byActor.values.toList()
      ..sort((a, b) => b.deposits.compareTo(a.deposits));

    return _ReportSingleSchool(
      schoolId: schoolId,
      schoolName: schoolName,
      balance: balance,
      deposits: totalDeposits,
      withdrawals: totalWithdrawals,
      transactionCount: transactionCount,
      topDepositorName: best?.name ?? '-',
      topDepositorDeposits: best?.deposits ?? 0.0,
      actors: actors,
      discrepancyTotal: discrepancyTotal,
      discrepancyCount: discrepancyCount,
      transactions: txLog,
    );
  }

  String _payoutActorKey(CuPayoutRow payout) {
    if ((payout.requestedByTeacherId ?? '').isNotEmpty) {
      return 'teacher:${payout.requestedByTeacherId}';
    }
    if ((payout.requestedByPrincipalId ?? '').isNotEmpty) {
      return 'principal:${payout.requestedByPrincipalId}';
    }
    return 'unknown';
  }

  String _payoutActorName({
    required CuPayoutRow payout,
    required Map<String, String> teacherNames,
  }) {
    final teacherId = payout.requestedByTeacherId;
    if (teacherId != null && teacherId.isNotEmpty) {
      return teacherNames[teacherId] ?? 'Teacher';
    }

    final principalId = payout.requestedByPrincipalId;
    if (principalId != null && principalId.isNotEmpty) {
      return 'Principal Request';
    }

    return 'Withdrawal Request';
  }

  String _generateAllSchoolsCsv(_ReportAllSchools report) {
    final buffer = StringBuffer();
    buffer.writeln(
      'School,Balance,Deposits,Withdrawals,Net,Discrepancy,Discrepancy Count,Top Depositor,Top Depositor Amount',
    );

    for (final r in report.rows) {
      final net = r.deposits - r.withdrawals;
      buffer.write('"${r.schoolName}",');
      buffer.write('${r.balance},');
      buffer.write('${r.deposits},');
      buffer.write('${r.withdrawals},');
      buffer.write('$net,');
      buffer.write('${r.discrepancyTotal},');
      buffer.write('${r.discrepancyCount},');
      buffer.write('"${r.topDepositorName}",');
      buffer.writeln('${r.topDepositorDeposits}');
    }

    buffer.writeln();
    buffer.writeln('Summary');
    buffer.writeln('Total Schools,${report.rows.length}');
    buffer.writeln('Total Balance,${report.totalBalance}');
    buffer.writeln('Total Deposits,${report.totalDeposits}');
    buffer.writeln('Total Withdrawals,${report.totalWithdrawals}');
    buffer.writeln(
      'Total Net,${report.totalDeposits - report.totalWithdrawals}',
    );
    buffer.writeln('Total Discrepancy,${report.totalDiscrepancy}');
    buffer.writeln('Total Discrepancy Count,${report.totalDiscrepancyCount}');

    if (report.transactions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Transaction Log');
      buffer.writeln('Date,School,Type,Submitted By,Amount,Discrepancy,Status,Notes');
      for (final t in report.transactions) {
        final date = t.date.toIso8601String().split('T').first;
        buffer.write('$date,');
        buffer.write('"${t.schoolName}",');
        buffer.write('${t.type},');
        buffer.write('"${t.submittedBy}",');
        buffer.write('${t.amount},');
        buffer.write('${t.discrepancy},');
        buffer.write('"${t.status}",');
        buffer.writeln('"${t.notes.replaceAll('"', "'")}"');
      }
    }

    return buffer.toString();
  }

  String _generateSingleSchoolCsv(_ReportSingleSchool report) {
    final buffer = StringBuffer();
    final net = report.deposits - report.withdrawals;

    buffer.writeln('School Report: ${report.schoolName}');
    buffer.writeln();
    buffer.writeln('Summary');
    buffer.writeln('Balance,${report.balance}');
    buffer.writeln('Deposits,${report.deposits}');
    buffer.writeln('Withdrawals,${report.withdrawals}');
    buffer.writeln('Net,$net');
    buffer.writeln('Total Discrepancy,${report.discrepancyTotal}');
    buffer.writeln('Discrepancy Count,${report.discrepancyCount}');
    buffer.writeln('Top Depositor,${report.topDepositorName}');
    buffer.writeln('Top Depositor Amount,${report.topDepositorDeposits}');
    buffer.writeln();
    buffer.writeln('Staff Activity');
    buffer.writeln('Actor,Deposits,Withdrawals,Transactions,Discrepancy,Discrepancy Count,Last Activity');

    for (final a in report.actors) {
      final last = a.lastActivity == null
          ? '-'
          : a.lastActivity!.toIso8601String().split('T').first;
      buffer.write('"${a.name}",');
      buffer.write('${a.deposits},');
      buffer.write('${a.withdrawals},');
      buffer.write('${a.transactionCount},');
      buffer.write('${a.discrepancyTotal},');
      buffer.write('${a.discrepancyCount},');
      buffer.writeln(last);
    }

    if (report.transactions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Transaction Log');
      buffer.writeln('Date,Type,Submitted By,Amount,Discrepancy,Status,Notes');
      for (final t in report.transactions) {
        final date = t.date.toIso8601String().split('T').first;
        buffer.write('$date,');
        buffer.write('${t.type},');
        buffer.write('"${t.submittedBy}",');
        buffer.write('${t.amount},');
        buffer.write('${t.discrepancy},');
        buffer.write('"${t.status}",');
        buffer.writeln('"${t.notes.replaceAll('"', "'")}"');
      }
    }

    return buffer.toString();
  }

  Future<void> _exportCsv() async {
    String csvContent;
    String fileName;

    if (_allSchools != null) {
      csvContent = _generateAllSchoolsCsv(_allSchools!);
      fileName =
          'all_schools_report_${DateTime.now().toIso8601String().split('T').first}.csv';
    } else if (_singleSchool != null) {
      csvContent = _generateSingleSchoolCsv(_singleSchool!);
      fileName =
          '${_singleSchool!.schoolName.replaceAll(' ', '_')}_report_${DateTime.now().toIso8601String().split('T').first}.csv';
    } else {
      return;
    }

    final success = await downloadOrShareCsv(csvContent, fileName);
    if (!mounted) return;

    if (success) {
      final msg = kIsWeb
          ? 'Report export started — check your browser downloads.'
          : 'Report exported successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = TellerScope.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 600;
    final isMobileDevice =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final titleSize = isNarrow ? 20.0 : 24.0;
    final welcomeSize = isNarrow ? 12.0 : 14.0;
    final nameSize = isNarrow ? 16.0 : 18.0;
    final edgePadding = isNarrow ? 8.0 : 12.0;

    final schools = vm.schools;
    if (_selectedSchoolId == null && schools.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectedSchoolId == null) {
          setState(() => _selectedSchoolId = schools.first.schoolId);
        }
      });
    }

    return Padding(
      padding: EdgeInsets.all(edgePadding),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Text(
              'Transaction Report',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((_displayName ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: 'Welcome ',
                      style: TextStyle(
                        fontSize: welcomeSize,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: _displayName!,
                      style: TextStyle(
                        fontSize: nameSize,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            _ControlsCard(
              isNarrow: isNarrow,
              scope: _scope,
              onScopeChanged: (v) {
                if (v == null) return;
                setState(() {
                  _scope = v;
                  _error = null;
                  _allSchools = null;
                  _singleSchool = null;
                });
              },
              schools: schools,
              selectedSchoolId: _selectedSchoolId,
              onSchoolChanged: (v) {
                setState(() {
                  _selectedSchoolId = v;
                  _error = null;
                  _allSchools = null;
                  _singleSchool = null;
                });
              },
              fromDate: _fromDate,
              toDate: _toDate,
              onPickFrom: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fromDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked == null) return;
                setState(() {
                  _fromDate = picked;
                  _allSchools = null;
                  _singleSchool = null;
                });
              },
              onPickTo: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _toDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked == null) return;
                setState(() {
                  _toDate = picked;
                  _allSchools = null;
                  _singleSchool = null;
                });
              },
              loading: _loading,
              onGenerate: _generate,
            ),

            if ((_error ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 12),

            if (_allSchools != null || _singleSchool != null) ...[
              Center(
                child: ElevatedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_allSchools != null)
              _buildAllSchoolsReport(isNarrow, isMobileDevice, _allSchools!),
            if (_singleSchool != null)
              _buildSingleSchoolReport(
                isNarrow,
                isMobileDevice,
                _singleSchool!,
              ),

            if (!_loading && _allSchools == null && _singleSchool == null) ...[
              const SizedBox(height: 18),
              Text(
                'Generate a teller-safe report to see balances, posted deposits, recorded withdrawals, and staff activity.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: isNarrow ? 12 : 14,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllSchoolsReport(
    bool isNarrow,
    bool isMobileDevice,
    _ReportAllSchools report,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryStrip(
          isNarrow: isNarrow,
          leftTitle: 'Schools',
          leftValue: '${report.rows.length}',
          midTitle: 'Total Deposits',
          midValue: formatMoney(report.totalDeposits),
          rightTitle: 'Total Withdrawals',
          rightValue: formatMoney(report.totalWithdrawals),
        ),
        const SizedBox(height: 12),
        if (isMobileDevice)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: report.rows.map((r) {
              final net = r.deposits - r.withdrawals;
              return Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(
                    color: AppColors.primaryBlue,
                    width: 1,
                  ),
                ),
                child: ExpansionTile(
                  title: Text(r.schoolName),
                  subtitle: Text(
                    formatMoney(net),
                    style: TextStyle(
                      color: net >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Balance: ${formatMoney(r.balance)}'),
                          const SizedBox(height: 6),
                          Text('Deposits: ${formatMoney(r.deposits)}'),
                          const SizedBox(height: 6),
                          Text('Withdrawals: ${formatMoney(r.withdrawals)}'),
                          const SizedBox(height: 6),
                          if (r.discrepancyCount > 0) ...[                            Text(
                              'Discrepancy: ${formatMoney(r.discrepancyTotal)} (${r.discrepancyCount})',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            'Top Depositor: ${r.topDepositorName == '-' ? '-' : '${r.topDepositorName} (${formatMoney(r.topDepositorDeposits)})'}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('School')),
                DataColumn(label: Text('Balance'), numeric: true),
                DataColumn(label: Text('Deposits'), numeric: true),
                DataColumn(label: Text('Withdrawals'), numeric: true),
                DataColumn(label: Text('Net'), numeric: true),
                DataColumn(label: Text('Discrepancy'), numeric: true),
                DataColumn(label: Text('Top Depositor')),
              ],
              rows: report.rows.map((r) {
                final net = r.deposits - r.withdrawals;
                return DataRow(
                  cells: [
                    DataCell(Text(r.schoolName)),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(formatMoney(r.balance)),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(formatMoney(r.deposits)),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(formatMoney(r.withdrawals)),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatMoney(net),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: net >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          r.discrepancyCount == 0
                              ? '-'
                              : formatMoney(r.discrepancyTotal),
                          style: TextStyle(
                            color: r.discrepancyCount > 0
                                ? Colors.orange.shade700
                                : null,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        r.topDepositorName == '-'
                            ? '-'
                            : '${r.topDepositorName} (${formatMoney(r.topDepositorDeposits)})',
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        if (report.totalDiscrepancyCount > 0) ...[
          const SizedBox(height: 16),
          Text(
            'Discrepancy Summary',
            style: TextStyle(
              fontSize: isNarrow ? 14 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Card(
            elevation: 1,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.orange.shade300, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Discrepancy',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        formatMoney(report.totalDiscrepancy),
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions with Discrepancy',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                      Text(
                        '${report.totalDiscrepancyCount}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.orange.shade50,
                      ),
                      columns: const [
                        DataColumn(label: Text('School')),
                        DataColumn(
                          label: Text('Discrepancy'),
                          numeric: true,
                        ),
                        DataColumn(label: Text('Count'), numeric: true),
                      ],
                      rows: report.rows
                          .where((r) => r.discrepancyCount > 0)
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text(r.schoolName)),
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      formatMoney(r.discrepancyTotal),
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text('${r.discrepancyCount}'),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (report.transactions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTransactionLog(
            isNarrow: isNarrow,
            isMobileDevice: isMobileDevice,
            transactions: report.transactions,
            showSchool: true,
          ),
        ],
      ],
    );
  }

  Widget _buildSingleSchoolReport(
    bool isNarrow,
    bool isMobileDevice,
    _ReportSingleSchool report,
  ) {
    final net = report.deposits - report.withdrawals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.primaryBlue, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  report.schoolName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isNarrow ? 18 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatMoney(report.balance),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Deposits',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatMoney(report.deposits),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Withdrawals',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatMoney(report.withdrawals),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatMoney(net),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: net >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                if (report.discrepancyCount > 0) ...[                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discrepancy',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${formatMoney(report.discrepancyTotal)} (${report.discrepancyCount})',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Top Depositor',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        report.topDepositorName == '-'
                            ? '-'
                            : '${report.topDepositorName}\n${formatMoney(report.topDepositorDeposits)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Staff Activity',
          style: TextStyle(
            fontSize: isNarrow ? 14 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (report.actors.isEmpty)
          const Text('No staff activity found for this period.')
        else if (isMobileDevice)
          Column(
            children: report.actors.map((a) {
              final last = a.lastActivity == null
                  ? '-'
                  : a.lastActivity!.toIso8601String().split('T').first;
              return Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(
                    color: AppColors.primaryBlue,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Deposits',
                            style: TextStyle(color: Colors.black54),
                          ),
                          Text(
                            formatMoney(a.deposits),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Withdrawals',
                            style: TextStyle(color: Colors.black54),
                          ),
                          Text(
                            formatMoney(a.withdrawals),
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transactions',
                            style: TextStyle(color: Colors.black54),
                          ),
                          Text(
                            '${a.transactionCount}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Last Activity',
                            style: TextStyle(color: Colors.black54),
                          ),
                          Text(
                            last,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                      if (a.discrepancyCount > 0) ...[                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discrepancy',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                            Text(
                              '${formatMoney(a.discrepancyTotal)} (${a.discrepancyCount})',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Actor')),
                DataColumn(label: Text('Deposits'), numeric: true),
                DataColumn(label: Text('Withdrawals'), numeric: true),
                DataColumn(label: Text('Transactions'), numeric: true),
                DataColumn(label: Text('Discrepancy'), numeric: true),
                DataColumn(label: Text('Last Activity')),
              ],
              rows: report.actors.map((a) {
                final last = a.lastActivity == null
                    ? '-'
                    : a.lastActivity!.toIso8601String().split('T').first;
                return DataRow(
                  cells: [
                    DataCell(Text(a.name)),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(formatMoney(a.deposits)),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(formatMoney(a.withdrawals)),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('${a.transactionCount}'),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          a.discrepancyCount == 0
                              ? '-'
                              : formatMoney(a.discrepancyTotal),
                          style: TextStyle(
                            color: a.discrepancyCount > 0
                                ? Colors.orange.shade700
                                : null,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(last)),
                  ],
                );
              }).toList(),
            ),
          ),
        if (report.transactions.isNotEmpty) ...[          const SizedBox(height: 16),
          _buildTransactionLog(
            isNarrow: isNarrow,
            isMobileDevice: isMobileDevice,
            transactions: report.transactions,
            showSchool: false,
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionLog({
    required bool isNarrow,
    required bool isMobileDevice,
    required List<_TransactionLogEntry> transactions,
    required bool showSchool,
  }) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryBlue, width: 1),
      ),
      child: ExpansionTile(
        title: Text(
          'Transaction Log (${transactions.length})',
          style: TextStyle(
            fontSize: isNarrow ? 14 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'All teller-confirmed deposits and withdrawals',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: isMobileDevice
                ? Column(
                    children: transactions.map((t) {
                      final date =
                          t.date.toIso8601String().split('T').first;
                      return Card(
                        elevation: 0,
                        color: Colors.grey.shade50,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: t.type == 'Deposit'
                                ? Colors.blue.shade200
                                : Colors.purple.shade200,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.type == 'Deposit'
                                          ? Colors.blue.shade50
                                          : Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      t.type,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: t.type == 'Deposit'
                                            ? Colors.blue.shade700
                                            : Colors.purple.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (showSchool) ...[
                                Text(
                                  t.schoolName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    t.submittedBy,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    formatMoney(t.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              if (t.discrepancy != 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Discrepancy: ${formatMoney(t.discrepancy)}',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (t.status.isNotEmpty &&
                                  t.status != 'confirmed') ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Status: ${t.status}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                              if (t.notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  t.notes,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      columns: [
                        const DataColumn(label: Text('Date')),
                        if (showSchool)
                          const DataColumn(label: Text('School')),
                        const DataColumn(label: Text('Type')),
                        const DataColumn(label: Text('Submitted By')),
                        const DataColumn(
                          label: Text('Amount'),
                          numeric: true,
                        ),
                        const DataColumn(
                          label: Text('Discrepancy'),
                          numeric: true,
                        ),
                        const DataColumn(label: Text('Status')),
                        const DataColumn(label: Text('Notes')),
                      ],
                      rows: transactions.map((t) {
                        final date =
                            t.date.toIso8601String().split('T').first;
                        return DataRow(
                          cells: [
                            DataCell(Text(date)),
                            if (showSchool) DataCell(Text(t.schoolName)),
                            DataCell(
                              Text(
                                t.type,
                                style: TextStyle(
                                  color: t.type == 'Deposit'
                                      ? Colors.blue.shade700
                                      : Colors.purple.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DataCell(Text(t.submittedBy)),
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(formatMoney(t.amount)),
                              ),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  t.discrepancy == 0
                                      ? '-'
                                      : formatMoney(t.discrepancy),
                                  style: TextStyle(
                                    color: t.discrepancy != 0
                                        ? Colors.orange.shade700
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(t.status)),
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  t.notes,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({
    required this.isNarrow,
    required this.scope,
    required this.onScopeChanged,
    required this.schools,
    required this.selectedSchoolId,
    required this.onSchoolChanged,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.loading,
    required this.onGenerate,
  });

  final bool isNarrow;
  final String scope;
  final ValueChanged<String?> onScopeChanged;
  final List<dynamic> schools;
  final String? selectedSchoolId;
  final ValueChanged<String?> onSchoolChanged;
  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final bool loading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryBlue, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isNarrow ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                initialValue: scope,
                decoration: const InputDecoration(labelText: 'Scope'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Schools')),
                  DropdownMenuItem(
                    value: 'school',
                    child: Text('Single School'),
                  ),
                ],
                onChanged: loading ? null : onScopeChanged,
              ),
            ),
            if (scope == 'school')
              SizedBox(
                width: isNarrow ? double.infinity : 320,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSchoolId,
                  decoration: const InputDecoration(labelText: 'School'),
                  items: schools
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.schoolId as String,
                          child: Text(s.schoolName as String),
                        ),
                      )
                      .toList(),
                  onChanged: loading ? null : onSchoolChanged,
                ),
              ),
            _DateChip(
              label: 'From',
              date: fromDate,
              onTap: loading ? null : onPickFrom,
            ),
            _DateChip(
              label: 'To',
              date: toDate,
              onTap: loading ? null : onPickTo,
            ),
            ElevatedButton(
              onPressed: loading ? null : onGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(loading ? 'Generating…' : 'Generate'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      child: Chip(label: Text('$label: $text')),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.isNarrow,
    required this.leftTitle,
    required this.leftValue,
    required this.midTitle,
    required this.midValue,
    required this.rightTitle,
    required this.rightValue,
  });

  final bool isNarrow;
  final String leftTitle;
  final String leftValue;
  final String midTitle;
  final String midValue;
  final String rightTitle;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    final styleTitle = TextStyle(
      fontSize: isNarrow ? 11 : 12,
      color: Colors.black54,
      fontWeight: FontWeight.w600,
    );
    final styleValue = TextStyle(
      fontSize: isNarrow ? 14 : 16,
      fontWeight: FontWeight.w700,
    );

    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryBlue, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _KV(
              title: leftTitle,
              valueText: leftValue,
              titleStyle: styleTitle,
              valueStyle: styleValue,
            ),
            _KV(
              title: midTitle,
              valueText: midValue,
              titleStyle: styleTitle,
              valueStyle: styleValue,
            ),
            _KV(
              title: rightTitle,
              valueText: rightValue,
              titleStyle: styleTitle,
              valueStyle: styleValue,
            ),
          ],
        ),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({
    required this.title,
    required this.valueText,
    required this.titleStyle,
    required this.valueStyle,
  });

  final String title;
  final String valueText;
  final TextStyle titleStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 2),
        Text(valueText, style: valueStyle),
      ],
    );
  }
}

class _SchoolAgg {
  double deposits = 0.0;
  double withdrawals = 0.0;
  int transactionCount = 0;
  double discrepancyTotal = 0.0;
  int discrepancyCount = 0;
  final Map<String, _ActorAgg> byActor = {};
}

class _ActorAgg {
  _ActorAgg({required this.name});

  final String name;
  double deposits = 0.0;
  double withdrawals = 0.0;
  int transactionCount = 0;
  double discrepancyTotal = 0.0;
  int discrepancyCount = 0;
  DateTime? lastActivity;
}

class _ReportAllSchools {
  _ReportAllSchools({
    required this.rows,
    required this.totalBalance,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.totalTransactions,
    required this.totalDiscrepancy,
    required this.totalDiscrepancyCount,
    required this.transactions,
  });

  final List<_SchoolRowReport> rows;
  final double totalBalance;
  final double totalDeposits;
  final double totalWithdrawals;
  final int totalTransactions;
  final double totalDiscrepancy;
  final int totalDiscrepancyCount;
  final List<_TransactionLogEntry> transactions;
}

class _SchoolRowReport {
  _SchoolRowReport({
    required this.schoolId,
    required this.schoolName,
    required this.balance,
    required this.deposits,
    required this.withdrawals,
    required this.transactionCount,
    required this.topDepositorName,
    required this.topDepositorDeposits,
    required this.discrepancyTotal,
    required this.discrepancyCount,
  });

  final String schoolId;
  final String schoolName;
  final double balance;
  final double deposits;
  final double withdrawals;
  final int transactionCount;
  final String topDepositorName;
  final double topDepositorDeposits;
  final double discrepancyTotal;
  final int discrepancyCount;
}

class _ReportSingleSchool {
  _ReportSingleSchool({
    required this.schoolId,
    required this.schoolName,
    required this.balance,
    required this.deposits,
    required this.withdrawals,
    required this.transactionCount,
    required this.topDepositorName,
    required this.topDepositorDeposits,
    required this.actors,
    required this.discrepancyTotal,
    required this.discrepancyCount,
    required this.transactions,
  });

  final String schoolId;
  final String schoolName;
  final double balance;
  final double deposits;
  final double withdrawals;
  final int transactionCount;
  final String topDepositorName;
  final double topDepositorDeposits;
  final List<_ActorAgg> actors;
  final double discrepancyTotal;
  final int discrepancyCount;
  final List<_TransactionLogEntry> transactions;
}

class _TransactionLogEntry {
  const _TransactionLogEntry({
    required this.date,
    required this.schoolName,
    required this.type,
    required this.submittedBy,
    required this.amount,
    this.discrepancy = 0.0,
    this.status = '',
    this.notes = '',
  });

  final DateTime date;
  final String schoolName;
  final String type; // 'Deposit' or 'Withdrawal'
  final String submittedBy;
  final double amount;
  final double discrepancy;
  final String status;
  final String notes;
}
