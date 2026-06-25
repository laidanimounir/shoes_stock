import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
import '../local_db/collections/expense_local.dart';
import '../local_db/collections/expense_category_local.dart';
import '../local_db/collections/sync_queue_item.dart';
import '../local_db/collections/sync_metadata.dart';
import '../local_db/collections/settings_local.dart';
import '../local_db/collections/size_run_local.dart';

class BackupService {
  static final instance = BackupService._();
  BackupService._();

  Future<String> exportToJson() async {
    final isar = await IsarService.getInstance();

    final data = {
      'exported_at': DateTime.now().toIso8601String(),
      'stores': await _exportAll(isar.storeLocals.where().findAll(), _storeToMap),
      'user_profiles': await _exportAll(isar.userProfileLocals.where().findAll(), _profileToMap),
      'customers': await _exportAll(isar.customerLocals.where().findAll(), _customerToMap),
      'suppliers': await _exportAll(isar.supplierLocals.where().findAll(), _supplierToMap),
      'products': await _exportAll(isar.productLocals.where().findAll(), _productToMap),
      'product_variants': await _exportAll(isar.productVariantLocals.where().findAll(), _variantToMap),
      'inventory': await _exportAll(isar.inventoryLocals.where().findAll(), _inventoryToMap),
      'invoices': await _exportAll(isar.invoiceLocals.where().findAll(), _invoiceToMap),
      'payments': await _exportAll(isar.paymentLocals.where().findAll(), _paymentToMap),
      'transactions': await _exportAll(isar.transactionLocals.where().findAll(), _transactionToMap),
      'expenses': await _exportAll(isar.expenseLocals.where().findAll(), _expenseToMap),
      'expense_categories': await _exportAll(isar.expenseCategoryLocals.where().findAll(), _expenseCategoryToMap),
      'settings': [await _settingsToMap(isar)],
      'size_runs': await _exportAll(isar.sizeRunLocals.where().findAll(), _sizeRunToMap),
      'sync_queue': await _exportAll(isar.syncQueueItems.where().findAll(), _syncQueueToMap),
      'sync_metadata': await _exportAll(isar.syncMetadatas.where().findAll(), _syncMetaToMap),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/shoestock_backup_$timestamp.json');
    await file.writeAsString(jsonStr);
    return file.path;
  }

  Future<void> shareBackup() async {
    final path = await exportToJson();
    await Share.shareXFiles([XFile(path)], text: 'ShoeStock ERP Backup');
  }

  Future<Map<String, dynamic>> restoreFromJson() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return {'success': false, 'error': 'no_file_selected'};
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (!data.containsKey('exported_at')) {
        return {'success': false, 'error': 'invalid_backup_format'};
      }

      return {
        'success': true,
        'preview': {
          'exported_at': data['exported_at'],
          'record_count': _countRecords(data),
        },
        'data': data,
      };
    } catch (e) {
      debugPrint('[BackupService] Restore error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> applyRestore(Map<String, dynamic> backupData) async {
    try {
      final isar = await IsarService.getInstance();

      await isar.writeTxn(() async {
        await isar.storeLocals.where().deleteAll();
        await isar.userProfileLocals.where().deleteAll();
        await isar.customerLocals.where().deleteAll();
        await isar.supplierLocals.where().deleteAll();
        await isar.productLocals.where().deleteAll();
        await isar.productVariantLocals.where().deleteAll();
        await isar.inventoryLocals.where().deleteAll();
        await isar.invoiceLocals.where().deleteAll();
        await isar.paymentLocals.where().deleteAll();
        await isar.transactionLocals.where().deleteAll();
        await isar.expenseLocals.where().deleteAll();
        await isar.expenseCategoryLocals.where().deleteAll();
        await isar.settingsLocals.where().deleteAll();
        await isar.sizeRunLocals.where().deleteAll();
        await isar.syncQueueItems.where().deleteAll();
        await isar.syncMetadatas.where().deleteAll();

        _restoreList<StoreLocal>(isar.storeLocals, backupData['stores'], _storeFromMap);
        _restoreList<UserProfileLocal>(isar.userProfileLocals, backupData['user_profiles'], _profileFromMap);
        _restoreList<CustomerLocal>(isar.customerLocals, backupData['customers'], _customerFromMap);
        _restoreList<SupplierLocal>(isar.supplierLocals, backupData['suppliers'], _supplierFromMap);
        _restoreList<ProductLocal>(isar.productLocals, backupData['products'], _productFromMap);
        _restoreList<ProductVariantLocal>(isar.productVariantLocals, backupData['product_variants'], _variantFromMap);
        _restoreList<InventoryLocal>(isar.inventoryLocals, backupData['inventory'], _inventoryFromMap);
        _restoreList<InvoiceLocal>(isar.invoiceLocals, backupData['invoices'], _invoiceFromMap);
        _restoreList<PaymentLocal>(isar.paymentLocals, backupData['payments'], _paymentFromMap);
        _restoreList<TransactionLocal>(isar.transactionLocals, backupData['transactions'], _transactionFromMap);
        _restoreList<ExpenseLocal>(isar.expenseLocals, backupData['expenses'], _expenseFromMap);
        _restoreList<ExpenseCategoryLocal>(isar.expenseCategoryLocals, backupData['expense_categories'], _expenseCategoryFromMap);
        if (backupData['settings'] is List && (backupData['settings'] as List).isNotEmpty) {
          await isar.settingsLocals.put(_settingsFromMap((backupData['settings'] as List).first as Map<String, dynamic>));
        }
        _restoreList<SizeRunLocal>(isar.sizeRunLocals, backupData['size_runs'], _sizeRunFromMap);
        _restoreList<SyncQueueItem>(isar.syncQueueItems, backupData['sync_queue'], _syncQueueFromMap);
        _restoreList<SyncMetadata>(isar.syncMetadatas, backupData['sync_metadata'], _syncMetaFromMap);
      });

      return {'success': true, 'message': 'Restauration terminée'};
    } catch (e) {
      debugPrint('[BackupService] ApplyRestore error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  int _countRecords(Map<String, dynamic> data) {
    int count = 0;
    final listKeys = ['stores', 'user_profiles', 'customers', 'suppliers', 'products',
      'product_variants', 'inventory', 'invoices', 'payments', 'transactions',
      'expenses', 'expense_categories', 'settings', 'size_runs', 'sync_queue', 'sync_metadata'];
    for (final key in listKeys) {
      final list = data[key];
      if (list is List) count += list.length;
    }
    return count;
  }

  Future<void> _restoreList<T>(dynamic collection, dynamic jsonList, T Function(Map<String, dynamic>) fromMap) async {
    if (jsonList is! List) return;
    for (final item in jsonList) {
      if (item is Map<String, dynamic>) {
        await collection.put(fromMap(item));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _exportAll<T>(Future<List<T>> future, Map<String, dynamic> Function(T) mapper) async {
    final items = await future;
    return items.map(mapper).toList();
  }

  Map<String, dynamic> _storeToMap(StoreLocal s) => {
    'supabase_id': s.supabaseId, 'name': s.name, 'location': s.location,
    'is_active': s.isActive, 'created_at': s.createdAt?.toIso8601String(), 'updated_at': s.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _profileToMap(UserProfileLocal p) => {
    'supabase_id': p.supabaseId, 'full_name': p.fullName, 'role': p.role,
    'store_id': p.storeId, 'is_active': p.isActive, 'first_name': p.firstName,
    'last_name': p.lastName, 'phone': p.phone, 'address': p.address,
    'job_title': p.jobTitle, 'hired_at': p.hiredAt?.toIso8601String(),
    'is_permanently_deleted': p.isPermanentlyDeleted, 'commission_rate': p.commissionRate,
    'login_at': p.loginAt?.toIso8601String(), 'preferred_language': p.preferredLanguage,
    'created_at': p.createdAt?.toIso8601String(), 'updated_at': p.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _customerToMap(CustomerLocal c) => {
    'supabase_id': c.supabaseId, 'full_name': c.fullName, 'phone': c.phone,
    'email': c.email, 'image_url': c.imageUrl, 'address': c.address,
    'balance': c.balance, 'loyalty_points': c.loyaltyPoints,
    'customer_type': c.customerType, 'is_active': c.isActive,
    'created_at': c.createdAt?.toIso8601String(), 'updated_at': c.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _supplierToMap(SupplierLocal s) => {
    'supabase_id': s.supabaseId, 'company_name': s.companyName,
    'contact_name': s.contactName, 'phone': s.phone, 'image_url': s.imageUrl,
    'is_active': s.isActive, 'balance': s.balance,
    'created_at': s.createdAt?.toIso8601String(), 'updated_at': s.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _productToMap(ProductLocal p) => {
    'supabase_id': p.supabaseId, 'name': p.name, 'description': p.description,
    'image_url': p.imageUrl, 'supplier_id': p.supplierId, 'category': p.category,
    'is_active': p.isActive,
    'created_at': p.createdAt?.toIso8601String(), 'updated_at': p.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _variantToMap(ProductVariantLocal v) => {
    'supabase_id': v.supabaseId, 'product_id': v.productId, 'size': v.size,
    'color': v.color, 'barcode': v.barcode, 'sell_price': v.sellPrice,
    'buy_price': v.buyPrice, 'is_active': v.isActive, 'unit_type': v.unitType,
    'units_per_carton': v.unitsPerCarton, 'wholesale_price': v.wholesalePrice,
    'created_at': v.createdAt?.toIso8601String(), 'updated_at': v.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _inventoryToMap(InventoryLocal i) => {
    'supabase_id': i.supabaseId, 'variant_id': i.variantId, 'store_id': i.storeId,
    'quantity': i.quantity, 'arrivage_id': i.arrivageId,
    'arrivage_date': i.arrivageDate?.toIso8601String(), 'purchase_price': i.purchasePrice,
    'created_at': i.createdAt?.toIso8601String(), 'updated_at': i.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _invoiceToMap(InvoiceLocal i) => {
    'supabase_id': i.supabaseId, 'invoice_number': i.invoiceNumber,
    'store_id': i.storeId, 'user_id': i.userId, 'customer_id': i.customerId,
    'supplier_id': i.supplierId, 'type': i.type, 'total_amount': i.totalAmount,
    'paid_amount': i.paidAmount, 'discount': i.discount, 'status': i.status,
    'synced': i.synced,
    'created_at': i.createdAt?.toIso8601String(), 'updated_at': i.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _paymentToMap(PaymentLocal p) => {
    'supabase_id': p.supabaseId, 'invoice_id': p.invoiceId,
    'customer_id': p.customerId, 'supplier_id': p.supplierId,
    'store_id': p.storeId, 'user_id': p.userId, 'amount': p.amount,
    'payment_method': p.paymentMethod, 'payment_date': p.paymentDate?.toIso8601String(),
    'notes': p.notes, 'payment_type': p.paymentType,
    'created_at': p.createdAt?.toIso8601String(), 'updated_at': p.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _transactionToMap(TransactionLocal t) => {
    'supabase_id': t.supabaseId, 'invoice_number': t.invoiceNumber,
    'type': t.type, 'variant_id': t.variantId, 'quantity': t.quantity,
    'unit_price': t.unitPrice, 'total_price': t.totalPrice,
    'store_id': t.storeId, 'user_id': t.userId, 'customer_id': t.customerId,
    'supplier_id': t.supplierId, 'invoice_id': t.invoiceId, 'synced': t.synced,
    'created_at': t.createdAt?.toIso8601String(), 'updated_at': t.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _expenseToMap(ExpenseLocal e) => {
    'supabase_id': e.supabaseId, 'category_id': e.categoryId,
    'amount': e.amount, 'description': e.description,
    'payment_method': e.paymentMethod, 'store_id': e.storeId,
    'user_id': e.userId,     'expense_date': e.expenseDate.toIso8601String(),
    'created_at': e.createdAt?.toIso8601String(), 'updated_at': e.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _expenseCategoryToMap(ExpenseCategoryLocal e) => {
    'supabase_id': e.supabaseId, 'name': e.name, 'store_id': e.storeId,
    'created_at': e.createdAt?.toIso8601String(), 'updated_at': e.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _syncQueueToMap(SyncQueueItem s) => {
    'isar_id': s.isarId, 'operation_type': s.operationType, 'payload_json': s.payloadJson,
    'status': s.status, 'idempotency_key': s.idempotencyKey, 'priority': s.priority,
    'retry_count': s.retryCount, 'error_message': s.errorMessage,
    'created_at': s.createdAt.toIso8601String(), 'last_attempt_at': s.lastAttemptAt?.toIso8601String(),
  };

  Map<String, dynamic> _syncMetaToMap(SyncMetadata s) => {
    'isar_id': s.isarId, 'last_sync_at': s.lastSyncAt?.toIso8601String(),
    'mode': s.mode, 'pending_count': s.pendingCount,
  };

  // ── FromMap helpers for restore ──

  StoreLocal _storeFromMap(Map<String, dynamic> m) => StoreLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..name = m['name'] as String? ?? ''
    ..location = m['location'] as String?
    ..isActive = m['is_active'] as bool? ?? true
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  UserProfileLocal _profileFromMap(Map<String, dynamic> m) => UserProfileLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..fullName = m['full_name'] as String? ?? ''
    ..role = m['role'] as String? ?? ''
    ..storeId = m['store_id'] as String?
    ..isActive = m['is_active'] as bool? ?? true
    ..firstName = m['first_name'] as String?
    ..lastName = m['last_name'] as String?
    ..phone = m['phone'] as String?
    ..address = m['address'] as String?
    ..jobTitle = m['job_title'] as String?
    ..hiredAt = m['hired_at'] != null ? DateTime.tryParse(m['hired_at'] as String) : null
    ..isPermanentlyDeleted = m['is_permanently_deleted'] as bool? ?? false
    ..commissionRate = (m['commission_rate'] as num?)?.toDouble() ?? 0
    ..loginAt = m['login_at'] != null ? DateTime.tryParse(m['login_at'] as String) : null
    ..preferredLanguage = m['preferred_language'] as String? ?? 'ar'
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  CustomerLocal _customerFromMap(Map<String, dynamic> m) => CustomerLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..fullName = m['full_name'] as String? ?? ''
    ..phone = m['phone'] as String?
    ..email = m['email'] as String?
    ..address = m['address'] as String?
    ..imageUrl = m['image_url'] as String?
    ..isActive = m['is_active'] as bool? ?? true
    ..balance = (m['balance'] as num?)?.toDouble() ?? 0
    ..loyaltyPoints = (m['loyalty_points'] as num?)?.toInt() ?? 0
    ..creditLimit = (m['credit_limit'] as num?)?.toDouble()
    ..customerType = m['customer_type'] as String?
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  SupplierLocal _supplierFromMap(Map<String, dynamic> m) => SupplierLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..companyName = m['company_name'] as String? ?? ''
    ..contactName = m['contact_name'] as String?
    ..phone = m['phone'] as String?
    ..imageUrl = m['image_url'] as String?
    ..isActive = m['is_active'] as bool? ?? true
    ..balance = (m['balance'] as num?)?.toDouble() ?? 0
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  ProductLocal _productFromMap(Map<String, dynamic> m) => ProductLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..name = m['name'] as String? ?? ''
    ..description = m['description'] as String?
    ..imageUrl = m['image_url'] as String?
    ..supplierId = m['supplier_id'] as String?
    ..category = m['category'] as String?
    ..isActive = m['is_active'] as bool? ?? true
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  ProductVariantLocal _variantFromMap(Map<String, dynamic> m) => ProductVariantLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..productId = m['product_id'] as String? ?? ''
    ..size = m['size'] as String? ?? ''
    ..color = m['color'] as String? ?? ''
    ..barcode = m['barcode'] as String?
    ..sellPrice = (m['sell_price'] as num?)?.toDouble() ?? 0
    ..buyPrice = (m['buy_price'] as num?)?.toDouble() ?? 0
    ..isActive = m['is_active'] as bool? ?? true
    ..unitType = m['unit_type'] as String?
    ..unitsPerCarton = (m['units_per_carton'] as num?)?.toInt()
    ..wholesalePrice = (m['wholesale_price'] as num?)?.toDouble()
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  InventoryLocal _inventoryFromMap(Map<String, dynamic> m) => InventoryLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..variantId = m['variant_id'] as String? ?? ''
    ..storeId = m['store_id'] as String? ?? ''
    ..quantity = (m['quantity'] as num?)?.toInt() ?? 0
    ..arrivageId = m['arrivage_id'] as String?
    ..arrivageDate = m['arrivage_date'] != null ? DateTime.tryParse(m['arrivage_date'] as String) : null
    ..purchasePrice = (m['purchase_price'] as num?)?.toDouble()
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  InvoiceLocal _invoiceFromMap(Map<String, dynamic> m) => InvoiceLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..invoiceNumber = m['invoice_number'] as String? ?? ''
    ..storeId = m['store_id'] as String?
    ..userId = m['user_id'] as String?
    ..customerId = m['customer_id'] as String?
    ..supplierId = m['supplier_id'] as String?
    ..type = m['type'] as String? ?? ''
    ..totalAmount = (m['total_amount'] as num?)?.toDouble() ?? 0
    ..paidAmount = (m['paid_amount'] as num?)?.toDouble() ?? 0
    ..discount = (m['discount'] as num?)?.toDouble() ?? 0
    ..notes = m['notes'] as String?
    ..status = m['status'] as String? ?? ''
    ..synced = m['synced'] as bool? ?? false
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null
    ..dueDate = m['due_date'] != null ? DateTime.tryParse(m['due_date'] as String) : null;

  PaymentLocal _paymentFromMap(Map<String, dynamic> m) => PaymentLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..invoiceId = m['invoice_id'] as String?
    ..customerId = m['customer_id'] as String?
    ..supplierId = m['supplier_id'] as String?
    ..storeId = m['store_id'] as String?
    ..userId = m['user_id'] as String?
    ..amount = (m['amount'] as num?)?.toDouble() ?? 0
    ..paymentMethod = m['payment_method'] as String? ?? 'cash'
    ..paymentDate = m['payment_date'] != null ? DateTime.tryParse(m['payment_date'] as String) : null
    ..notes = m['notes'] as String?
    ..paymentType = m['payment_type'] as String? ?? 'invoice'
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  TransactionLocal _transactionFromMap(Map<String, dynamic> m) => TransactionLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..invoiceNumber = m['invoice_number'] as String?
    ..type = m['type'] as String? ?? ''
    ..variantId = m['variant_id'] as String? ?? ''
    ..quantity = (m['quantity'] as num?)?.toInt() ?? 0
    ..unitPrice = (m['unit_price'] as num?)?.toDouble() ?? 0
    ..totalPrice = (m['total_price'] as num?)?.toDouble() ?? 0
    ..storeId = m['store_id'] as String? ?? ''
    ..userId = m['user_id'] as String? ?? ''
    ..customerId = m['customer_id'] as String?
    ..supplierId = m['supplier_id'] as String?
    ..invoiceId = m['invoice_id'] as String?
    ..profitMargin = (m['profit_margin'] as num?)?.toDouble()
    ..synced = m['synced'] as bool? ?? false
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  ExpenseLocal _expenseFromMap(Map<String, dynamic> m) => ExpenseLocal()
    ..supabaseId = m['supabase_id'] as String?
    ..categoryId = m['category_id'] as String?
    ..amount = (m['amount'] as num?)?.toDouble() ?? 0
    ..description = m['description'] as String?
    ..paymentMethod = m['payment_method'] as String? ?? ''
    ..storeId = m['store_id'] as String? ?? ''
    ..userId = m['user_id'] as String?
    ..expenseDate = m['expense_date'] != null ? DateTime.tryParse(m['expense_date'] as String) ?? DateTime.now() : DateTime.now()
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  ExpenseCategoryLocal _expenseCategoryFromMap(Map<String, dynamic> m) => ExpenseCategoryLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..name = m['name'] as String? ?? ''
    ..storeId = m['store_id'] as String? ?? ''
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;

  SyncQueueItem _syncQueueFromMap(Map<String, dynamic> m) => SyncQueueItem()
    ..operationType = m['operation_type'] as String? ?? ''
    ..payloadJson = m['payload_json'] as String? ?? ''
    ..status = m['status'] as String? ?? ''
    ..idempotencyKey = m['idempotency_key'] as String? ?? ''
    ..priority = (m['priority'] as num?)?.toInt() ?? 3
    ..retryCount = (m['retry_count'] as num?)?.toInt() ?? 0
    ..errorMessage = m['error_message'] as String?
    ..createdAt = m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) ?? DateTime.now() : DateTime.now()
    ..lastAttemptAt = m['last_attempt_at'] != null ? DateTime.tryParse(m['last_attempt_at'] as String) : null;

  SyncMetadata _syncMetaFromMap(Map<String, dynamic> m) => SyncMetadata()
    ..lastSyncAt = m['last_sync_at'] != null ? DateTime.tryParse(m['last_sync_at'] as String) : null
    ..mode = m['mode'] as String? ?? 'online'
    ..pendingCount = (m['pending_count'] as num?)?.toInt() ?? 0;

  // ── Settings serializers ──

  Future<Map<String, dynamic>> _settingsToMap(Isar isar) async {
    final s = await isar.settingsLocals.get(1);
    if (s == null) return {};
    return {
      'locale': s.locale,
      'debt_overdue_days': s.debtOverdueDays,
      'inactivity_timeout_minutes': s.inactivityTimeoutMinutes,
      'low_stock_threshold': s.lowStockThreshold,
      'pin_enabled': s.pinEnabled,
      'pin_hash': s.pinHash,
      'biometric_enabled': s.biometricEnabled,
      'last_api_version_check': s.lastApiVersionCheck,
    };
  }

  SettingsLocal _settingsFromMap(Map<String, dynamic> m) => SettingsLocal()
    ..locale = m['locale'] as String? ?? 'ar'
    ..debtOverdueDays = (m['debt_overdue_days'] as num?)?.toInt() ?? 30
    ..inactivityTimeoutMinutes = (m['inactivity_timeout_minutes'] as num?)?.toInt() ?? 15
    ..lowStockThreshold = (m['low_stock_threshold'] as num?)?.toInt() ?? 3
    ..pinEnabled = m['pin_enabled'] as bool? ?? false
    ..pinHash = m['pin_hash'] as String?
    ..biometricEnabled = m['biometric_enabled'] as bool? ?? false
    ..lastApiVersionCheck = m['last_api_version_check'] as int?;

  // ── SizeRun serializers ──

  Map<String, dynamic> _sizeRunToMap(SizeRunLocal s) => {
    'supabase_id': s.supabaseId,
    'product_id': s.productId,
    'color': s.color,
    'sizes_json': s.sizesJson,
    'store_id': s.storeId,
    'updated_at': s.updatedAt?.toIso8601String(),
  };

  SizeRunLocal _sizeRunFromMap(Map<String, dynamic> m) => SizeRunLocal()
    ..supabaseId = m['supabase_id'] as String? ?? ''
    ..productId = m['product_id'] as String? ?? ''
    ..color = m['color'] as String?
    ..sizesJson = m['sizes_json'] as String? ?? '{}'
    ..storeId = m['store_id'] as String? ?? ''
    ..updatedAt = m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null;
}
