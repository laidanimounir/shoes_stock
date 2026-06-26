import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? trend;
  final String? trendLabel;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = AppColors.desktopPrimary,
    this.trend,
    this.trendLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDesktop
            ? AppColors.desktopSurface
            : AppColors.mobileSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border(
          left: isDesktop
              ? BorderSide(color: color, width: 3)
              : BorderSide.none,
        ),
        boxShadow: isDesktop
            ? [
                BoxShadow(
                  color: AppColors.desktopShadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption(
                    color: isDesktop
                        ? AppColors.desktopTextSecondary
                        : AppColors.mobileTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.headingSmall(color: color),
                ),
                if (trend != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        trend! >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: trend! >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trendLabel ?? '${trend!.abs().toStringAsFixed(1)}%',
                        style: AppTextStyles.caption(
                          color: trend! >= 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
