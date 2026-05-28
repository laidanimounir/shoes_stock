import 'dart:convert';
import 'dart:io';
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
    'user_id': e.userId, 'expense_date': e.expenseDate?.toIso8601String(),
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
}
