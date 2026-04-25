import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/shift_service.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';

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
          _showError(S.t('shift_error_fetch'));
        }
      } else {
        _showError('${S.t('shift_error_open')}: $e');
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
      _showError(S.t('shift_initial_amount_required'));
      return;
    }
    final amount = double.tryParse(text);
    if (amount == null || amount < 0) {
      _showError(S.t('shift_error_amount'));
      return;
    }
    _handleShiftAction(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.t('shift_open_title'), textAlign: TextAlign.center),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.t('shift_open_msg'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: S.t('shift_initial_amount'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.money),
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
          child: Text(S.t('shift_no_caisse')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onOpenShiftPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          child: Text(S.t('shift_open_btn')),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}
