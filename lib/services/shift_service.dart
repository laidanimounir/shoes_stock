import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shift_model.dart';

class ShiftService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ShiftModel?> getActiveShift(String storeId) async {
    try {
      final response = await _supabase.rpc('get_active_shift', params: {
        'p_store_id': storeId,
      });

      if (response != null && response is List && response.isNotEmpty) {
        // the RPC returns a table which might be mapped to a List of maps
        // get_active_shift returns only id, opening_amount, opened_at.
        // We might need to fetch the full shift object to map it to ShiftModel
        final shiftId = response[0]['id'];
        final shiftData = await _supabase
            .from('shifts')
            .select()
            .eq('id', shiftId)
            .single();
        return ShiftModel.fromJson(shiftData);
      }
      return null;
    } catch (e) {
      if (e is PostgrestException && e.code == '42501') {
        throw 'ACCESS_DENIED';
      }
      rethrow;
    }
  }

  Future<String> openShift(String storeId, double openingAmount) async {
    try {
      final response = await _supabase.rpc('open_shift', params: {
        'p_store_id': storeId,
        'p_opening_amount': openingAmount,
      });
      return response as String;
    } catch (e) {
      if (e is PostgrestException) {
        if (e.message.contains('SHIFT_ALREADY_OPEN')) {
          throw 'SHIFT_ALREADY_OPEN';
        } else if (e.code == '42501') {
          throw 'ACCESS_DENIED';
        }
      }
      rethrow;
    }
  }

  Future<ShiftSummary> closeShift(String shiftId, double closingAmount, {String? notes}) async {
    try {
      final response = await _supabase.rpc('close_shift', params: {
        'p_shift_id': shiftId,
        'p_closing_amount': closingAmount,
        'p_notes': notes,
      });
      return ShiftSummary.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      if (e is PostgrestException && e.code == '42501') {
        throw 'ACCESS_DENIED';
      }
      rethrow;
    }
  }
}
