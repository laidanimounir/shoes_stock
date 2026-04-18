import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shift_model.dart';
import '../core/app_session.dart';
import '../local_db/isar_service.dart';
import '../local_db/collections/shift_local.dart';
import '../local_db/collections/sync_queue_item.dart';
import 'dart:convert';

class ShiftService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ShiftModel?> getActiveShift(String storeId) async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final localShift = await isar.shiftLocals
          .filter()
          .storeIdEqualTo(storeId)
          .statusEqualTo('open')
          .findAll()
          .then((list) => list.isNotEmpty ? list.first : null);
      if (localShift == null) return null;
      final shift = ShiftModel(
        id: localShift.supabaseId,
        storeId: localShift.storeId,
        cashierId: localShift.cashierId,
        openingAmount: localShift.openingAmount,
        openedAt: localShift.openedAt ?? DateTime.now(),
        status: localShift.status,
      );
      final shiftDate = shift.openedAt.toLocal();
      final today = DateTime.now();
      if (shiftDate.year != today.year ||
          shiftDate.month != today.month ||
          shiftDate.day != today.day) return null;
      return shift;
    }
    try {
      final response = await _supabase.rpc('get_active_shift', params: {
        'p_store_id': storeId,
      });
      if (response != null && response is List && response.isNotEmpty) {
        final shiftId = response[0]['id'];
        final shiftData = await _supabase
            .from('shifts')
            .select()
            .eq('id', shiftId)
            .single();
        final shift = ShiftModel.fromJson(shiftData);
        final shiftDate = shift.openedAt.toLocal();
        final today = DateTime.now();
        final isToday = shiftDate.year == today.year &&
            shiftDate.month == today.month &&
            shiftDate.day == today.day;
        if (!isToday) return null;
        return shift;
      }
      return null;
    } catch (e) {
      if (e is PostgrestException && e.code == '42501') throw 'ACCESS_DENIED';
      rethrow;
    }
  }

  Future<String> openShift(String storeId, double openingAmount) async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final existingList = await isar.shiftLocals
          .filter()
          .storeIdEqualTo(storeId)
          .statusEqualTo('open')
          .findAll();
      if (existingList.isNotEmpty) throw 'SHIFT_ALREADY_OPEN';

      final offlineId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      final userId = AppSession.currentUserId ?? 'unknown';
      final localShift = ShiftLocal()
        ..supabaseId = offlineId
        ..storeId = storeId
        ..cashierId = userId
        ..openingAmount = openingAmount
        ..openedAt = DateTime.now()
        ..status = 'open'
        ..synced = false;

      await isar.writeTxn(() async {
        await isar.shiftLocals.put(localShift);
        final queueItem = SyncQueueItem()
          ..operationType = 'open_shift'
          ..payloadJson = jsonEncode({
            'p_store_id': storeId,
            'p_opening_amount': openingAmount,
            'offline_id': offlineId,
            'cashier_id': userId,
            'opened_at': localShift.openedAt!.toIso8601String(),
          })
          ..status = 'pending'
          ..createdAt = DateTime.now();
        await isar.syncQueueItems.put(queueItem);
      });
      return offlineId;
    }
    try {
      final response = await _supabase.rpc('open_shift', params: {
        'p_store_id': storeId,
        'p_opening_amount': openingAmount,
      });
      return response as String;
    } catch (e) {
      if (e is PostgrestException) {
        if (e.message.contains('SHIFT_ALREADY_OPEN')) throw 'SHIFT_ALREADY_OPEN';
        if (e.code == '42501') throw 'ACCESS_DENIED';
      }
      rethrow;
    }
  }

  Future<ShiftSummary> closeShift(
    String shiftId,
    double closingAmount,
    String? notes,
  ) async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final results = await isar.shiftLocals
          .filter()
          .supabaseIdEqualTo(shiftId)
          .findAll();
      if (results.isEmpty) throw 'SHIFT_NOT_FOUND';
      final localShift = results.first;

      await isar.writeTxn(() async {
        localShift.status = 'closed';
        localShift.closingAmount = closingAmount;
        localShift.closedAt = DateTime.now();
        localShift.notes = notes;
        await isar.shiftLocals.put(localShift);

        final queueItem = SyncQueueItem()
          ..operationType = 'close_shift'
          ..payloadJson = jsonEncode({
            'p_shift_id': shiftId,
            'p_closing_amount': closingAmount,
            'p_notes': notes,
          })
          ..status = 'pending'
          ..createdAt = DateTime.now();
        await isar.syncQueueItems.put(queueItem);
      });

      return ShiftSummary(
        opening: localShift.openingAmount,
        sales: 0,
        expected: localShift.openingAmount,
        closing: closingAmount,
        discrepancy: closingAmount - localShift.openingAmount,
      );
    }
    try {
      final response = await _supabase.rpc('close_shift', params: {
        'p_shift_id': shiftId,
        'p_closing_amount': closingAmount,
        'p_notes': notes,
      });
      return ShiftSummary.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      if (e is PostgrestException && e.code == '42501') throw 'ACCESS_DENIED';
      rethrow;
    }
  }
}