import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final EdgeInsetsGeometry? contentPadding;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).brightness == Brightness.light;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: AppTextStyles.bodyMedium(
        color: isDesktop
            ? AppColors.desktopTextPrimary
            : AppColors.mobileTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20)
            : null,
        suffixIcon: suffixIcon,
        contentPadding: contentPadding ?? EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isDesktop ? 12.0 : 14.0,
        ),
        filled: true,
        fillColor: isDesktop
            ? AppColors.desktopSurface
            : AppColors.mobileInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: isDesktop
              ? const BorderSide(color: AppColors.desktopBorder)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: isDesktop
              ? const BorderSide(color: AppColors.desktopBorder)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDesktop
                ? AppColors.desktopPrimary
                : AppColors.mobilePrimary,
            width: isDesktop ? 1.5 : 1.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: AppTextStyles.bodyMedium(
          color: isDesktop
              ? AppColors.desktopTextMuted
              : AppColors.mobileTextSecondary,
        ),
      ),
    );
  }
}
