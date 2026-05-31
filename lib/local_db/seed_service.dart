
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_db/isar_service.dart';

import '../local_db/collections/store_local.dart';
import '../local_db/collections/user_profile_local.dart';
import '../local_db/collections/customer_local.dart';
import '../local_db/collections/supplier_local.dart';
import '../local_db/collections/product_local.dart';
import '../local_db/collections/product_variant_local.dart';
import '../local_db/collections/inventory_local.dart';
import '../local_db/collections/invoice_local.dart';
import '../local_db/collections/payment_local.dart';
import '../local_db/collections/transaction_local.dart';
import '../local_db/collections/expense_category_local.dart';
import '../local_db/collections/expense_local.dart';
import '../local_db/collections/sync_metadata.dart';


/// Downloads Supabase data into Isar for offline-first access.
class SeedService {
  SeedService._internal();
  static final SeedService instance = SeedService._internal();

  final _client = Supabase.instance.client;

  /// Main entry point — seeds all tables in FK-safe order.
  Future<void> seedAll(String storeId, {bool force = false}) async {
    final isar = await IsarService.getInstance();
    final isFirstRun = await isSeeded() == false;

    if (isFirstRun || force) {
      debugPrint('🌱 SeedService: Starting full seed for store=$storeId');
      await _fullSeed(isar, storeId);
      return;
    }

    debugPrint('🌱 SeedService: Starting incremental pull for store=$storeId');
    await _incrementalPull(isar, storeId);
  }

  Future<void> _fullSeed(Isar isar, String storeId) async {
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    await _seedCollection<StoreLocal>(
      isar: isar,
      name: 'stores',
      full: true,
      fetch: () => _client.from('stores').select().eq('is_active', true),
      mapper: _mapStore,
    );

    await _seedCollection<UserProfileLocal>(
      isar: isar,
      name: 'user_profiles',
      full: true,
      fetch: () => _client.from('user_profiles').select().eq('is_active', true),
      mapper: _mapUserProfile,
    );

    await _seedCollection<CustomerLocal>(
      isar: isar,
      name: 'customers',
      full: true,
      fetch: () => _client.from('customers').select().eq('is_active', true),
      mapper: _mapCustomer,
    );

    await _seedCollection<SupplierLocal>(
      isar: isar,
      name: 'suppliers',
      full: true,
      fetch: () => _client.from('suppliers').select().eq('is_active', true),
      mapper: _mapSupplier,
    );

    await _seedCollection<ProductLocal>(
      isar: isar,
      name: 'products',
      full: true,
      fetch: () => _client.from('products').select().eq('is_active', true),
      mapper: _mapProduct,
    );

    await _seedCollection<ProductVariantLocal>(
      isar: isar,
      name: 'product_variants',
      full: true,
      fetch: () =>
          _client.from('product_variants').select().eq('is_active', true),
      mapper: _mapProductVariant,
    );

    await _seedCollection<InventoryLocal>(
      isar: isar,
      name: 'inventory',
      full: true,
      fetch: () =>
          _client.from('inventory').select().eq('store_id', storeId),
      mapper: _mapInventory,
    );

    await _seedCollection<InvoiceLocal>(
      isar: isar,
      name: 'invoices',
      full: true,
      fetch: () => _client
          .from('invoices')
          .select()
          .eq('store_id', storeId)
          .gte('created_at', thirtyDaysAgo),
      mapper: _mapInvoice,
    );

    await _seedCollection<PaymentLocal>(
      isar: isar,
      name: 'payments',
      full: true,
      fetch: () => _client
          .from('payments')
          .select()
          .eq('store_id', storeId)
          .gte('created_at', thirtyDaysAgo),
      mapper: _mapPayment,
    );

    await _seedCollection<TransactionLocal>(
      isar: isar,
      name: 'transactions',
      full: true,
      fetch: () => _client
          .from('transactions')
          .select()
          .eq('store_id', storeId)
          .gte('created_at', thirtyDaysAgo),
      mapper: _mapTransaction,
    );

    await _seedCollection<ExpenseCategoryLocal>(
      isar: isar,
      name: 'expense_categories',
      full: true,
      fetch: () => _client.from('expense_categories').select().eq('store_id', storeId),
      mapper: _mapExpenseCategory,
    );

    await _seedCollection<ExpenseLocal>(
      isar: isar,
      name: 'expenses',
      full: true,
      fetch: () => _client
          .from('expenses')
          .select()
          .eq('store_id', storeId)
          .gte('expense_date', thirtyDaysAgo),
      mapper: _mapExpense,
    );

    await updateLastSyncAt();
    debugPrint('✅ SeedService: Full seed complete');
  }

