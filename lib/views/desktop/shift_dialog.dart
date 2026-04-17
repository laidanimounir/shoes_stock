import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/shift_service.dart';
import '../../core/app_session.dart';

class ShiftDialog extends StatefulWidget {
  final String storeId;
  const ShiftDialog({super.key, required this.storeId});

  @override
  State<ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<ShiftDialog> {
  final _amountController = TextEditingController();
  final _shiftService = ShiftService();
  bool _isLoading = false;

  Future<void> _handleShiftAction(double amount) async {
    setState(() => _isLoading = true);
    try {
      final shiftId = await _shiftService.openShift(widget.storeId, amount);
      AppSession.currentShiftId = shiftId;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (e == 'SHIFT_ALREADY_OPEN') {
        try {
          final shift = await _shiftService.getActiveShift(widget.storeId);
          if (shift != null) {
            AppSession.currentShiftId = shift.id;
          }
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } catch (fetchErr) {
          _showError('Erreur de récupération de la caisse / خطأ في استرجاع الوردية');
        }
      } else {
        _showError('Erreur d\'ouverture de caisse / حدث خطأ أثناء فتح الوردية: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _onOpenShiftPressed() {
    final text = _amountController.text.trim();
    if (text.isEmpty) {
      _showError('Veuillez entrer un montant / الرجاء إدخال المبلغ');
      return;
    }
    final amount = double.tryParse(text);
    if (amount == null || amount < 0) {
      _showError('Montant invalide / مبلغ غير صحيح');
      return;
    }
    _handleShiftAction(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ouverture de caisse / فتح الوردية', textAlign: TextAlign.center),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Entrez le montant initial en caisse pour aujourd\'hui\nأدخل المبلغ الموجود في الصندوق لبدء يوم العمل',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Montant initial (DA) / المبلغ الابتدائي',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isLoading ? null : () => _handleShiftAction(0),
          child: const Text('Sans caisse / بدون وردية'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onOpenShiftPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          child: const Text('Ouvrir la caisse / فتح الوردية'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}
