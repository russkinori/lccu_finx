import 'package:flutter/material.dart';

import 'package:lccu_finx/features/common/data/common_repo.dart';
import 'package:lccu_finx/features/teller/viewmodel/teller_vm.dart';
import 'package:lccu_finx/app/supabase_config.dart';
import 'package:lccu_finx/app/app_constants.dart';

class TellerHome extends StatefulWidget {
  const TellerHome({super.key});

  @override
  State<TellerHome> createState() => _TellerHomeState();
}

class _TellerHomeState extends State<TellerHome> {
  bool _initialized = false;
  String? _displayName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final vm = TellerScope.of(context, listen: false);
    if (!vm.isLoading && vm.schools.isEmpty) {
      Future.microtask(() => vm.bootstrap());
    }

    Future.microtask(() async {
      try {
        final name = await CommonRepository(
          supabase,
        ).getCurrentUserDisplayName(fallback: '');
        if (!mounted) return;
        setState(() => _displayName = name);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;

    final vm = TellerScope.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 600;
    final titleSize = isNarrow ? 20.0 : 24.0;
    final welcomeSize = isNarrow ? 12.0 : 14.0;
    final nameSize = isNarrow ? 16.0 : 18.0;
    final edgePadding = isNarrow ? 8.0 : 12.0;

    return Padding(
      padding: EdgeInsets.all(edgePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            'Teller Home',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxCardHeight = MediaQuery.of(context).size.height * 0.65;

              return ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: 180,
                  maxHeight: maxCardHeight,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: AppColors.primaryBlue),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: AppColors.primaryBlue,
                          padding: EdgeInsets.symmetric(
                            vertical: isNarrow ? 6 : 8,
                          ),
                          child: Row(
                            children: [
                              _HeaderCell(
                                'School',
                                flex: 4,
                                isNarrow: isNarrow,
                              ),
                              _HeaderCell(
                                'Account Balance',
                                flex: 3,
                                right: true,
                                isNarrow: isNarrow,
                              ),
                              _HeaderCell(
                                'Pending Deposit',
                                flex: 3,
                                right: true,
                                isNarrow: isNarrow,
                              ),
                              _HeaderCell(
                                'Disparity',
                                flex: 3,
                                right: true,
                                isNarrow: isNarrow,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final rows = vm.schools;

                              if (vm.isLoading && rows.isEmpty) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if ((vm.error ?? '').isNotEmpty && rows.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      vm.error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                );
                              }

                              if (rows.isEmpty) {
                                return const Center(child: Text('No schools'));
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: rows.length,
                                separatorBuilder: (context, index) => const Divider(
                                  height: 1,
                                  color: Colors.black12,
                                ),
                                itemBuilder: (context, i) {
                                  final s = rows[i];
                                  return InkWell(
                                    onTap: () async {
                                      await vm.selectSchool(s.schoolId);
                                      if (!mounted) return;
                                      Navigator.of(context).pushNamed('/teller/dash');
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isNarrow ? 8 : 12,
                                        vertical: isNarrow ? 8 : 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              s.schoolName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                decoration:
                                                    TextDecoration.underline,
                                                fontSize: isNarrow ? 12 : 14,
                                              ),
                                            ),
                                          ),
                                          _vDivider(),
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: isNarrow ? 4 : 8,
                                              ),
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  '\$${s.accountBalance.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: isNarrow ? 11 : 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          _vDivider(),
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: isNarrow ? 4 : 8,
                                              ),
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  '\$${s.pendingDeposit.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: isNarrow ? 11 : 14,
                                                    color: s.pendingDeposit < 0
                                                        ? Colors.red.shade700
                                                        : null,
                                                    fontWeight:
                                                        s.pendingDeposit < 0
                                                        ? FontWeight.w600
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          _vDivider(),
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: isNarrow ? 4 : 8,
                                              ),
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  '\$${s.latestDiscrepancy.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: isNarrow ? 11 : 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool right;
  final bool isNarrow;

  const _HeaderCell(
    this.text, {
    this.flex = 1,
    this.right = false,
    this.isNarrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 12),
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isNarrow ? 11 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _vDivider() => Container(width: 1, height: 14, color: Colors.black26);