import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF7F6F4);
  static const raised = Color(0xFFFFFFFF);
  static const sunken = Color(0xFFF0EFEC);
  static const photo = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF1E1D1B);
  static const textSecondary = Color(0xFF565350);
  static const textMuted = Color(0xFF837F79);
  static const textOnAccent = Color(0xFFFCFCFB);

  static const borderDefault = Color(0xFFE1DFDB);
  static const borderStrong = Color(0xFFC8C5C0);
  static const accent = Color(0xFF1E1D1B);
}

abstract final class AppSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x8 = 32.0;
}

abstract final class AppRadii {
  static const medium = 12.0;
  static const large = 16.0;
}

abstract final class AppSizes {
  static const hitTarget = 44.0;
  static const navButton = 52.0;
}

ThemeData buildCompeteTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.textOnAccent,
      surface: AppColors.raised,
      onSurface: AppColors.textPrimary,
      outline: AppColors.borderDefault,
    ),
    fontFamily: null,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.textPrimary,
      selectionColor: AppColors.borderStrong,
      selectionHandleColor: AppColors.textPrimary,
    ),
  );
}
