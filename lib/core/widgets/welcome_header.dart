// welcome_header.dart
//
// Shared "WELCOME" header used on all role home screens.
// Renders the WELCOME label, the user's display name, and a configurable
// bottom spacing so each screen can match its own layout rhythm.

import 'package:flutter/material.dart';

class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({
    super.key,
    required this.name,
    this.bottomSpacing = 14.0,
  });

  final String name;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Text(
          'WELCOME',
          style: TextStyle(letterSpacing: 1.2, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}