  Future<void> _incrementalPull(Isar isar, String storeId) async {
    final meta = await isar.syncMetadatas.get(1);
    final lastSync = meta?.lastSyncAt;
    final since = lastSync?.toIso8601String() ?? '2000-01-01T00:00:00Z';
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    await _pullUpdated('stores', since, _mapStore,
        (s) => _client.from('stores').select().gte('updated_at', s));
    await _pullUpdated('user_profiles', since, _mapUserProfile,
        (s) => _client.from('user_profiles').select().gte('updated_at', s));
    await _pullUpdated('customers', since, _mapCustomer,
        (s) => _client.from('customers').select().gte('updated_at', s));
    await _pullUpdated('suppliers', since, _mapSupplier,
        (s) => _client.from('suppliers').select().gte('updated_at', s));
    await _pullUpdated('products', since, _mapProduct,
        (s) => _client.from('products').select().gte('updated_at', s));
    await _pullUpdated('product_variants', since, _mapProductVariant,
        (s) => _client.from('product_variants').select().gte('updated_at', s));
    await _pullUpdated('inventory', since, _mapInventory,
        (s) => _client.from('inventory').select().eq('store_id', storeId).gte('updated_at', s));
    await _pullUpdated('invoices', since, _mapInvoice,
        (s) => _client.from('invoices').select().eq('store_id', storeId).gte('updated_at', s).gte('created_at', thirtyDaysAgo));
    await _pullUpdated('payments', since, _mapPayment,
        (s) => _client.from('payments').select().eq('store_id', storeId).gte('updated_at', s).gte('created_at', thirtyDaysAgo));
    await _pullUpdated('transactions', since, _mapTransaction,
        (s) => _client.from('transactions').select().eq('store_id', storeId).gte('updated_at', s).gte('created_at', thirtyDaysAgo));
    await _pullUpdated('expense_categories', since, _mapExpenseCategory,
        (s) => _client.from('expense_categories').select().eq('store_id', storeId).gte('updated_at', s));
    await _pullUpdated('expenses', since, _mapExpense,
        (s) => _client.from('expenses').select().eq('store_id', storeId).gte('expense_date', thirtyDaysAgo).gte('updated_at', s));

    await updateLastSyncAt();
    debugPrint('✅ SeedService: Incremental pull complete');
  }

  /// Fetches records updated since [since] and upserts them into Isar.
  Future<void> _pullUpdated<T>(
    String name,
    String since,
    T Function(Map<String, dynamic>) mapper,
    Future<List<dynamic>> Function(String since) fetch,
  ) async {
    try {
      final rows = await fetch(since);
      if (rows.isEmpty) return;
      final isar = await IsarService.getInstance();
      final items = rows
          .map((r) => mapper(Map<String, dynamic>.from(r as Map)))
          .toList();
      await isar.writeTxn(() async {
        // Upsert: find existing by supabaseId and replace, or insert new
        for (final item in items) {
          await isar.collection<T>().put(item);
        }
      });
      debugPrint('  📥 $name: ${items.length} rows pulled');
    } catch (e) {
      debugPrint('  ⚠️ $name incremental error: $e');
    }
  }

  // ══════════════════════════════════════════
  // Generic seed helper
  // ══════════════════════════════════════════

  Future<void> _seedCollection<T>({
    required Isar isar,
    required String name,
    required bool full,
    required Future<List<dynamic>> Function() fetch,
    required T Function(Map<String, dynamic>) mapper,
  }) async {
    try {
      final rows = await fetch();
      final items = rows
          .map((r) => mapper(Map<String, dynamic>.from(r as Map)))
          .toList();

      await isar.writeTxn(() async {
        if (full) {
          await isar.collection<T>().clear();
        }
        await isar.collection<T>().putAll(items);
      });

      debugPrint('  📦 $name: ${items.length} rows ${full ? 'seeded' : 'upserted'}');
    } catch (e) {
      debugPrint('  ❌ $name seed error: $e');
    }
  }

