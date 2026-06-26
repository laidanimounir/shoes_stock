import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ────────────────────────────────────────────
  // DESKTOP — Light Clean Professional
  // ────────────────────────────────────────────
  static const desktopBackground = Color(0xFFF5F6FA);
  static const desktopSurface = Color(0xFFFFFFFF);
  static const desktopSidebar = Color(0xFFFFFFFF);
  static const desktopPrimary = Color(0xFF5B5FC7);
  static const desktopPrimaryDark = Color(0xFF4A4FB8);
  static const desktopPrimaryLight = Color(0xFFEEEEFF);
  static const desktopSidebarActive = Color(0xFF5B5FC7);
  static const desktopSidebarInactive = Color(0xFF6B7280);
  static const desktopShadow = Color(0x0F000000); // rgba(0,0,0,0.06)

  // ────────────────────────────────────────────
  // MOBILE — Dark Premium
  // ────────────────────────────────────────────
  static const mobileBackground = Color(0xFF0F0F0F);
  static const mobileSurface = Color(0xFF1C1C1E);
  static const mobileSurfaceElevated = Color(0xFF2C2C2E);
  static const mobilePrimary = Color(0xFF2979FF);
  static const mobilePrimaryDark = Color(0xFF1565C0);
  static const mobilePrimaryLight = Color(0xFF1E3A5F);
  static const mobileBottomNavBg = Color(0xFF1C1C1E);
  static const mobileBottomNavActive = Color(0xFF2979FF);
  static const mobileInputFill = Color(0xFF2C2C2E);

  // ────────────────────────────────────────────
  // TEXT
  // ────────────────────────────────────────────
  static const desktopTextPrimary = Color(0xFF111827);
  static const desktopTextSecondary = Color(0xFF6B7280);
  static const desktopTextMuted = Color(0xFF9CA3AF);

  static const mobileTextPrimary = Color(0xFFFFFFFF);
  static const mobileTextSecondary = Color(0xFF8E8E93);
  static const mobileTextMuted = Color(0xFF48484A);

  // ────────────────────────────────────────────
  // SEMANTIC (shared)
  // ────────────────────────────────────────────
  static const success = Color(0xFF22C55E);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFDBEAFE);

  // ────────────────────────────────────────────
  // BORDERS
  // ────────────────────────────────────────────
  static const desktopBorder = Color(0xFFE5E7EB);
  static const desktopBorderStrong = Color(0xFFD1D5DB);
  static const mobileBorder = Color(0xFF2C2C2E);
  static const mobileBorderStrong = Color(0xFF3A3A3C);

  // ────────────────────────────────────────────
  // SHIMMER
  // ────────────────────────────────────────────
  static const desktopShimmerBase = Color(0xFFF0F0F0);
  static const desktopShimmerHighlight = Color(0xFFE0E0E0);
  static const mobileShimmerBase = Color(0xFF1C1C1E);
  static const mobileShimmerHighlight = Color(0xFF2C2C2E);

  // ────────────────────────────────────────────
  // LEGACY REFERENCE — keep old AppColors names
  // for incremental migration (remove after all
  // screens are migrated)
  // ────────────────────────────────────────────
  static const background = Color(0xFF121220);
  static const surface = Color(0xFF1E1E2E);
  static const surfaceLight = Color(0xFF252538);
  static const sidebarTop = Color(0xFF1A1A2E);
  static const sidebarBottom = Color(0xFF0D0D1F);
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF1565C0);
  static const gold = Color(0xFFD4A843);
  static const goldLight = Color(0xFFF0C96B);
  static const successOld = Color(0xFF43A047);
  static const warningOld = Color(0xFFFB8C00);
  static const dangerOld = Color(0xFFE53935);
  static const infoOld = Color(0xFF1E88E5);
  static const purple = Color(0xFF7B1FA2);
  static const teal = Color(0xFF00897B);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0C0);
  static const border = Color(0xFF2A2A3E);
}
