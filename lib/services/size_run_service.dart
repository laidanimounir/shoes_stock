import 'dart:convert';
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
      await Supabase.instance.client
          .from('size_runs')
          .update({'sizes': sizes})
          .eq('id', sizeRunId);
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

    final rows = await Supabase.instance.client
        .from('size_runs')
        .select()
        .eq('store_id', storeId);

    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
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
