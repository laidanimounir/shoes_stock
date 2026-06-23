import 'package:flutter/material.dart';
import '../../core/app_strings.dart';

class ConfirmDialog {
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '',
    String cancelText = '',
    Color confirmColor = Colors.red,
    IconData? icon,
  }) {
    final cText = confirmText.isNotEmpty ? confirmText : S.t('action_confirm');
    final aText = cancelText.isNotEmpty ? cancelText : S.t('action_cancel');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: confirmColor),
              const SizedBox(width: 8),
            ],
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(aText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(cText),
          ),
        ],
      ),
    );
  }
}
