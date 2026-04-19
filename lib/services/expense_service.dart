import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../core/app_session.dart';
import '../core/sync_engine.dart';
import '../local_db/isar_service.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/collections/expense_local.dart';
import '../local_db/collections/expense_category_local.dart';

/// Offline-aware expense service.
/// Online path → Supabase RPC / queries.
/// Offline path → write to Isar + enqueue for later sync.
class ExpenseService {
  static final instance = ExpenseService._();
  ExpenseService._();

  final _client = Supabase.instance.client;

  // ══════════════════════════════════════════
  // Add Expense
  // ══════════════════════════════════════════

  Future<Map<String, dynamic>> addExpense({
    required String storeId,
    String? categoryId,
    required double amount,
    String? description,
    required String paymentMethod,
    required DateTime expenseDate,
  }) async {
    // ── ONLINE PATH ──
    if (!AppSession.isOfflineMode) {
      final result = await _client.rpc('add_expense', params: {
        'p_category_id': categoryId,
        'p_amount': amount,
        'p_description': description ?? '',
        'p_payment_method': paymentMethod,
        'p_store_id': storeId,
        'p_expense_date': expenseDate.toIso8601String().split('T').first,
      });
      return {'success': true, 'expense_id': result};
    }

    // ── OFFLINE PATH ──
    final isar = await IsarService.getInstance();

    final expense = ExpenseLocal()
      ..supabaseId = null
      ..categoryId = categoryId
      ..amount = amount
      ..description = description
      ..paymentMethod = paymentMethod
      ..storeId = storeId
      ..userId = AppSession.currentUserId
      ..expenseDate = expenseDate
      ..createdAt = DateTime.now()
      ..synced = false;

    late int localId;
    await isar.writeTxn(() async {
      localId = await isar.expenseLocals.put(expense);
    });

    await SyncEngine.instance.enqueue(
      SyncOperationType.createExpense,
      {
        'p_category_id': categoryId,
        'p_amount': amount,
        'p_description': description ?? '',
        'p_payment_method': paymentMethod,
        'p_store_id': storeId,
        'p_expense_date': expenseDate.toIso8601String().split('T').first,
      },
    );

    return {'success': true, 'expense_id': 'local_$localId'};
  }

  // ══════════════════════════════════════════
  // Fetch Expenses
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchExpenses(
    String storeId, {
    DateTime? from,
    DateTime? to,
    String? categoryId,
  }) async {
    // ── ONLINE PATH ──
    if (!AppSession.isOfflineMode) {
      try {
        var query = _client
            .from('expenses')
            .select('*, expense_categories(name)')
            .eq('store_id', storeId);

        if (from != null) {
          query = query.gte('expense_date', from.toIso8601String().split('T').first);
        }
        if (to != null) {
          query = query.lte('expense_date', to.toIso8601String().split('T').first);
        }
        if (categoryId != null) {
          query = query.eq('category_id', categoryId);
        }

        final res = await query.order('expense_date', ascending: false);
        return List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Error fetching expenses: $e');
        return [];
      }
    }

    // ── OFFLINE PATH ──
    final isar = await IsarService.getInstance();
    var q = isar.expenseLocals.filter().storeIdEqualTo(storeId);

    final results = await q.sortByExpenseDateDesc().findAll();

    // Load categories for name lookup
    final categories = await isar.expenseCategoryLocals.where().findAll();
    final catMap = {for (var c in categories) c.supabaseId: c.name};

    return results
        .where((e) {
          if (from != null && e.expenseDate.isBefore(from)) return false;
          if (to != null && e.expenseDate.isAfter(to)) return false;
          if (categoryId != null && e.categoryId != categoryId) return false;
          return true;
        })
        .map((e) => {
              'id': e.supabaseId ?? 'local_${e.isarId}',
              'category_id': e.categoryId,
              'amount': e.amount,
              'description': e.description,
              'payment_method': e.paymentMethod,
              'store_id': e.storeId,
              'user_id': e.userId,
              'expense_date': e.expenseDate.toIso8601String().split('T').first,
              'created_at': e.createdAt?.toIso8601String(),
              'expense_categories': e.categoryId != null
                  ? {'name': catMap[e.categoryId] ?? 'Inconnue'}
                  : null,
            })
        .toList();
  }

  // ══════════════════════════════════════════
  // Fetch Categories
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchCategories(String storeId) async {
    // ── ONLINE PATH ──
    if (!AppSession.isOfflineMode) {
      try {
        final res = await _client
            .from('expense_categories')
            .select()
            .eq('store_id', storeId)
            .order('name');
        return List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Error fetching categories: $e');
        return [];
      }
    }

    // ── OFFLINE PATH ──
    final isar = await IsarService.getInstance();
    final results = await isar.expenseCategoryLocals
        .filter()
        .storeIdEqualTo(storeId)
        .findAll();

    return results
        .map((c) => {
              'id': c.supabaseId,
              'name': c.name,
              'store_id': c.storeId,
            })
        .toList();
  }

  // ══════════════════════════════════════════
  // Add Category (online only)
  // ══════════════════════════════════════════

  Future<void> addCategory({
    required String name,
    required String storeId,
  }) async {
    await _client.from('expense_categories').insert({
      'name': name,
      'store_id': storeId,
    });
  }
}
