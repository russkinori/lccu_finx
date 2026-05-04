// detail_card.dart
//
// Reusable card widget with blue header and optional column layout
// Used in principal_home, reconcile screen, and other dashboards

import 'package:flutter/material.dart';
import 'package:lccu_finx/app/app_constants.dart';

/// A card with blue header bar and optional columns
///
/// Used for "School Deposit Details", "Teacher Deposit Details" etc.
/// Supports tap actions and custom value colors (e.g., red for negative amounts)
class DetailCard extends StatelessWidget {
  const DetailCard({
    super.key,
    required this.title,
    required this.headers,
    required this.values,
    this.valueColors,
    this.onTap,
  });

  final String title;
  final List<String> headers;
  final List<String> values;
  final List<Color?>? valueColors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primaryBlue;
    const radius = AppDimensions.radiusLarge;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: blue,
              width: AppDimensions.cardBorderWidth,
            ),
          ),
          child: Column(
            children: [
              // Title
              Container(
                color: blue,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Column headers
              Container(
                color: AppColors.primaryBlueLighter,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < headers.length; i++) ...[
                      Expanded(
                        child: Text(
                          headers[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (i < headers.length - 1)
                        const SizedBox(
                          width: 1,
                          child: ColoredBox(color: AppColors.textOnPrimary),
                        ),
                    ],
                  ],
                ),
              ),
              // Single values row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  children: List.generate(
                    values.length,
                    (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          values[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                valueColors != null && i < valueColors!.length
                                ? valueColors![i]
                                : null,
                            fontWeight:
                                valueColors != null &&
                                    i < valueColors!.length &&
                                    valueColors![i] != null
                                ? FontWeight.w600
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A mini detail card used for split side-by-side cards
/// (e.g., "Funds On-Site" and "Deposited Funds" in principal_home)
class MiniDetailCard extends StatelessWidget {
  const MiniDetailCard({
    super.key,
    required this.title,
    required this.amount,
    this.isLeft = true,
  });

  final String title;
  final String amount;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primaryBlue;
    const radius = AppDimensions.radiusLarge;

    final borderRadius = isLeft
        ? const BorderRadius.only(
            topLeft: Radius.circular(radius),
            bottomLeft: Radius.circular(radius),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: blue, width: AppDimensions.cardBorderWidth),
        ),
        child: Column(
          children: [
            // Title bar
            Container(
              color: blue,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Single centered value row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(amount, textAlign: TextAlign.center),
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
