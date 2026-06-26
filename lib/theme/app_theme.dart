import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  // ────────────────────────────────────────────
  // DESKTOP — Light Clean Professional
  // ────────────────────────────────────────────
  static ThemeData get desktop {
    const primary = AppColors.desktopPrimary;
    const surface = AppColors.desktopSurface;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: primary,
        surface: surface,
        onSurface: AppColors.desktopTextPrimary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.desktopBorder,
        outlineVariant: AppColors.desktopBorderStrong,
      ),
      scaffoldBackgroundColor: AppColors.desktopBackground,
      cardColor: surface,
      dividerColor: AppColors.desktopBorder,
      shadowColor: AppColors.desktopShadow,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: AppColors.desktopTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.appBarTitle(
          color: AppColors.desktopTextPrimary,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: surface,
        elevation: AppElevation.low,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.desktopBorder),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.desktopBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.desktopBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: AppTextStyles.bodyMedium(
          color: AppColors.desktopTextMuted,
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button(color: Colors.white),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.desktopTextPrimary,
          side: const BorderSide(color: AppColors.desktopBorderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button(
            color: AppColors.desktopTextPrimary,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppTextStyles.button(color: primary),
        ),
      ),

      // Bottom Nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.desktopSurface,
        selectedItemColor: primary,
        unselectedItemColor: AppColors.desktopTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 2,
      ),

      // Tab Bar
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: AppColors.desktopTextSecondary,
        indicatorColor: primary,
        dividerColor: Colors.transparent,
      ),

      // Text
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge(
          color: AppColors.desktopTextPrimary,
        ),
        displayMedium: AppTextStyles.displayMedium(
          color: AppColors.desktopTextPrimary,
        ),
        headlineLarge: AppTextStyles.headingLarge(
          color: AppColors.desktopTextPrimary,
        ),
        headlineMedium: AppTextStyles.headingMedium(
          color: AppColors.desktopTextPrimary,
        ),
        headlineSmall: AppTextStyles.headingSmall(
          color: AppColors.desktopTextPrimary,
        ),
        bodyLarge: AppTextStyles.bodyLarge(
          color: AppColors.desktopTextPrimary,
        ),
        bodyMedium: AppTextStyles.bodyMedium(
          color: AppColors.desktopTextPrimary,
        ),
        bodySmall: AppTextStyles.bodySmall(
          color: AppColors.desktopTextSecondary,
        ),
        labelLarge: AppTextStyles.label(
          color: AppColors.desktopTextPrimary,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: AppColors.desktopTextSecondary,
        size: 20,
      ),
    );
  }

  // ────────────────────────────────────────────
  // MOBILE — Dark Premium
  // ────────────────────────────────────────────
  static ThemeData get mobile {
    const primary = AppColors.mobilePrimary;
    const surface = AppColors.mobileSurface;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        secondary: primary,
        surface: surface,
        onSurface: AppColors.mobileTextPrimary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.mobileBorder,
        outlineVariant: AppColors.mobileBorderStrong,
      ),
      scaffoldBackgroundColor: AppColors.mobileBackground,
      cardColor: surface,
      dividerColor: AppColors.mobileBorder,
      shadowColor: Colors.transparent,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.mobileBackground,
        foregroundColor: AppColors.mobileTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.appBarTitle(
          color: AppColors.mobileTextPrimary,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.mobileBorder),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.mobileInputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: AppTextStyles.bodyMedium(
          color: AppColors.mobileTextSecondary,
        ),
        labelStyle: AppTextStyles.bodyMedium(
          color: AppColors.mobileTextSecondary,
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button(color: Colors.white),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: AppColors.mobileBorderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button(color: primary),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppTextStyles.button(color: primary),
        ),
      ),

      // Bottom Nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.mobileBottomNavBg,
        selectedItemColor: AppColors.mobileBottomNavActive,
        unselectedItemColor: AppColors.mobileTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Tab Bar
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: AppColors.mobileTextSecondary,
        indicatorColor: primary,
        dividerColor: Colors.transparent,
      ),

      // Text
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge(
          color: AppColors.mobileTextPrimary,
        ),
        displayMedium: AppTextStyles.displayMedium(
          color: AppColors.mobileTextPrimary,
        ),
        headlineLarge: AppTextStyles.headingLarge(
          color: AppColors.mobileTextPrimary,
        ),
        headlineMedium: AppTextStyles.headingMedium(
          color: AppColors.mobileTextPrimary,
        ),
        headlineSmall: AppTextStyles.headingSmall(
          color: AppColors.mobileTextPrimary,
        ),
        bodyLarge: AppTextStyles.bodyLarge(
          color: AppColors.mobileTextPrimary,
        ),
        bodyMedium: AppTextStyles.bodyMedium(
          color: AppColors.mobileTextPrimary,
        ),
        bodySmall: AppTextStyles.bodySmall(
          color: AppColors.mobileTextSecondary,
        ),
        labelLarge: AppTextStyles.label(
          color: AppColors.mobileTextPrimary,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.mobileSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: AppColors.mobileTextSecondary,
        size: 20,
      ),
    );
  }
}
