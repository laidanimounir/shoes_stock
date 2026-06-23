import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_session.dart';
import '../local_db/isar_service.dart';
import '../local_db/collections/size_run_local.dart';

class SizeRunService {
  static final instance = SizeRunService._();
  SizeRunService._();

  Future<List<SizeRunLocal>> getSizeRuns(String productId) async {
    final isar = await IsarService.getInstance();
    return isar.sizeRunLocals
        .filter()
        .productIdEqualTo(productId)
        .findAll();
  }

  Future<void> updateSizeRun(String sizeRunId, Map<String, int> sizes) async {
    if (!AppSession.isOfflineMode) {
      try {
        await Supabase.instance.client
            .from('size_runs')
            .update({'sizes': sizes})
            .eq('id', sizeRunId);
      } on PostgrestException catch (e) {
        debugPrint('[SizeRunService] Update error: ${e.message}');
      } catch (e, stackTrace) {
        debugPrint('[SizeRunService] Update error: $e');
        debugPrint('[SizeRunService] StackTrace: $stackTrace');
      }
    }

    final isar = await IsarService.getInstance();
    final local = await isar.sizeRunLocals
        .filter()
        .supabaseIdEqualTo(sizeRunId)
        .findFirst();
    if (local != null) {
      await isar.writeTxn(() async {
        local.updateSizes(sizes);
        local.updatedAt = DateTime.now();
        await isar.sizeRunLocals.put(local);
      });
    }
  }

  Future<void> syncSizeRuns() async {
    if (AppSession.isOfflineMode) return;

    final storeId = AppSession.currentStoreId;
    if (storeId == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('size_runs')
          .select()
          .eq('store_id', storeId);
      await _syncSizeRunsFromRows(rows);
    } on PostgrestException catch (e) {
      debugPrint('[SizeRunService] Sync error: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[SizeRunService] Sync error: $e');
      debugPrint('[SizeRunService] StackTrace: $stackTrace');
    }
  }

  Future<void> _syncSizeRunsFromRows(List<dynamic> rows) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      final storeId = AppSession.currentStoreId;
      if (storeId == null) return;
      await isar.sizeRunLocals
          .filter()
          .storeIdEqualTo(storeId)
          .deleteAll();

      for (final row in rows) {
        final j = Map<String, dynamic>.from(row as Map);
        final local = SizeRunLocal()
          ..supabaseId = j['id'] as String
          ..productId = j['product_id'] as String
          ..color = j['color'] as String?
          ..sizesJson = jsonEncode(j['sizes'])
          ..storeId = j['store_id'] as String
          ..updatedAt = _parseDate(j['updated_at']);
        await isar.sizeRunLocals.put(local);
      }
    });
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    return DateTime.tryParse(val.toString());
  }
}