  // ══════════════════════════════════════════
  // Sync metadata helpers
  // ══════════════════════════════════════════

  /// Returns true if at least one seed has completed.
  Future<bool> isSeeded() async {
    final isar = await IsarService.getInstance();
    final meta = await isar.syncMetadatas.get(1);
    return meta?.lastSyncAt != null;
  }

  /// Stamps the current time on the SyncMetadata singleton.
  Future<void> updateLastSyncAt() async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      var meta = await isar.syncMetadatas.get(1);
      if (meta == null) {
        meta = SyncMetadata()..lastSyncAt = DateTime.now();
      } else {
        meta.lastSyncAt = DateTime.now();
      }
      await isar.syncMetadatas.put(meta);
    });
  }

  // ══════════════════════════════════════════
  // Mappers — Supabase JSON → Isar objects
  // ══════════════════════════════════════════

  StoreLocal _mapStore(Map<String, dynamic> j) => StoreLocal()
    ..supabaseId = j['id'] as String
    ..name = j['name'] as String
    ..location = j['location'] as String?
    ..isActive = j['is_active'] as bool? ?? true
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at']);

  UserProfileLocal _mapUserProfile(Map<String, dynamic> j) =>
      UserProfileLocal()
        ..supabaseId = j['id'] as String
        ..fullName = j['full_name'] as String
        ..role = j['role'] as String? ?? 'employee'
        ..storeId = j['store_id'] as String?
        ..isActive = j['is_active'] as bool? ?? true
        ..createdAt = _parseDate(j['created_at'])
        ..updatedAt = _parseDate(j['updated_at'])
        ..firstName = j['first_name'] as String?
        ..lastName = j['last_name'] as String?
        ..phone = j['phone'] as String?
        ..address = j['address'] as String?
        ..jobTitle = j['job_title'] as String?
        ..hiredAt = _parseDate(j['hired_at'])
        ..isPermanentlyDeleted = j['is_permanently_deleted'] as bool? ?? false;

  CustomerLocal _mapCustomer(Map<String, dynamic> j) => CustomerLocal()
    ..supabaseId = j['id'] as String
    ..fullName = j['full_name'] as String
    ..phone = j['phone'] as String?
    ..email = j['email'] as String?
    ..address = j['address'] as String?
    ..imageUrl = j['image_url'] as String?
    ..isActive = j['is_active'] as bool? ?? true
    ..balance = (j['balance'] as num?)?.toDouble() ?? 0.0
    ..creditLimit = (j['credit_limit'] as num?)?.toDouble()
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at']);

  SupplierLocal _mapSupplier(Map<String, dynamic> j) => SupplierLocal()
    ..supabaseId = j['id'] as String
    ..companyName = j['company_name'] as String
    ..contactName = j['contact_name'] as String?
    ..phone = j['phone'] as String?
    ..imageUrl = j['image_url'] as String?
    ..isActive = j['is_active'] as bool? ?? true
    ..balance = (j['balance'] as num?)?.toDouble() ?? 0.0
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at']);

  ProductLocal _mapProduct(Map<String, dynamic> j) => ProductLocal()
    ..supabaseId = j['id'] as String
    ..name = j['name'] as String
    ..description = j['description'] as String?
    ..imageUrl = j['image_url'] as String?
    ..supplierId = j['supplier_id'] as String?
    ..isActive = j['is_active'] as bool? ?? true
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at']);

  ProductVariantLocal _mapProductVariant(Map<String, dynamic> j) =>
      ProductVariantLocal()
        ..supabaseId = j['id'] as String
        ..productId = j['product_id'] as String
        ..size = j['size'] as String
        ..color = j['color'] as String
        ..barcode = j['barcode'] as String?
        ..sellPrice = (j['sell_price'] as num?)?.toDouble() ?? 0.0
        ..buyPrice = (j['buy_price'] as num?)?.toDouble() ?? 0.0
        ..isActive = j['is_active'] as bool? ?? true
        ..createdAt = _parseDate(j['created_at'])
        ..updatedAt = _parseDate(j['updated_at']);

  InventoryLocal _mapInventory(Map<String, dynamic> j) => InventoryLocal()
    ..supabaseId = j['id'] as String
    ..variantId = j['variant_id'] as String
    ..storeId = j['store_id'] as String
    ..quantity = j['quantity'] as int? ?? 0
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at']);

  InvoiceLocal _mapInvoice(Map<String, dynamic> j) => InvoiceLocal()
    ..supabaseId = j['id'] as String
    ..invoiceNumber = j['invoice_number'] as String
    ..storeId = j['store_id'] as String?
    ..userId = j['user_id'] as String?
    ..customerId = j['customer_id'] as String?
    ..supplierId = j['supplier_id'] as String?
    ..type = j['type'] as String
    ..totalAmount = (j['total_amount'] as num?)?.toDouble() ?? 0.0
    ..paidAmount = (j['paid_amount'] as num?)?.toDouble() ?? 0.0
    ..discount = (j['discount'] as num?)?.toDouble() ?? 0.0
    ..status = j['status'] as String? ?? 'paid'
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at'])
    ..synced = true; // came from server

  PaymentLocal _mapPayment(Map<String, dynamic> j) => PaymentLocal()
    ..supabaseId = j['id'] as String
    ..invoiceId = j['invoice_id'] as String?
    ..customerId = j['customer_id'] as String?
    ..supplierId = j['supplier_id'] as String?
    ..storeId = j['store_id'] as String?
    ..userId = j['user_id'] as String?
    ..amount = (j['amount'] as num?)?.toDouble() ?? 0.0
    ..paymentMethod = j['payment_method'] as String? ?? 'cash'
    ..paymentType = j['payment_type'] as String? ?? 'invoice'
    ..paymentDate = _parseDate(j['payment_date'])
    ..notes = j['notes'] as String?
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at'])
    ..synced = true; // came from server

  TransactionLocal _mapTransaction(Map<String, dynamic> j) =>
      TransactionLocal()
        ..supabaseId = j['id'] as String
        ..invoiceNumber = j['invoice_number'] as String?
        ..type = j['type'] as String
        ..variantId = j['variant_id'] as String
        ..quantity = j['quantity'] as int? ?? 0
        ..unitPrice = (j['unit_price'] as num?)?.toDouble() ?? 0.0
        ..totalPrice = (j['total_price'] as num?)?.toDouble() ?? 0.0
        ..storeId = j['store_id'] as String
        ..userId = j['user_id'] as String
        ..customerId = j['customer_id'] as String?
        ..supplierId = j['supplier_id'] as String?
        ..invoiceId = j['invoice_id'] as String?
        ..createdAt = _parseDate(j['created_at'])
        ..updatedAt = _parseDate(j['updated_at'])
        ..synced = true; // came from server

  ExpenseCategoryLocal _mapExpenseCategory(Map<String, dynamic> j) =>
      ExpenseCategoryLocal()
        ..supabaseId = j['id'] as String
        ..name = j['name'] as String
        ..storeId = j['store_id'] as String
        ..createdAt = _parseDate(j['created_at'])
        ..updatedAt = _parseDate(j['updated_at']);

  ExpenseLocal _mapExpense(Map<String, dynamic> j) => ExpenseLocal()
    ..supabaseId = j['id'] as String
    ..categoryId = j['category_id'] as String?
    ..amount = (j['amount'] as num?)?.toDouble() ?? 0.0
    ..description = j['description'] as String?
    ..paymentMethod = j['payment_method'] as String? ?? 'cash'
    ..storeId = j['store_id'] as String
    ..userId = j['user_id'] as String?
    ..expenseDate = _parseDate(j['expense_date']) ?? DateTime.now()
    ..createdAt = _parseDate(j['created_at'])
    ..updatedAt = _parseDate(j['updated_at'])
    ..synced = true; // came from server

  // ══════════════════════════════════════════
  // Date parser
  // ══════════════════════════════════════════

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    return DateTime.tryParse(val.toString());
  }
}
