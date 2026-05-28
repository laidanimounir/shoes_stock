import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_strings.dart';

class ContactUtils {
  static String cleanPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
    if (cleaned.startsWith('00213')) {
      cleaned = '+213${cleaned.substring(5)}';
    } else if (cleaned.startsWith('0')) {
      cleaned = '+213${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+213$cleaned';
    }
    return cleaned;
  }

  static Future<void> sendWhatsApp(
    BuildContext context,
    String phone,
    String name,
    double balance,
  ) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('contact_no_phone')), backgroundColor: Colors.orange),
      );
      return;
    }
    final cleanedPhone = cleanPhone(phone).replaceAll('+', '');
    final message = S.t('contact_whatsapp_msg')
        .replaceAll('{name}', name)
        .replaceAll('{amount}', '${balance.toStringAsFixed(0)} ${S.t('misc_currency')}');
    final url = Uri.parse('https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> sendSMS(
    BuildContext context,
    String phone,
    String name,
    double balance,
  ) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('contact_no_phone')), backgroundColor: Colors.orange),
      );
      return;
    }
    final cleanedPhone = cleanPhone(phone);
    final message = S.t('contact_sms_msg')
        .replaceAll('{name}', name)
        .replaceAll('{amount}', '${balance.toStringAsFixed(0)} ${S.t('misc_currency')}');
    final url = Uri.parse('sms:$cleanedPhone?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
