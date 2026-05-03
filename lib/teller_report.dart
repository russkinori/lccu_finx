import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'common_repo.dart';
import 'download_helper.dart';
import 'supabase_config.dart';
import 'teller_vm.dart';
import 'teller_repo.dart';
import 'app_constants.dart';
import 'app_utils.dart';
import 'friendly_error.dart';

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

    for (final d in deposits) {
      final agg = bySchool.putIfAbsent(d.schoolId, () => _SchoolAgg());
      agg.deposits += d.amount;
      agg.transactionCount += 1;

      if (d.teacherId.isNotEmpty) {
        final teacherName =
            teacherNameBySchool[d.schoolId]?[d.teacherId] ?? 'Teacher';
        final t = agg.byActor.putIfAbsent(
          'teacher:${d.teacherId}',
          () => _ActorAgg(name: teacherName),
        );
        t.deposits += d.amount;
        t.transactionCount += 1;
        t.lastActivity = d.postedAt;
      }
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
    }

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
        ),
      );
    }

    rows.sort((a, b) => a.schoolName.compareTo(b.schoolName));

    double totalBalance = 0.0;
    double totalDeposits = 0.0;
    double totalWithdrawals = 0.0;
    int totalTransactions = 0;

    for (final r in rows) {
      totalBalance += r.balance;
      totalDeposits += r.deposits;
      totalWithdrawals += r.withdrawals;
      totalTransactions += r.transactionCount;
    }

    return _ReportAllSchools(
      rows: rows,
      totalBalance: totalBalance,
      totalDeposits: totalDeposits,
      totalWithdrawals: totalWithdrawals,
      totalTransactions: totalTransactions,
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

    final byActor = <String, _ActorAgg>{};

    for (final d in deposits) {
      totalDeposits += d.amount;
      transactionCount += 1;

      final actorName = teacherNames[d.teacherId] ?? 'Teacher';
      final actor = byActor.putIfAbsent(
        'teacher:${d.teacherId}',
        () => _ActorAgg(name: actorName),
      );
      actor.deposits += d.amount;
      actor.transactionCount += 1;
      actor.lastActivity = d.postedAt;
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
    }

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
      'School,Balance,Deposits,Withdrawals,Net,Top Depositor,Top Depositor Amount',
    );

    for (final r in report.rows) {
      final net = r.deposits - r.withdrawals;
      buffer.write('"${r.schoolName}",');
      buffer.write('${r.balance},');
      buffer.write('${r.deposits},');
      buffer.write('${r.withdrawals},');
      buffer.write('$net,');
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
    buffer.writeln('Top Depositor,${report.topDepositorName}');
    buffer.writeln('Top Depositor Amount,${report.topDepositorDeposits}');
    buffer.writeln();
    buffer.writeln('Staff Activity');
    buffer.writeln('Actor,Deposits,Withdrawals,Transactions,Last Activity');

    for (final a in report.actors) {
      final last = a.lastActivity == null
          ? '-'
          : a.lastActivity!.toIso8601String().split('T').first;
      buffer.write('"${a.name}",');
      buffer.write('${a.deposits},');
      buffer.write('${a.withdrawals},');
      buffer.write('${a.transactionCount},');
      buffer.writeln(last);
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
                    DataCell(Text(last)),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
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
  final Map<String, _ActorAgg> byActor = {};
}

class _ActorAgg {
  _ActorAgg({required this.name});

  final String name;
  double deposits = 0.0;
  double withdrawals = 0.0;
  int transactionCount = 0;
  DateTime? lastActivity;
}

class _ReportAllSchools {
  _ReportAllSchools({
    required this.rows,
    required this.totalBalance,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.totalTransactions,
  });

  final List<_SchoolRowReport> rows;
  final double totalBalance;
  final double totalDeposits;
  final double totalWithdrawals;
  final int totalTransactions;
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
  });

  final String schoolId;
  final String schoolName;
  final double balance;
  final double deposits;
  final double withdrawals;
  final int transactionCount;
  final String topDepositorName;
  final double topDepositorDeposits;
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
}
