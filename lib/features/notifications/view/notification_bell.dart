// lib/features/notifications/view/notification_bell.dart
//
// KISS          : a single IconButton with a red badge — no third-party package needed.
// DRY           : one widget reused by every role's app bar.
// Open/Closed   : the bell reads from NotificationScope; tapping navigates to
//                 NotificationScreen. New behaviours (e.g. sound) add without
//                 modifying this widget.
import 'package:flutter/material.dart';

import 'package:lccu_finx/features/notifications/view/notification_screen.dart';
import 'package:lccu_finx/features/notifications/viewmodel/notification_vm.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = NotificationScope.of(context);
    final count = vm.unreadCount;

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () {
        final notifVm = vm; // captured before push
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationScreen(vm: notifVm),
          ),
        );
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, color: Colors.white),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
