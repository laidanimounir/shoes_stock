import 'package:flutter/material.dart';
import '../../services/shift_service.dart';
import '../../core/app_session.dart';
import '../../models/shift_model.dart';
import '../auth/login_screen.dart';

class CloseShiftScreen extends StatefulWidget {
  final ShiftModel shift;
  const CloseShiftScreen({super.key, required this.shift});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final _closingController = TextEditingController();
  final _notesController = TextEditingController();
  final _shiftService = ShiftService();
  
  bool _isLoading = false;
  double _discrepancy = 0.0;
  bool _hasInput = false;

  void _calculateDiscrepancy(String value) {
    if (value.isEmpty) {
      setState(() {
        _discrepancy = 0.0;
        _hasInput = false;
      });
      return;
    }
    final closing = double.tryParse(value) ?? 0.0;
    // Expected amount calculated by DB, but we get the shift object. Wait, ShiftModel might not contain the live expected_amount yet.
    // The prompt says "expected_amount from ShiftModel", but actually we don't have sales stored continuously in ShiftModel unless refreshed.
    // Wait, the user said "live calculate discrepancy = closing - expected_amount from ShiftModel". 
    // I will use widget.shift.expectedAmount or we just use 0 if null.
    final expected = widget.shift.expectedAmount ?? widget.shift.openingAmount;
    setState(() {
      _discrepancy = closing - expected;
      _hasInput = true;
    });
  }

  Future<void> _closeShift() async {
    final closingText = _closingController.text.trim();
    if (closingText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال المبلغ الفعلي'), backgroundColor: Colors.red),
      );
      return;
    }

    final closing = double.tryParse(closingText);
    if (closing == null || closing < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final summary = await _shiftService.closeShift(
        widget.shift.id,
        closing,
        notes: _notesController.text.trim(),
      );
      
      AppSession.currentShiftId = null;

      if (mounted) {
        // Show summary dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('ملخص الوردية', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المبلغ الابتدائي: ${summary.opening} DA'),
                Text('إجمالي المبيعات: ${summary.sales} DA'),
                Text('المبلغ المتوقع: ${summary.expected} DA'),
                Text('المبلغ الفعلي: ${summary.closing} DA'),
                Text(
                  'الفرق: ${summary.discrepancy > 0 ? "+" : ""}${summary.discrepancy} DA',
                  style: TextStyle(
                    color: summary.discrepancy == 0 ? Colors.green : (summary.discrepancy > 0 ? Colors.green : Colors.red),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('موافق وخروج'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we couldn't fetch live expected amount in constructor, we fallback to opening amount.
    final expectedAmount = widget.shift.expectedAmount ?? widget.shift.openingAmount;

    return Scaffold(
      backgroundColor: Colors.indigo[50],
      appBar: AppBar(
        title: const Text('إغلاق الوردية'),
        centerTitle: true,
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_clock, size: 64, color: Colors.indigo),
                    const SizedBox(height: 24),
                    ListTile(
                      title: const Text('المبلغ الابتدائي'),
                      trailing: Text('${widget.shift.openingAmount} DA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('المبلغ المتوقع (الافتراضي بدون مبيعات في هذه الشاشة)'),
                      trailing: Text('$expectedAmount DA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _closingController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ الفعلي في الصندوق (DA)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      onChanged: _calculateDiscrepancy,
                    ),
                    if (_hasInput) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _discrepancy == 0 ? Colors.green[50] : (_discrepancy > 0 ? Colors.green[50] : Colors.red[50]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _discrepancy == 0 ? Colors.green : (_discrepancy > 0 ? Colors.green : Colors.red),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _discrepancy == 0 ? 'مطابق ✓' : (_discrepancy > 0 ? 'فائض' : 'عجز'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _discrepancy == 0 ? Colors.green : (_discrepancy > 0 ? Colors.green : Colors.red),
                              ),
                            ),
                            Text(
                              '${_discrepancy > 0 ? "+" : ""}${_discrepancy.toStringAsFixed(2)} DA',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _discrepancy == 0 ? Colors.green : (_discrepancy > 0 ? Colors.green : Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _closeShift,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('إغلاق الوردية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
