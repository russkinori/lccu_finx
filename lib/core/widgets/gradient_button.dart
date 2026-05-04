// gradient_button.dart
//
// Reusable gradient button widget used throughout the app
// Eliminates code duplication for yellow/blue gradient buttons

import 'package:flutter/material.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/app/app_theme.dart';

/// A button with a gradient background decoration
///
/// Used for primary actions like "Submit", "Transaction History", etc.
/// Supports both yellow and blue gradients
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = AppGradients.yellowGradient,
    this.width = AppDimensions.buttonWidthStandard,
    this.height = AppDimensions.buttonHeightLarge,
    this.disabledBackgroundColor,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final LinearGradient gradient;
  final double width;
  final double height;
  final Color? disabledBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
          boxShadow: AppShadows.defaultShadow,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: AppTheme.transparentButtonStyle.copyWith(
            backgroundColor:
                disabledBackgroundColor != null && onPressed == null
                ? WidgetStateProperty.all(disabledBackgroundColor)
                : null,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// A text-only gradient button (for simpler use cases)
class GradientTextButton extends StatelessWidget {
  const GradientTextButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.gradient = AppGradients.yellowGradient,
    this.width = AppDimensions.buttonWidthStandard,
    this.height = AppDimensions.buttonHeightLarge,
  });

  final VoidCallback? onPressed;
  final String text;
  final LinearGradient gradient;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GradientButton(
      onPressed: onPressed,
      gradient: gradient,
      width: width,
      height: height,
      child: Text(text),
    );
  }
}
