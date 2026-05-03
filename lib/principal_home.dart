// principal_home.dart
//
// Mobile-only “Principal Home” screen.
// Use it like: DashboardShell(child: PrincipalHome())
//
// This matches your mock:
// - Welcome header (name)
// - Two blue summary tiles: Funds On-Site, Deposited Funds
// - “School Deposit Details” card (3 columns)
// - Teacher dropdown with left blue pill
// - “Teacher Deposit Details” card (3 columns)
// - Yellow “Transaction History” button

import 'package:flutter/material.dart';
import 'dashboard_shell.dart';
import 'principal_dash.dart';
import 'principal_vm.dart';
import 'principal_repo.dart';
import 'principal_reconcile.dart';
import 'app_constants.dart';
import 'app_utils.dart';
import 'widgets.dart';

class PrincipalHome extends StatefulWidget {
  const PrincipalHome({super.key});

  @override
  State<PrincipalHome> createState() => _PrincipalHomeState();
}

class _PrincipalHomeState extends State<PrincipalHome> {
  String? _selectedTeacherId;
  String? _schoolId;

  final List<String> _headers = const [
    'Deposit Due',
    'Deposited',
    'Difference',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = PrincipalScope.of(context, listen: false);

    // Bootstrap if needed
    if (!vm.isLoading && vm.snapshot == null) {
      Future.microtask(() async {
        await vm.bootstrap();
        // Extract schoolId from snapshot after bootstrap
        if (vm.repo is SupabasePrincipalRepository) {
          final repo = vm.repo as SupabasePrincipalRepository;
          try {
            final (_, i_, schoolId) = await repo.getPrincipalIdentity();
            setState(() => _schoolId = schoolId);
            await vm.refreshHomeData(schoolId);
          } catch (_) {}
        }
      });
    }

    _selectedTeacherId ??= vm.selectedTeacherId;
  }

  @override
  Widget build(BuildContext context) {
    final vm = PrincipalScope.of(context);

    final teachers = vm.teacherOptions;
    final selectedTeacher = _selectedTeacherId ?? vm.selectedTeacherId;

    return Column(
      children: [
        WelcomeHeader(name: vm.principalName, bottomSpacing: 16),

        // Account Balance pill (teacher_dash style)
        PillValueRow(
          label: 'Account Balance',
          value: formatMoney(vm.accountBalance),
        ),

        const SizedBox(height: 12),

        // Mini detail cards (same visual style as School Deposit Details,
        // kept side-by-side and same size)
        Row(
          children: [
            Expanded(
              child: MiniDetailCard(
                title: 'Funds On-Site',
                amount: formatMoney(vm.fundsOnSite),
                isLeft: true,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: MiniDetailCard(
                title: 'Deposited Funds',
                amount: formatMoney(vm.depositedFunds),
                isLeft: false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // School Deposit Details
        DetailCard(
          title: 'School Deposit Details',
          headers: _headers,
          values: [
            formatMoney(vm.schoolDepositDue),
            formatMoney(vm.schoolDeposited),
            formatMoney(vm.schoolDifference),
          ],
          valueColors: [
            vm.schoolDepositDue < 0 ? Colors.red.shade700 : null,
            null,
            vm.schoolDifference < 0 ? Colors.red.shade700 : null,
          ],
          onTap: () => _showSchoolDepositHistory(context),
        ),

        const SizedBox(height: 10),

        // Teacher dropdown (left blue pill + dropdown with names)
        PillLabeledDropdownWithNames(
          label: 'Teacher',
          value: selectedTeacher,
          options: teachers,
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _selectedTeacherId = v);
            vm.setTeacher(v == 'ALL' ? null : v);
            // Refresh teacher details after selection
            if (_schoolId != null) {
              await vm.refreshHomeData(_schoolId!);
            }
          },
        ),

        const SizedBox(height: 10),

        // Teacher Deposit Details
        DetailCard(
          title: 'Teacher Deposit Details',
          headers: _headers,
          values: [
            formatMoney(vm.teacherDepositDue),
            formatMoney(vm.teacherDeposited),
            formatMoney(vm.teacherDifference),
          ],
          valueColors: [
            vm.teacherDepositDue < 0 ? Colors.red.shade700 : null,
            null,
            vm.teacherDifference < 0 ? Colors.red.shade700 : null,
          ],
          onTap: () => _showTeacherDepositHistory(context),
        ),

        const SizedBox(height: 16),

        // Reconcile & Submit Deposit button
        GradientTextButton(
          onPressed: () async {
            if (_schoolId == null) return;
            final repo = vm.repo as SupabasePrincipalRepository;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PrincipalReconcileScreen(schoolId: _schoolId!, repo: repo),
              ),
            );
            // Refresh home data when returning from reconciliation
            if (mounted && _schoolId != null) {
              await vm.refreshHomeData(_schoolId!);
            }
          },
          text: 'Reconcile Deposit',
          gradient: AppGradients.blueGradient,
        ),
        const SizedBox(height: 12),

        // Transaction History button
        GradientTextButton(
          onPressed: () {
            // Preserve the existing PrincipalVm scope when opening the dash
            final vm = PrincipalScope.of(context, listen: false);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PrincipalScope(
                  notifier: vm,
                  child: const DashboardShell(
                    key: ValueKey('principal_dash_shell'),
                    center: PrincipalDashboard(),
                    welcomeText: '',
                  ),
                ),
              ),
            );
          },
          text: 'Transaction History',
          gradient: AppGradients.yellowGradient,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _showSchoolDepositHistory(BuildContext context) async {
    if (_schoolId == null) return;

    final repo =
        (PrincipalScope.of(context, listen: false).repo
            as SupabasePrincipalRepository);
    final history = await repo.getSchoolDepositHistory(_schoolId!);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.primaryBlue,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'School Deposit History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('No deposit history found'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: history.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, i) {
                          final record = history[i];
                          return ListTile(
                            title: Text(
                              formatMoney(record.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${formatDate(record.date)}'),
                                if (record.discrepancy != 0)
                                  Text(
                                    'Discrepancy: ${formatMoney(record.discrepancy)}',
                                  ),
                                if (record.notes.isNotEmpty)
                                  Text('Notes: ${record.notes}'),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTeacherDepositHistory(BuildContext context) async {
    if (_schoolId == null) return;

    final vm = PrincipalScope.of(context, listen: false);
    final repo = (vm.repo as SupabasePrincipalRepository);
    final teacherId = _selectedTeacherId == 'ALL' ? null : _selectedTeacherId;
    final history = await repo.getTeacherDepositHistory(
      _schoolId!,
      teacherId: teacherId,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.primaryBlue,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        teacherId == null
                            ? 'All Teachers Deposit History'
                            : 'Teacher Deposit History',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('No deposit history found'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: history.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, i) {
                          final record = history[i];
                          return ListTile(
                            title: Text(
                              formatMoney(record.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Teacher: ${record.teacherName}'),
                                Text(
                                  'Week: ${formatDate(record.weekStart)} - ${formatDate(record.weekEnd)}',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
