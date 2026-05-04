// popup_dialog.dart
//
// Reusable dialog with popup background image
// Used for confirmations and other modal interactions

import 'package:flutter/material.dart';
import 'package:lccu_finx/app/app_constants.dart';

/// A dialog with the popup background image
///
/// Provides consistent styling for all popup dialogs in the app
class PopupDialog extends StatelessWidget {
  const PopupDialog({super.key, required this.child, this.maxWidth = 520});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.backgroundTransparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage(AppAssets.popupBg),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A helper to show a standard confirmation dialog
///
/// Returns true if user confirms, false if canceled, null if dismissed
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool useYellowButton = true,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => PopupDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          Text(message, style: const TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: AppDimensions.paddingLarge),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  cancelText,
                  style: const TextStyle(color: AppColors.primaryBlue),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: useYellowButton
                      ? AppColors.yellow1
                      : AppColors.primaryBlue,
                  foregroundColor: AppColors.textOnPrimary,
                ),
                child: Text(confirmText),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
