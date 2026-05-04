// pill_row.dart
//
// Reusable "pill" style row widgets with blue left section and white right section
// Used for displaying labels and values in a consistent format

import 'package:flutter/material.dart';
import 'package:responsive_text_widget/responsive_text_widget.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/features/principal/data/principal_repo.dart' show PIdName;

/// A row with blue pill label on left and value on right
///
/// Example: "Account Balance" | "$1,234.56"
class PillValueRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const PillValueRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primaryBlue;
    return Row(
      children: [
        Container(
          width: AppDimensions.pillLeftWidth,
          height: AppDimensions.pillHeight,
          decoration: const BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ResponsiveText(
            text: label,
            style:
                labelStyle ??
                const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Container(
            height: AppDimensions.pillHeight,
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              border: Border.all(color: blue),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ResponsiveText(
              text: value,
              style:
                  valueStyle ??
                  const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Left blue pill label + dropdown that shows names but uses IDs as values
///
/// Used for teacher selection, etc.
class PillLabeledDropdownWithNames extends StatelessWidget {
  const PillLabeledDropdownWithNames({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<PIdName> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primaryBlue;

    return Row(
      children: [
        // Blue pill
        Container(
          width: AppDimensions.pillLeftWidth,
          height: AppDimensions.pillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Dropdown
        Expanded(
          child: Container(
            height: AppDimensions.pillHeight,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
              border: Border.all(
                color: blue,
                width: AppDimensions.cardBorderWidth,
              ),
              color: AppColors.backgroundWhite,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.arrow_drop_down),
                ),
                items: options
                    .map(
                      (opt) => DropdownMenuItem(
                        value: opt.id,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(opt.name),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
