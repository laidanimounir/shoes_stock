import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../core/app_strings.dart';

class ReportService {
  static final instance = ReportService._();
  ReportService._();

  Future<File> _savePdf(pw.Document pdf, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> _share(File file, {String? text}) async {
    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  Future<void> generateDailySalesReport(DateTime date, String? storeId) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final res = await Supabase.instance.client
        .from('transactions')
        .select('*, invoices!inner(store_id, invoice_number, total_amount, paid_amount, payment_method), product_variants(size, color, products(name))')
        .gte('created_at', '${dateStr}T00:00:00')
        .lte('created_at', '${dateStr}T23:59:59');

    double total = 0;
    int count = 0;
    for (final t in res) {
      total += (t['total_price'] as num?)?.toDouble() ?? 0;
      count++;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(text: 'Rapport de Ventes - $dateStr'),
        pw.Paragraph(text: 'Total des ventes: ${total.toStringAsFixed(2)} ${S.t('misc_currency')}'),
        pw.Paragraph(text: 'Nombre de transactions: $count'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Produit', 'Taille', 'Couleur', 'Qté', 'Prix', 'Total'],
          data: res.map((t) => [
            t['product_variants']?['products']?['name'] ?? '',
            t['product_variants']?['size'] ?? '',
            t['product_variants']?['color'] ?? '',
            '${t['quantity'] ?? 0}',
            '${((t['unit_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
            '${((t['total_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
          ]).toList(),
        ),
      ],
    ));

    final file = await _savePdf(pdf, 'rapport_ventes');
    await _share(file, text: 'Rapport de ventes $dateStr');
  }

  Future<void> generateInventoryReport(String? storeId) async {
    final pdf = pw.Document();
    var qb = Supabase.instance.client
        .from('inventory')
        .select('quantity, stores(name), product_variants(size, color, buy_price, sell_price, products(name))');
    if (storeId != null) qb = qb.eq('store_id', storeId);
    final res = await qb.order('quantity', ascending: true);

    double totalValue = 0;
    int totalQty = 0;
    for (final item in res) {
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final buyPrice = item['product_variants']?['buy_price'] as num? ?? 0;
      totalValue += qty * (buyPrice.toDouble());
      totalQty += qty;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(text: "Rapport d'Inventaire"),
        pw.Paragraph(text: 'Stock total: $totalQty unités'),
        pw.Paragraph(text: 'Valeur totale (achat): ${totalValue.toStringAsFixed(2)} ${S.t('misc_currency')}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Produit', 'Taille', 'Couleur', 'Magasin', 'Qté', 'Prix Achat', 'Prix Vente'],
          data: res.map((item) => [
            item['product_variants']?['products']?['name'] ?? '',
            item['product_variants']?['size'] ?? '',
            item['product_variants']?['color'] ?? '',
            item['stores']?['name'] ?? '',
            '${item['quantity'] ?? 0}',
            '${((item['product_variants']?['buy_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
            '${((item['product_variants']?['sell_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
          ]).toList(),
        ),
      ],
    ));

    final file = await _savePdf(pdf, 'rapport_inventaire');
    await _share(file, text: "Rapport d'inventaire");
  }

  Future<void> generateDebtReport(String? storeId) async {
    final pdf = pw.Document();
    final res = await Supabase.instance.client
        .from('customers')
        .select('id, full_name, phone, balance')
        .gt('balance', 0)
        .eq('is_active', true)
        .order('balance', ascending: false);

    double totalDebt = 0;
    for (final c in res) {
      totalDebt += (c['balance'] as num?)?.toDouble() ?? 0;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(text: 'Rapport des Dettes Clients'),
        pw.Paragraph(text: 'Total des dettes: ${totalDebt.toStringAsFixed(2)} ${S.t('misc_currency')}'),
        pw.Paragraph(text: 'Nombre de clients: ${res.length}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Client', 'Téléphone', 'Solde dû'],
          data: res.map((c) => [
            c['full_name'] ?? '',
            c['phone'] ?? '',
            '${((c['balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ${S.t('misc_currency')}',
          ]).toList(),
        ),
      ],
    ));

    final file = await _savePdf(pdf, 'rapport_dettes');
    await _share(file, text: 'Rapport des dettes');
  }
}