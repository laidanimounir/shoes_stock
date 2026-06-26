import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final bool isDesktop;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.elevation,
    this.isDesktop = false,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = widget.isDesktop;
    final borderRadius = BorderRadius.circular(AppRadius.lg);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDesktop
            ? AppColors.desktopSurface
            : AppColors.mobileSurface,
        borderRadius: borderRadius,
        border: Border.all(
          color: _isHovered && isDesktop
              ? AppColors.desktopPrimary
              : (isDesktop ? AppColors.desktopBorder : AppColors.mobileBorder),
          width: _isHovered && isDesktop ? 1.5 : 0.5,
        ),
        boxShadow: isDesktop
            ? [
                BoxShadow(
                  color: AppColors.desktopShadow,
                  blurRadius: _isHovered ? 12 : 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: card,
      );
    }

    if (isDesktop) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: card,
      );
    }

    return card;
  }
}
