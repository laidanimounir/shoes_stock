import 'package:flutter/material.dart';
import '../../core/app_session.dart';

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppSession.locale,
      builder: (context, locale, _) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.language),
          tooltip: '',
          onSelected: (lang) async {
            await AppSession.setLocale(lang);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'ar',
              child: Row(
                children: [
                  if (locale == 'ar') const Icon(Icons.check, size: 16),
                  if (locale != 'ar') const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  const Text('العربية'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'fr',
              child: Row(
                children: [
                  if (locale == 'fr') const Icon(Icons.check, size: 16),
                  if (locale != 'fr') const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  const Text('Français'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
