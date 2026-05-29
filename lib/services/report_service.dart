import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:barcode/barcode.dart' as bc;
import '../core/app_strings.dart';

class BarcodeItem {
  final String variantId;
  final String barcode;
  final String productName;
  final String size;
  final String color;
  final double price;
  final int quantity;

  BarcodeItem({
    required this.variantId,
    required this.barcode,
    required this.productName,
    required this.size,
    required this.color,
    required this.price,
    required this.quantity,
  });
}

class ReportService {
  static final instance = ReportService._();
  ReportService._();

  Future<void> generateCashierSessionPdf(Map<String, dynamic> report, {String? userName}) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final totalSales = (report['total_sales'] as num?)?.toInt() ?? 0;
    final totalRevenue = (report['total_revenue'] as num?)?.toDouble() ?? 0;
    final avgDiscount = (report['avg_discount'] as num?)?.toDouble() ?? 0;
    final totalRefunds = (report['total_refunds'] as num?)?.toInt() ?? 0;
    final refundAmount = (report['refund_amount'] as num?)?.toDouble() ?? 0;
    final totalInvoices = (report['total_invoices'] as num?)?.toInt() ?? 0;
    final cashCollected = (report['cash_collected'] as num?)?.toDouble() ?? 0;
    final creditGiven = (report['credit_given'] as num?)?.toDouble() ?? 0;
    final topProduct = report['top_product_name'] as String? ?? '';
    final topProductQty = (report['top_product_qty'] as num?)?.toInt() ?? 0;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(text: 'Rapport de Caisse - $dateStr'),
        if (userName != null) pw.Paragraph(text: 'Caissier: $userName'),
        pw.SizedBox(height: 8),
        pw.Paragraph(text: 'Ventes: $totalSales'),
        pw.Paragraph(text: 'Revenu total: ${totalRevenue.toStringAsFixed(2)} ${S.t('misc_currency')}'),
        pw.Paragraph(text: 'Remise moyenne: ${avgDiscount.toStringAsFixed(1)}%'),
        pw.SizedBox(height: 8),
        pw.Paragraph(text: 'Factures: $totalInvoices'),
        pw.Paragraph(text: 'Remboursements: $totalRefunds (${refundAmount.toStringAsFixed(2)} ${S.t('misc_currency')})'),
        pw.SizedBox(height: 8),
        pw.Paragraph(text: 'Espèces encaissées: ${cashCollected.toStringAsFixed(2)} ${S.t('misc_currency')}'),
        pw.Paragraph(text: 'Crédit accordé: ${creditGiven.toStringAsFixed(2)} ${S.t('misc_currency')}'),
        if (topProduct.isNotEmpty)
          pw.Paragraph(text: 'Top produit: $topProduct ($topProductQty)'),
      ],
    ));

    final file = await _savePdf(pdf, 'rapport_caissier');
    await _share(file, text: 'Rapport de caisse $dateStr');
  }

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

  Future<Uint8List> generateEndOfDayPdf(Map<String, dynamic> data, String storeName, DateTime date) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(date);
    final currency = S.t('misc_currency');

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        children: [
          pw.Header(text: 'Rapport de Clôture'),
          pw.Paragraph(text: 'Magasin: $storeName'),
          pw.Paragraph(text: 'Date: $dateStr'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Indicateur', 'Valeur'],
            data: [
              ['Revenu total', '${(data['total_revenue'] as num?)?.toInt() ?? 0} $currency'],
              ['Nombre de ventes', '${data['total_sales'] ?? 0}'],
              ['Dépenses totales', '${(data['total_expenses'] as num?)?.toInt() ?? 0} $currency'],
              ['Profit net', '${(data['net_profit'] as num?)?.toInt() ?? 0} $currency'],
              ['Factures', '${data['total_invoices'] ?? 0}'],
              ['Ventes cash', '${(data['cash_sales'] as num?)?.toInt() ?? 0} $currency'],
              ['Ventes crédit', '${(data['credit_sales'] as num?)?.toInt() ?? 0} $currency'],
              ['Remboursements', '${(data['total_refunds'] as num?)?.toInt() ?? 0} $currency'],
              ['Nouveaux clients', '${data['new_customers'] ?? 0}'],
              ['Dettes recouvrées', '${(data['debt_collected'] as num?)?.toInt() ?? 0} $currency'],
              ['Top produit', '${data['top_product_name'] ?? '-'} (${data['top_product_qty'] ?? 0})'],
            ],
          ),
        ],
      ),
    ));

    return await pdf.save();
  }

  Future<void> showEndOfDayReportDialog(BuildContext context, String? storeId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final supabase = Supabase.instance.client;
      final res = await supabase.rpc('get_end_of_day_report', params: {
        'p_store_id': storeId,
      });

      String storeName = 'Tous les magasins';
      if (storeId != null) {
        final storeRes = await supabase.from('stores').select('name').eq('id', storeId).maybeSingle();
        storeName = storeRes?['name'] ?? '';
      }

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        _showDialog(context, res as Map<String, dynamic>, storeName);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDialog(BuildContext context, Map<String, dynamic> data, String storeName) {
    final currency = S.t('misc_currency');
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rapport de Clôture', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Magasin: $storeName', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Date: $dateStr'),
              const Divider(),
              _kpiLine('Revenu total', '${(data['total_revenue'] as num?)?.toInt() ?? 0} $currency', Colors.green),
              _kpiLine('Nombre de ventes', '${data['total_sales'] ?? 0}', Colors.blue),
              _kpiLine('Dépenses totales', '${(data['total_expenses'] as num?)?.toInt() ?? 0} $currency', Colors.red),
              _kpiLine('Profit net', '${(data['net_profit'] as num?)?.toInt() ?? 0} $currency', Colors.indigo),
              const Divider(),
              Text('Top produit: ${data['top_product_name'] ?? '-'} (${data['top_product_qty'] ?? 0} vendus)',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Divider(),
              _kpiLine('Factures', '${data['total_invoices'] ?? 0}', Colors.grey),
              _kpiLine('Ventes cash', '${(data['cash_sales'] as num?)?.toInt() ?? 0} $currency', Colors.teal),
              _kpiLine('Ventes crédit', '${(data['credit_sales'] as num?)?.toInt() ?? 0} $currency', Colors.orange),
              _kpiLine('Remboursements', '${(data['total_refunds'] as num?)?.toInt() ?? 0} $currency', Colors.red),
              _kpiLine('Nouveaux clients', '${data['new_customers'] ?? 0}', Colors.blue),
              _kpiLine('Dettes recouvrées', '${(data['debt_collected'] as num?)?.toInt() ?? 0} $currency', Colors.green),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final pdfBytes = await generateEndOfDayPdf(data, storeName, DateTime.now());
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/rapport_cloture_${DateTime.now().millisecondsSinceEpoch}.pdf');
              await file.writeAsBytes(pdfBytes);
              await _share(file, text: 'Rapport de Clôture $dateStr');
            },
            child: const Text('Partager'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _kpiLine(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Future<Uint8List> generateInventoryPdf(List<Map<String, dynamic>> items, String storeName) async {
    final pdf = pw.Document();

    double totalValue = 0;
    int totalStock = 0;

    for (final item in items) {
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final buyPrice = (item['product_variants']?['buy_price'] as num?)?.toDouble() ?? 0.0;
      totalStock += qty;
      totalValue += qty * buyPrice;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        pw.Header(text: 'Inventory Report - $storeName'),
        pw.Paragraph(text: 'Total Items: ${items.length}'),
        pw.Paragraph(text: 'Total Stock Units: $totalStock'),
        pw.Paragraph(text: 'Total Value: ${totalValue.toStringAsFixed(2)} ${S.t('misc_currency')}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Product', 'Variant', 'Barcode', 'Size', 'Color', 'Stock', 'Buy Price', 'Sell Price', 'Value'],
          data: items.map((item) {
            final variant = item['product_variants'] ?? {};
            final product = variant['products'] ?? {};
            final qty = (item['quantity'] as num?)?.toInt() ?? 0;
            final buyPrice = (variant['buy_price'] as num?)?.toDouble() ?? 0.0;
            final sellPrice = (variant['sell_price'] as num?)?.toDouble() ?? 0.0;
            final value = qty * buyPrice;
            return [
              product['name'] ?? '',
              '${variant['size'] ?? ''} / ${variant['color'] ?? ''}',
              variant['barcode'] ?? '',
              '${variant['size'] ?? ''}',
              '${variant['color'] ?? ''}',
              '$qty',
              buyPrice.toStringAsFixed(2),
              sellPrice.toStringAsFixed(2),
              value.toStringAsFixed(2),
            ];
          }).toList(),
        ),
      ],
    ));

    return await pdf.save();
  }

  Future<Uint8List> generateInventoryExcel(List<Map<String, dynamic>> items) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('Product,Variant,Barcode,Size,Color,Stock,Buy Price,Sell Price,Value');

    for (final item in items) {
      final variant = item['product_variants'] ?? {};
      final product = variant['products'] ?? {};
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final buyPrice = (variant['buy_price'] as num?)?.toDouble() ?? 0.0;
      final sellPrice = (variant['sell_price'] as num?)?.toDouble() ?? 0.0;
      final value = qty * buyPrice;

      buffer.writeln(
        '"${_csvEscape(product['name'] ?? '')}","${_csvEscape('${variant['size'] ?? ''} / ${variant['color'] ?? ''}')}","${_csvEscape(variant['barcode'] ?? '')}","${_csvEscape('${variant['size'] ?? ''}')}","${_csvEscape('${variant['color'] ?? ''}')}","$qty","${buyPrice.toStringAsFixed(2)}","${sellPrice.toStringAsFixed(2)}","${value.toStringAsFixed(2)}"',
      );
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  String _csvEscape(String value) => value.replaceAll('"', '""');

  Future<Uint8List> generateBulkBarcodePdf(List<BarcodeItem> items) async {
    final pdf = pw.Document();

    final expanded = <BarcodeItem>[];
    for (final item in items) {
      for (int i = 0; i < item.quantity; i++) {
        expanded.add(item);
      }
    }
    if (expanded.isEmpty) return pdf.save();

    const double labelWidthMm = 80;
    const double labelHeightMm = 40;
    const int columns = 2;
    const int rowsPerPage = 7;

    for (int i = 0; i < expanded.length; i += columns * rowsPerPage) {
      final end = (i + columns * rowsPerPage > expanded.length)
          ? expanded.length
          : i + columns * rowsPerPage;
      final pageItems = expanded.sublist(i, end);
      final rowCount = (pageItems.length / columns).ceil();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          build: (_) => pw.Column(
            children: List.generate(rowCount, (r) {
              return pw.SizedBox(
                height: labelHeightMm * PdfPageFormat.mm,
                child: pw.Row(
                  children: List.generate(columns, (c) {
                    final idx = r * columns + c;
                    if (idx >= pageItems.length) {
                      return pw.Expanded(child: pw.SizedBox());
                    }
                    return pw.Expanded(child: _buildBarcodeLabel(pageItems[idx]));
                  }),
                ),
              );
            }),
          ),
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _buildBarcodeLabel(BarcodeItem item) {
    final code128 = bc.Barcode.code128();
    final svg = code128.toSvg(item.barcode, width: 200, height: 80);

    return pw.Container(
      margin: const pw.EdgeInsets.all(1),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(item.productName,
            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
          pw.SizedBox(height: 1),
          pw.Expanded(
            child: pw.Center(
              child: pw.SvgImage(svg: svg),
            ),
          ),
          pw.Text(item.barcode,
            style: pw.TextStyle(fontSize: 5),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${item.size} / ${item.color}',
                style: const pw.TextStyle(fontSize: 4),
              ),
              pw.Text('${item.price.toStringAsFixed(0)} DA',
                style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}