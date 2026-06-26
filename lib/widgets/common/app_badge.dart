import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class SizeBadge extends StatelessWidget {
  final String size;
  final bool isSelected;
  final VoidCallback? onTap;

  const SizeBadge({
    super.key,
    required this.size,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDesktop
                  ? AppColors.desktopPrimary
                  : AppColors.mobilePrimary)
              : (isDesktop
                  ? AppColors.desktopBackground
                  : AppColors.mobileSurface),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected
                ? (isDesktop
                    ? AppColors.desktopPrimary
                    : AppColors.mobilePrimary)
                : (isDesktop
                    ? AppColors.desktopBorder
                    : AppColors.mobileBorder),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          size,
          style: AppTextStyles.label(
            color: isSelected
                ? Colors.white
                : (isDesktop
                    ? AppColors.desktopTextSecondary
                    : AppColors.mobileTextSecondary),
          ),
        ),
      ),
    );
  }
}

class ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const ColorSwatch({
    super.key,
    required this.color,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: 28,
        height: 28,
        padding: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: isDesktop
                      ? AppColors.desktopPrimary
                      : AppColors.mobilePrimary,
                  width: 2,
                )
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: color == Colors.white || color == const Color(0xFFFFFFFF)
                ? Border.all(color: AppColors.desktopBorder, width: 0.5)
                : null,
          ),
        ),
      ),
    );
  }
}
