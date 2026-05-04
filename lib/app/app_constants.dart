// app_constants.dart
//
// Centralized constants for colors, dimensions, assets, and common values
// Promotes DRY principle across the app

import 'package:flutter/material.dart';

/// App Colors - Single source of truth for all color values
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary blue color scheme
  static const Color primaryBlue = Color(0xFF4899CB);
  static const Color primaryBlueLight = Color(0xFF5AB0E3);
  static const Color primaryBlueLighter = Color(
    0xFFEAF3FB,
  ); // Light blue for headers

  // Yellow/Gold gradient colors (for buttons, highlights)
  static const Color yellow1 = Color(0xFFF7B032);
  static const Color yellow2 = Color(0xFFF6CF52);

  // Additional UI accents used across dashboards/cards
  static const Color accentYellow = Color(0xFFF6C33A);
  static const Color accentGreen = Color(0xFF27AE60);
  static const Color accentPurple = Color(0xFFBB6BD9);
  static const Color accentBlue2 = Color(0xFF2E86DE);
  static const Color accentRed = Color(0xFFEE5A6F);

  // Semantic colors
  static const Color successGreen = Colors.green;
  static const Color errorRed = Colors.red;
  static const Color warningOrange = Colors.orange;

  // Text colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textOnPrimary = Colors.white;

  // Background colors
  static const Color backgroundWhite = Colors.white;
  static const Color backgroundTransparent = Colors.transparent;
}

/// App Dimensions - Consistent spacing and sizing
class AppDimensions {
  AppDimensions._();

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 10.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 14.0;

  // Padding/spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 12.0;
  static const double paddingLarge = 16.0;
  static const double paddingXLarge = 24.0;

  // Button dimensions
  static const double buttonHeightSmall = 40.0;
  static const double buttonHeightMedium = 44.0;
  static const double buttonHeightLarge = 48.0;
  static const double buttonHeightXLarge = 56.0;
  static const double buttonWidthStandard = 230.0;

  // Card dimensions
  static const double cardElevation = 0.0;
  static const double cardBorderWidth = 1.0;

  // Pill/Row dimensions
  static const double pillLeftWidth = 140.0;
  static const double pillHeight = 44.0;

  // Icon sizes
  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 40.0;
  static const double iconSizeLarge = 64.0;
}

/// App Assets - Centralized asset paths
class AppAssets {
  AppAssets._();

  // Images
  static const String bgImage = 'assets/images/bg_img.png';
  static const String lccuLogo = 'assets/images/lccu_logo.png';
  static const String popupBg = 'assets/images/popup_bg.png';
  static const String icon = 'assets/images/icon.png';
  static const String launcherIcon = 'assets/images/launcher_icon.png';
  static const String webBanner = 'assets/images/web_banner.png';
  static const String webBg = 'assets/images/web_bg.png';
}

/// App Gradients - Reusable gradient definitions
class AppGradients {
  AppGradients._();

  static const LinearGradient blueGradient = LinearGradient(
    colors: [AppColors.primaryBlue, AppColors.primaryBlueLight],
  );

  static const LinearGradient yellowGradient = LinearGradient(
    colors: [AppColors.yellow1, AppColors.yellow2],
  );
}

/// App Shadows - Reusable box shadow definitions
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> defaultShadow = [
    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
  ];
}
