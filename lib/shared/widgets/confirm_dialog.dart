import 'package:flutter/material.dart';
import '../../core/app_strings.dart';

class ConfirmDialog {
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '',
    String cancelText = '',
    Color confirmColor = const Color(0xFFF87171),
    IconData? icon,
  }) {
    const bgCard = Color(0xFF13131F);
    const borderStrong = Color(0xFF2A2A40);
    const textPrimary = Color(0xFFEEEEFF);
    const textSecondary = Color(0xFF9090A8);

    final cText = confirmText.isNotEmpty ? confirmText : S.t('action_confirm');
    final aText = cancelText.isNotEmpty ? cancelText : S.t('action_cancel');
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderStrong),
        ),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: confirmColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(fontSize: 14, color: textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(aText,
                style: const TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: textPrimary,
              elevation: 0,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: Text(cText),
          ),
        ],
      ),
    );
  }
}
