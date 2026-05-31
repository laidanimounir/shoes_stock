import 'dart:convert';
import 'package:isar/isar.dart';

part 'size_run_local.g.dart';

@Collection()
class SizeRunLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  late String productId;
  String? color;
  String sizesJson = '{}';
  late String storeId;
  DateTime? updatedAt;

  @ignore
  Map<String, int> get sizes {
    final map = jsonDecode(sizesJson) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  void updateSizes(Map<String, int> value) {
    sizesJson = jsonEncode(value);
  }
}
