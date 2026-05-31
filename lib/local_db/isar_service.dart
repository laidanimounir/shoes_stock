import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'collections/store_local.dart';
import 'collections/user_profile_local.dart';
import 'collections/customer_local.dart';
import 'collections/supplier_local.dart';
import 'collections/product_local.dart';
import 'collections/product_variant_local.dart';
import 'collections/inventory_local.dart';
import 'collections/invoice_local.dart';
import 'collections/payment_local.dart';
import 'collections/transaction_local.dart';
import 'collections/expense_category_local.dart';
import 'collections/expense_local.dart';
import 'collections/sync_queue_item.dart';
import 'collections/sync_metadata.dart';
import 'collections/settings_local.dart';
import 'collections/size_run_local.dart';

/// Central Isar database service.
/// Opens one shared instance with all collections registered.
class IsarService {
  static Isar? _isar;

  /// Returns the singleton Isar instance, creating it on first call.
  static Future<Isar> getInstance() async {
    if (_isar != null && _isar!.isOpen) return _isar!;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [
        StoreLocalSchema,
        UserProfileLocalSchema,
        CustomerLocalSchema,
        SupplierLocalSchema,
        ProductLocalSchema,
        ProductVariantLocalSchema,
        InventoryLocalSchema,
        InvoiceLocalSchema,
        PaymentLocalSchema,
        TransactionLocalSchema,
        ExpenseCategoryLocalSchema,
        ExpenseLocalSchema,
        SyncQueueItemSchema,
        SyncMetadataSchema,
        SettingsLocalSchema,
        SizeRunLocalSchema,
      ],
      directory: dir.path,
      name: 'shoestock_local',
    );

    return _isar!;
  }

  /// Closes the Isar instance gracefully.
  static Future<void> close() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
      _isar = null;
    }
  }
}
