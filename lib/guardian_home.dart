// guardian_home.dart
//
// Mobile-only “Guardian Dashboard”
// Use like: DashboardShell(child: GuardianHome())
// Matches your mock:
// - Welcome header (guardian name)
// - Blue summary table: Child | Balance | Requests (with tappable "Pending")
// - Withdrawal Request card with details row + note field
// - Segmented Approve / Decline buttons
// - Yellow "Transaction History" button

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'guardian_vm.dart';
import 'guardian_repo.dart';
import 'dashboard_shell.dart';
import 'guardian_dash.dart';
import 'app_constants.dart';
import 'app_utils.dart';
import 'widgets.dart';
import 'friendly_error.dart';

class GuardianHome extends StatefulWidget {
  const GuardianHome({super.key});

  @override
  State<GuardianHome> createState() => _GuardianHomeState();
}

class _GuardianHomeState extends State<GuardianHome> {
  final TextEditingController _note = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = GuardianScope.of(context, listen: false);
    Future.microtask(() => vm.bootstrap());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;
    final vm = GuardianScope.of(context);
    final children = vm.children;
    final activeRequest = vm.highlightedRequest;

    // Update note controller when active request changes
    if (activeRequest != null &&
        _note.text.isEmpty &&
        activeRequest.note != null) {
      _note.text = activeRequest.note!;
    }

