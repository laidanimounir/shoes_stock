import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import '../../services/shift_service.dart';
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/shift_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/user_profile_local.dart';
import '../../core/app_strings.dart';

class EndOfDayReport extends StatefulWidget {
  final DateTime date;
  final String? shiftId;
  
  const EndOfDayReport({super.key, required this.date, this.shiftId});

  @override
  State<EndOfDayReport> createState() => _EndOfDayReportState();
}

class _EndOfDayReportState extends State<EndOfDayReport> {
  final _supabase = Supabase.instance.client;
  final _shiftService = ShiftService();
  
  bool _isLoading = true;
  double _openingAmount = 0.0;
  double _totalSales = 0.0;
  
  // For inline shift closing
  bool _isClosing = false;
  final _actualAmountController = TextEditingController();
  final _notesController = TextEditingController();
  double _discrepancy = 0.0;
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(hours: 24));
      
      final storeId = AppSession.currentStoreId;
      if (storeId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (widget.shiftId != null) {
        final shift = await isar.shiftLocals
            .filter()
            .supabaseIdEqualTo(widget.shiftId!)
            .findFirst();
        if (shift != null) {
          _openingAmount = shift.openingAmount;
        }
      }

      final invoices = await isar.invoiceLocals
          .filter()
          .storeIdEqualTo(storeId)
          .statusEqualTo('paid')
          .createdAtBetween(todayStart, todayEnd)
          .findAll();
          
      _totalSales = invoices.fold<double>(
          0.0, (sum, inv) => sum + inv.totalAmount);

      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(hours: 1)); // UTC+1 → UTC
      final todayEnd = todayStart.add(const Duration(hours: 24));
      
      final user = _supabase.auth.currentUser;
      final profile = await _supabase.from('user_profiles').select('store_id').eq('id', user!.id).single();
      final storeId = profile['store_id'];

      if (widget.shiftId != null) {
        final shiftRes = await _supabase.from('shifts').select('opening_amount, status').eq('id', widget.shiftId!).single();
        _openingAmount = (shiftRes['opening_amount'] as num?)?.toDouble() ?? 0.0;
      }

      final invoicesRes = await _supabase.from('invoices')
          .select('total_amount')
          .eq('store_id', storeId)
          .eq('status', 'paid')
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String());
          
      _totalSales = invoicesRes.fold<double>(
          0.0, (sum, row) => sum + (row['total_amount'] as num).toDouble());

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _calculateDiscrepancy(String value) {
    if (value.isEmpty) {
      setState(() {
        _discrepancy = 0.0;
        _hasInput = false;
      });
      return;
    }
    final closing = double.tryParse(value) ?? 0.0;
    final expected = _openingAmount + _totalSales;
    setState(() {
      _discrepancy = closing - expected;
      _hasInput = true;
    });
  }

  Future<void> _closeShift() async {
    final closingText = _actualAmountController.text.trim();
    if (closingText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('shift_actual_amount_required')), backgroundColor: Colors.red));
      return;
    }

    final closing = double.tryParse(closingText);
    if (closing == null || closing < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('shift_error_amount')), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isClosing = true);
    try {
      await _shiftService.closeShift(
        widget.shiftId!,
        closing,
        notes: _notesController.text.trim(),
      );
      
      AppSession.currentShiftId = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('shift_close_success')), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isClosing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(widget.date);

    return AlertDialog(
      title: Column(
        children: [
          const Icon(Icons.assessment, size: 48, color: Colors.indigo),
          const SizedBox(height: 8),
          Text(S.t('label_daily_report'), textAlign: TextAlign.center),
          Text(formattedDate, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: widget.shiftId != null ? _buildCaseA() : _buildCaseB(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.t('label_close'), style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildCaseA() {
    final expected = _openingAmount + _totalSales;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRow(S.t('shift_initial_amount'), '$_openingAmount DA', Colors.black87),
        const Divider(),
        _buildRow(S.t('shift_total_sales'), '$_totalSales DA', Colors.green),
        const Divider(),
        _buildRow(S.t('shift_expected_amount'), '$expected DA', Colors.indigo, isBold: true),
        
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(S.t('shift_close_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextFormField(
                controller: _actualAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: S.t('shift_actual_amount'),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: _calculateDiscrepancy,
              ),
              if (_hasInput) ...[
                const SizedBox(height: 8),
                Text(
                  '${S.t('shift_discrepancy')}: ${_discrepancy > 0 ? "+" : ""}${_discrepancy.toStringAsFixed(2)} DA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _discrepancy == 0 ? Colors.green : (_discrepancy > 0 ? Colors.green : Colors.red),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: S.t('shift_notes'),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isClosing ? null : _closeShift,
                icon: _isClosing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.lock),
                label: Text(S.t('shift_close_btn')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaseB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
              const SizedBox(height: 8),
              Text(S.t('shift_warning_no_caisse'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              Text(S.t('shift_no_caisse'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildRow(S.t('shift_total_sales_recorded'), '$_totalSales DA', Colors.green, isBold: true),
      ],
    );
  }

  Widget _buildRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Text(value, style: TextStyle(fontSize: isBold ? 18 : 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
