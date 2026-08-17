import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF8F8F5);
  static const raised = Color(0xFFFFFFFF);
  static const sunken = Color(0xFFF0F1EC);
  static const photo = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF191A17);
  static const textSecondary = Color(0xFF565850);
  static const textMuted = Color(0xFF85877E);
  static const textOnAccent = Color(0xFFFCFCFB);

  static const borderDefault = Color(0xFFE5E6E0);
  static const borderStrong = Color(0xFFCACCC3);
  static const accent = Color(0xFF191A17);
  static const fresh = Color(0xFFDCF46B);
  static const freshSoft = Color(0xFFF2F8D9);
}

abstract final class AppSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
}

abstract final class AppRadii {
  static const small = 10.0;
  static const medium = 14.0;
  static const large = 20.0;
  static const pill = 999.0;
}

abstract final class AppSizes {
  static const hitTarget = 44.0;
  static const navButton = 44.0;
}

abstract final class AppMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const relaxed = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
}

ThemeData buildCompeteTheme() {
  const compactTextTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 26,
      height: 1.12,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.4,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.15,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.25,
    ),
    headlineSmall: TextStyle(
      fontSize: 19,
      height: 1.2,
      fontWeight: FontWeight.w500,
    ),
    titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: 15, height: 1.35),
    bodyMedium: TextStyle(fontSize: 13.5, height: 1.35),
    bodySmall: TextStyle(fontSize: 12, height: 1.3),
    labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
  );
  const inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
    borderSide: BorderSide(color: AppColors.borderDefault),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Jost',
    textTheme: compactTextTheme,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: InkSparkle.splashFactory,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.textOnAccent,
      surface: AppColors.raised,
      onSurface: AppColors.textPrimary,
      outline: AppColors.borderDefault,
      secondary: AppColors.fresh,
      onSecondary: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.sunken,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _CompetePageTransitionsBuilder(),
        TargetPlatform.iOS: _CompetePageTransitionsBuilder(),
        TargetPlatform.macOS: _CompetePageTransitionsBuilder(),
        TargetPlatform.windows: _CompetePageTransitionsBuilder(),
        TargetPlatform.linux: _CompetePageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 50,
      titleSpacing: 4,
      iconTheme: IconThemeData(size: 21),
      titleTextStyle: TextStyle(
        fontFamily: 'Jost',
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        textStyle: compactTextTheme.labelLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        textStyle: compactTextTheme.labelLarge,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: compactTextTheme.labelLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.small)),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSizes.hitTarget),
        maximumSize: const Size.square(AppSizes.hitTarget),
        padding: EdgeInsets.zero,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.raised,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        borderSide: BorderSide(color: AppColors.textPrimary),
      ),
      errorBorder: inputBorder,
      focusedErrorBorder: inputBorder,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.raised,
      selectedColor: AppColors.textPrimary,
      disabledColor: AppColors.sunken,
      side: BorderSide(color: AppColors.borderDefault),
      shape: StadiumBorder(),
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      labelPadding: EdgeInsets.zero,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      secondaryLabelStyle: TextStyle(
        color: AppColors.textOnAccent,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      showCheckmark: false,
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      minVerticalPadding: 8,
      horizontalTitleGap: 10,
      contentPadding: EdgeInsets.symmetric(horizontal: 14),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.raised,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      contentTextStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13.5,
        height: 1.4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.raised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: TextStyle(color: AppColors.textOnAccent, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderDefault,
      thickness: 0.6,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.textPrimary,
      linearTrackColor: AppColors.sunken,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.textPrimary,
      selectionColor: AppColors.borderStrong,
      selectionHandleColor: AppColors.textPrimary,
    ),
  );
}

class _CompetePageTransitionsBuilder extends PageTransitionsBuilder {
  const _CompetePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.025, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