    if (vm.isLoading && children.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading guardian data',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                vm.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => vm.refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        WelcomeHeader(name: vm.guardianName),

        // ---- Children table ----
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.primaryBlue),
            ),
            child: Column(
              children: [
                // blue header bar
                Container(
                  height: 40,
                  color: AppColors.primaryBlue,
                  child: Row(
                    children: const [
                      _HeaderCell('Child', flex: 5),
                      _HeaderCell('Balance', flex: 3),
                      _HeaderCell('Requests', flex: 4, right: true),
                    ],
                  ),
                ),
                // body
                ...children.map(
                  (c) => _ChildRowTile(
                    data: c,
                    // If the currently highlighted request belongs to this child,
                    // pass its status so the row can show APPROVED/DECLINED instead
                    // of the simple Pending/None text.
                    statusLabel:
                        activeRequest != null &&
                            activeRequest.studentId == c.studentId
                        ? activeRequest.status
                        : null,
                    onTapRequest: () => _openChildRequests(c),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ---- Withdrawal request card ----
        if (activeRequest != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: AppColors.primaryBlue),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: const Center(
                      child: Text(
                        'Withdrawal Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // detail row header
                  Container(
                    height: 36,
                    color: AppColors.primaryBlueLighter,
                    child: Row(
                      children: const [
                        _SubHeaderCell('Child', flex: 5),
                        _SubHeaderCell('Amount', flex: 3),
                        _SubHeaderCell('Time', flex: 3, right: true),
                      ],
                    ),
                  ),
                  // detail row values
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.primaryBlue),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(activeRequest.studentName),
                        ),
                        _vDivider(),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              '\$${activeRequest.amount.toStringAsFixed(2)}',
                            ),
                          ),
                        ),
                        _vDivider(),
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(_formatTime(activeRequest.requestedAt)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // status banner when not pending (compare case-insensitive)
                  if (activeRequest.status.toLowerCase() != 'pending')
                    Container(
                      width: double.infinity,
                      color: activeRequest.status.toLowerCase() == 'approved'
                          ? Colors.green[50]
                          : Colors.red[50],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          capitalize(activeRequest.status),
                          style: TextStyle(
                            color:
                                activeRequest.status.toLowerCase() == 'approved'
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  // note box
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: TextField(
                      controller: _note,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: activeRequest.note ?? 'Add a note…',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  // Approve / Decline segmented buttons (only when still pending)
                  if (activeRequest.status.toLowerCase() == 'pending')
                    SizedBox(
                      height: 41,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _approve,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.green[100],
                                foregroundColor: Colors.green[800],
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(10),
                                  ),
                                ),
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: _decline,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red[100],
                                foregroundColor: Colors.red[800],
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    bottomRight: Radius.circular(10),
                                  ),
                                ),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          'Status: ${capitalize(activeRequest.status)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // ---- Transaction History button ----
        SizedBox(
          width: 230,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.yellowGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                final vm = GuardianScope.of(context, listen: false);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GuardianScope(
                      notifier: vm,
                      child: DashboardShell(
                        key: ValueKey(
                          'guardian_dash_${DateTime.now().millisecondsSinceEpoch}',
                        ),
                        center: const GuardianDashboard(),
                        welcomeText: '',
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                foregroundColor: Colors.white,
              ),
              child: const Center(child: Text('Transaction History')),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // --- Actions ---
  void _openChildRequests(GuardianChildRow c) async {
    if (c.pendingRequests > 0) {
      final vm = GuardianScope.of(context, listen: false);
      final pending = await vm.getPendingRequests(studentId: c.studentId);
      if (!mounted) return;

      if (pending.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pending requests found')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _PendingSheet(
            childName: c.name,
            requests: pending,
            onDecide: (requestId, approve, note) async {
              Navigator.pop(context);
              if (approve) {
                await _approve(requestId, note);
              } else {
                await _decline(requestId, note);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _approve([String? specificRequestId, String? note]) async {
    final vm = GuardianScope.of(context, listen: false);
    final requestId = specificRequestId ?? vm.highlightedRequest?.requestId;
    if (requestId == null) return;

    try {
      await vm.decide(
        requestId: requestId,
        approve: true,
        note: note ?? _note.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Withdrawal approved')));
      _note.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Failed to approve withdrawal.', e))));
    }
  }

  Future<void> _decline([String? specificRequestId, String? note]) async {
    final vm = GuardianScope.of(context, listen: false);
    final requestId = specificRequestId ?? vm.highlightedRequest?.requestId;
    if (requestId == null) return;

    try {
      await vm.decide(
        requestId: requestId,
        approve: false,
        note: note ?? _note.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Withdrawal declined')));
      _note.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyActionError('Failed to decline withdrawal.', e))));
    }
  }

  String _formatTime(DateTime dt) {
    return DateFormat('dd.MM.yy').format(dt);
  }
}

// ====== UI bits ======

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool right;
  const _HeaderCell(this.text, {this.flex = 1, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: right ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubHeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool right;
  const _SubHeaderCell(this.text, {this.flex = 1, this.right = false});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _ChildRowTile extends StatelessWidget {
  final GuardianChildRow data;
  final VoidCallback onTapRequest;
  final String? statusLabel;

  const _ChildRowTile({
    required this.data,
    required this.onTapRequest,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final divider = Container(width: 1, height: 14, color: Colors.black26);
    final hasPending = data.pendingRequests > 0;

    Widget requestWidget;
    if (statusLabel != null && statusLabel!.toLowerCase() != 'pending') {
      // Show final decision for the highlighted request belonging to this child
      final color = statusLabel!.toLowerCase() == 'approved'
          ? Colors.green[800]
          : Colors.red[800];
      requestWidget = Text(
        capitalize(statusLabel!),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      );
    } else if (hasPending) {
      requestWidget = InkWell(
        onTap: onTapRequest,
        child: Text(
          'Pending',
          style: const TextStyle(
            color: AppColors.primaryBlue,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      requestWidget = const Text(
        'None',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.primaryBlue)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(data.name)),
          divider,
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('\$${data.balance.toStringAsFixed(2)}'),
            ),
          ),
          divider,
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: requestWidget,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSheet extends StatelessWidget {
  final String childName;
  final List<GuardianWithdrawal> requests;
  // onDecide receives the request id, approve flag, and the optional note
  // provided by the child when they created the withdrawal request.
  final void Function(String requestId, bool approve, String? note) onDecide;

  const _PendingSheet({
    required this.childName,
    required this.requests,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage(AppAssets.popupBg),
              fit: BoxFit.fill,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'PENDING REQUESTS – ${childName.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...requests.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '• \$${r.amount.toStringAsFixed(2)} — ${DateFormat('MMM d, h:mm a').format(r.requestedAt)}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                              TextButton(
                                onPressed: () => onDecide(r.requestId, true, r.note),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.green[100],
                                  foregroundColor: Colors.green[800],
                                ),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () => onDecide(r.requestId, false, r.note),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red[100],
                                  foregroundColor: Colors.red[800],
                                ),
                                child: const Text('Decline'),
                              ),
                            ],
                          ),
                          if (r.note != null && r.note!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 6),
                              child: Text(
                                r.note!,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      width: 140,
                      height: 42,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppGradients.yellowGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ====== Helpers ======

// (Title/case helpers centralized in app_utils.dart)

Widget _vDivider() => Container(width: 1, height: 14, color: Colors.black26);
