import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/app_strings.dart';

class ReceiptService {
  static final instance = ReceiptService._();
  ReceiptService._();

  Future<Uint8List> generateReceipt({
    required String storeName,
    required String invoiceNumber,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    double discountPercent = 0,
    double discountAmount = 0,
    required double total,
    required double paid,
    required double change,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.nunitoRegular();
    final boldFont = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            children: [
              pw.Text(storeName,
                  style: pw.TextStyle(font: boldFont, fontSize: 16)),
              pw.SizedBox(height: 4),
              pw.Text(S.t('pos_title'),
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Text('${S.t('pos_invoice')} $invoiceNumber',
                  style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                  style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(S.t('label_product'),
                      style: pw.TextStyle(font: boldFont, fontSize: 9)),
                  pw.Text(S.t('label_qty_short'),
                      style: pw.TextStyle(font: boldFont, fontSize: 9)),
                  pw.Text(S.t('label_unit_price'),
                      style: pw.TextStyle(font: boldFont, fontSize: 9)),
                  pw.Text(S.t('label_total'),
                      style: pw.TextStyle(font: boldFont, fontSize: 9)),
                ],
              ),
              pw.Divider(),
              ...items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            '${item['product_name']} (${item['size']}/${item['color']})',
                            style: pw.TextStyle(font: font, fontSize: 8),
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.SizedBox(
                          width: 20,
                          child: pw.Text('${item['quantity']}',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: font, fontSize: 8)),
                        ),
                        pw.SizedBox(width: 4),
                        pw.SizedBox(
                          width: 30,
                          child: pw.Text(
                              '${item['unit_price']} ${S.t('misc_currency')}',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: font, fontSize: 8)),
                        ),
                        pw.SizedBox(width: 4),
                        pw.SizedBox(
                          width: 35,
                          child: pw.Text(
                              '${item['total_price']} ${S.t('misc_currency')}',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: font, fontSize: 8)),
                        ),
                      ],
                    ),
                  )),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(S.t('pos_discount_subtotal'),
                      style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text('${subtotal.toStringAsFixed(0)} ${S.t('misc_currency')}',
                      style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              if (discountAmount > 0 || discountPercent > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        '${S.t('pos_discount_remise_lbl')}${discountPercent > 0 ? ' ($discountPercent%)' : ''}',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text('-${discountAmount.toStringAsFixed(0)} ${S.t('misc_currency')}',
                        style: pw.TextStyle(
                            font: font, fontSize: 9, color: PdfColors.red)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(S.t('pos_total'),
                      style: pw.TextStyle(font: boldFont, fontSize: 11)),
                  pw.Text('${total.toStringAsFixed(0)} ${S.t('misc_currency')}',
                      style: pw.TextStyle(font: boldFont, fontSize: 11)),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(S.t('pos_amount_received'),
                      style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text('${paid.toStringAsFixed(0)} ${S.t('misc_currency')}',
                      style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(S.t('pos_change_label'),
                      style: pw.TextStyle(font: font, fontSize: 9)),
                  pw.Text('${change.toStringAsFixed(0)} ${S.t('misc_currency')}',
                      style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 4),
              pw.Text(S.t('auth_welcome'),
                  style: pw.TextStyle(font: font, fontSize: 8)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> printReceipt(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  Future<void> shareReceipt(Uint8List pdfBytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> showReceiptBottomSheet(
    BuildContext context, {
    required String storeName,
    required String invoiceNumber,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    double discountPercent = 0,
    double discountAmount = 0,
    required double total,
    required double paid,
    required double change,
  }) async {
    final pdfBytes = await generateReceipt(
      storeName: storeName,
      invoiceNumber: invoiceNumber,
      date: date,
      items: items,
      subtotal: subtotal,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      total: total,
      paid: paid,
      change: change,
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.receipt_long, size: 48, color: Colors.indigo[900]),
            const SizedBox(height: 12),
            Text(S.t('pos_print_title'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: Text(S.t('action_print')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  printReceipt(pdfBytes);
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: Text(S.t('action_export')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  shareReceipt(pdfBytes, 'receipt_$invoiceNumber');
                },
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t('action_close')),
            ),
          ],
        ),
      ),
    );
  }
}
