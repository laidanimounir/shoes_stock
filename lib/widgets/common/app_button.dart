import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double? height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height,
  });

  factory AppButton.primary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = true,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        isLoading: isLoading,
        fullWidth: fullWidth,
        variant: AppButtonVariant.primary,
      );

  factory AppButton.secondary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = true,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        isLoading: isLoading,
        fullWidth: fullWidth,
        variant: AppButtonVariant.secondary,
      );

  factory AppButton.ghost({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = true,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        isLoading: isLoading,
        fullWidth: fullWidth,
        variant: AppButtonVariant.ghost,
      );

  factory AppButton.danger({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = true,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        isLoading: isLoading,
        fullWidth: fullWidth,
        variant: AppButtonVariant.danger,
      );

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).brightness == Brightness.light;
    final effectiveHeight = height ?? (isDesktop ? 40.0 : 48.0);

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant == AppButtonVariant.primary || variant == AppButtonVariant.danger
              ? Colors.white
              : AppColors.mobilePrimary,
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: _textStyle(context)),
        ],
      );
    } else {
      child = Text(label, style: _textStyle(context));
    }

    final button = _buildStyledButton(context, child, effectiveHeight);

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildStyledButton(BuildContext context, Widget child, double height) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _Pressable(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );

      case AppButtonVariant.secondary:
        return _Pressable(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );

      case AppButtonVariant.ghost:
        return _Pressable(
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );

      case AppButtonVariant.danger:
        return _Pressable(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );
    }
  }

  TextStyle _textStyle(BuildContext context) {
    return AppTextStyles.button(
      color: variant == AppButtonVariant.primary || variant == AppButtonVariant.danger
          ? Colors.white
          : Theme.of(context).colorScheme.primary,
    );
  }
}

enum AppButtonVariant { primary, secondary, ghost, danger }

class _Pressable extends StatefulWidget {
  final Widget child;
  const _Pressable({required this.child});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
