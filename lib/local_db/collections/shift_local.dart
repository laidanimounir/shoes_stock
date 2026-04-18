import 'package:isar/isar.dart';

part 'shift_local.g.dart';

@Collection()
class ShiftLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  late String storeId;
  late String cashierId;
  double openingAmount = 0.0;
  double? closingAmount;
  double? expectedAmount;
  double? discrepancy;
  String? notes;
  DateTime? openedAt;
  DateTime? closedAt;
  String status = 'open'; // ShiftStatus: 'open' | 'closed'

  /// false = created offline, not yet pushed to Supabase
  bool synced = false;
}
