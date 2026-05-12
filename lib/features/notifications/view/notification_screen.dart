// lib/features/notifications/view/notification_screen.dart
//
// Single Responsibility : renders the notification inbox and handles
//                         mark-read interactions.
// KISS                  : pull-to-refresh + list; no pagination for now (YAGNI).
// Separation of Concerns: all state mutations delegated to NotificationVm.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/features/notifications/data/notification_repo.dart';
import 'package:lccu_finx/features/notifications/viewmodel/notification_vm.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, required this.vm});

  final NotificationVm vm;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static final _dateFmt = DateFormat('d MMM y, HH:mm');

  @override
  void initState() {
    super.initState();
    // Refresh the list when the screen opens (non-blocking).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.vm.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final vm = widget.vm;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 3,
            actions: [
              if (vm.unreadCount > 0)
                TextButton(
                  onPressed: vm.markAllRead,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: _buildBody(vm),
        );
      },
    );
  }

  Widget _buildBody(NotificationVm vm) {
    if (vm.isLoading && vm.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null && vm.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(vm.error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (vm.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No notifications yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView.separated(
        itemCount: vm.items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) => _NotificationTile(
          item: vm.items[i],
          onTap: () => vm.markRead(vm.items[i].notificationId),
          dateFmt: _dateFmt,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private tile widget — keeps NotificationScreen lean (SRP)
// ---------------------------------------------------------------------------
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.dateFmt,
  });

  final NotificationRow item;
  final VoidCallback onTap;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? AppColors.primaryBlueLighter : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unread ? AppColors.primaryBlue : Colors.transparent,
                ),
              ),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight:
                          unread ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFmt.format(item.createdAt.toLocal()),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
