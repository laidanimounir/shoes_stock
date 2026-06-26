import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppShimmerCard extends StatelessWidget {
  final int count;
  final double height;
  final double? width;

  const AppShimmerCard({
    super.key,
    this.count = 3,
    this.height = 80,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).brightness == Brightness.light;

    return Shimmer.fromColors(
      baseColor: isDesktop
          ? AppColors.desktopShimmerBase
          : AppColors.mobileShimmerBase,
      highlightColor: isDesktop
          ? AppColors.desktopShimmerHighlight
          : AppColors.mobileShimmerHighlight,
      child: Column(
        children: List.generate(count, (i) {
          return Container(
            width: width,
            height: height,
            margin: EdgeInsets.only(
              bottom: i < count - 1 ? AppSpacing.sm : 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          );
        }),
      ),
    );
  }
}

class AppShimmerListTile extends StatelessWidget {
  final int count;

  const AppShimmerListTile({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).brightness == Brightness.light;

    return Shimmer.fromColors(
      baseColor: isDesktop
          ? AppColors.desktopShimmerBase
          : AppColors.mobileShimmerBase,
      highlightColor: isDesktop
          ? AppColors.desktopShimmerHighlight
          : AppColors.mobileShimmerHighlight,
      child: Column(
        children: List.generate(count, (i) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            margin: EdgeInsets.only(
              bottom: i < count - 1 ? AppSpacing.xs : 0,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class AppShimmerStatCard extends StatelessWidget {
  final int count;

  const AppShimmerStatCard({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return AppShimmerCard(count: count, height: 96);
  }
}

class AppShimmerGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;

  const AppShimmerGrid({
    super.key,
    this.count = 6,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).brightness == Brightness.light;

    return Shimmer.fromColors(
      baseColor: isDesktop
          ? AppColors.desktopShimmerBase
          : AppColors.mobileShimmerBase,
      highlightColor: isDesktop
          ? AppColors.desktopShimmerHighlight
          : AppColors.mobileShimmerHighlight,
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: List.generate(count, (_) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          );
        }),
      ),
    );
  }
}
