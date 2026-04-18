// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_local.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetInventoryLocalCollection on Isar {
  IsarCollection<InventoryLocal> get inventoryLocals => this.collection();
}

const InventoryLocalSchema = CollectionSchema(
  name: r'InventoryLocal',
  id: -7728381355647449418,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'quantity': PropertySchema(
      id: 1,
      name: r'quantity',
      type: IsarType.long,
    ),
    r'storeId': PropertySchema(
      id: 2,
      name: r'storeId',
      type: IsarType.string,
    ),
    r'supabaseId': PropertySchema(
      id: 3,
      name: r'supabaseId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 4,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'variantId': PropertySchema(
      id: 5,
      name: r'variantId',
      type: IsarType.string,
    )
  },
  estimateSize: _inventoryLocalEstimateSize,
  serialize: _inventoryLocalSerialize,
  deserialize: _inventoryLocalDeserialize,
  deserializeProp: _inventoryLocalDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'variantId_storeId': IndexSchema(
      id: -2764703807858905050,
      name: r'variantId_storeId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'variantId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'storeId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _inventoryLocalGetId,
  getLinks: _inventoryLocalGetLinks,
  attach: _inventoryLocalAttach,
  version: '3.1.0+1',
);

int _inventoryLocalEstimateSize(
  InventoryLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.storeId.length * 3;
  bytesCount += 3 + object.supabaseId.length * 3;
  bytesCount += 3 + object.variantId.length * 3;
  return bytesCount;
}

void _inventoryLocalSerialize(
  InventoryLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeLong(offsets[1], object.quantity);
  writer.writeString(offsets[2], object.storeId);
  writer.writeString(offsets[3], object.supabaseId);
  writer.writeDateTime(offsets[4], object.updatedAt);
  writer.writeString(offsets[5], object.variantId);
}

InventoryLocal _inventoryLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = InventoryLocal();
  object.createdAt = reader.readDateTimeOrNull(offsets[0]);
  object.isarId = id;
  object.quantity = reader.readLong(offsets[1]);
  object.storeId = reader.readString(offsets[2]);
  object.supabaseId = reader.readString(offsets[3]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[4]);
  object.variantId = reader.readString(offsets[5]);
  return object;
}

P _inventoryLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _inventoryLocalGetId(InventoryLocal object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _inventoryLocalGetLinks(InventoryLocal object) {
  return [];
}

void _inventoryLocalAttach(
    IsarCollection<dynamic> col, Id id, InventoryLocal object) {
  object.isarId = id;
}

extension InventoryLocalByIndex on IsarCollection<InventoryLocal> {
  Future<InventoryLocal?> getByVariantIdStoreId(
      String variantId, String storeId) {
    return getByIndex(r'variantId_storeId', [variantId, storeId]);
  }

  InventoryLocal? getByVariantIdStoreIdSync(String variantId, String storeId) {
    return getByIndexSync(r'variantId_storeId', [variantId, storeId]);
  }

  Future<bool> deleteByVariantIdStoreId(String variantId, String storeId) {
    return deleteByIndex(r'variantId_storeId', [variantId, storeId]);
  }

  bool deleteByVariantIdStoreIdSync(String variantId, String storeId) {
    return deleteByIndexSync(r'variantId_storeId', [variantId, storeId]);
  }

  Future<List<InventoryLocal?>> getAllByVariantIdStoreId(
      List<String> variantIdValues, List<String> storeIdValues) {
    final len = variantIdValues.length;
    assert(storeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([variantIdValues[i], storeIdValues[i]]);
    }

    return getAllByIndex(r'variantId_storeId', values);
  }

  List<InventoryLocal?> getAllByVariantIdStoreIdSync(
      List<String> variantIdValues, List<String> storeIdValues) {
    final len = variantIdValues.length;
    assert(storeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([variantIdValues[i], storeIdValues[i]]);
    }

    return getAllByIndexSync(r'variantId_storeId', values);
  }

  Future<int> deleteAllByVariantIdStoreId(
      List<String> variantIdValues, List<String> storeIdValues) {
    final len = variantIdValues.length;
    assert(storeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([variantIdValues[i], storeIdValues[i]]);
    }

    return deleteAllByIndex(r'variantId_storeId', values);
  }

  int deleteAllByVariantIdStoreIdSync(
      List<String> variantIdValues, List<String> storeIdValues) {
    final len = variantIdValues.length;
    assert(storeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([variantIdValues[i], storeIdValues[i]]);
    }

    return deleteAllByIndexSync(r'variantId_storeId', values);
  }

  Future<Id> putByVariantIdStoreId(InventoryLocal object) {
    return putByIndex(r'variantId_storeId', object);
  }

  Id putByVariantIdStoreIdSync(InventoryLocal object, {bool saveLinks = true}) {
    return putByIndexSync(r'variantId_storeId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByVariantIdStoreId(List<InventoryLocal> objects) {
    return putAllByIndex(r'variantId_storeId', objects);
  }

  List<Id> putAllByVariantIdStoreIdSync(List<InventoryLocal> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'variantId_storeId', objects,
        saveLinks: saveLinks);
  }
}

extension InventoryLocalQueryWhereSort
    on QueryBuilder<InventoryLocal, InventoryLocal, QWhere> {
  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension InventoryLocalQueryWhere
    on QueryBuilder<InventoryLocal, InventoryLocal, QWhereClause> {
  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause> isarIdEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause>
      isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause>
      isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause>
      isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerIsarId,
        includeLower: includeLower,
        upper: upperIsarId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause>
      variantIdEqualToAnyStoreId(String variantId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'variantId_storeId',
        value: [variantId],
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause>
      variantIdNotEqualToAnyStoreId(String variantId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'variantId_storeId',
              lower: [],
              upper: [variantId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'variantId_storeId',
              lower: [variantId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'variantId_storeId',
              lower: [variantId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'variantId_storeId',
              lower: [],
              upper: [variantId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause>
      variantIdStoreIdEqualTo(String variantId, String storeId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'variantId_storeId',
        value: [variantId, storeId],
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterWhereClause>
      variantIdEqualToStoreIdNotEqualTo(String variantId, String storeId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'variantId_storeId',
              lower: [variantId],
              upper: [variantId, storeId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'variantId_storeId',
              lower: [variantId, storeId],
              includeLower: false,
              upper: [variantId],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'variantId_storeId',
              lower: [variantId, storeId],
              includeLower: false,
              upper: [variantId],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'variantId_storeId',
              lower: [variantId],
              upper: [variantId, storeId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension InventoryLocalQueryFilter
    on QueryBuilder<InventoryLocal, InventoryLocal, QFilterCondition> {
  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      createdAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isarId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      quantityEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quantity',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      quantityGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'quantity',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      quantityLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'quantity',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      quantityBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'quantity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storeId',
        value: '',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      storeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storeId',
        value: '',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'supabaseId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'supabaseId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'supabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      supabaseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'supabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'variantId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'variantId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'variantId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'variantId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'variantId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'variantId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'variantId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'variantId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'variantId',
        value: '',
      ));
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterFilterCondition>
      variantIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'variantId',
        value: '',
      ));
    });
  }
}

extension InventoryLocalQueryObject
    on QueryBuilder<InventoryLocal, InventoryLocal, QFilterCondition> {}

extension InventoryLocalQueryLinks
    on QueryBuilder<InventoryLocal, InventoryLocal, QFilterCondition> {}

extension InventoryLocalQuerySortBy
    on QueryBuilder<InventoryLocal, InventoryLocal, QSortBy> {
  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> sortByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      sortByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> sortByStoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeId', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      sortByStoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeId', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      sortBySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      sortBySupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> sortByVariantId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'variantId', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      sortByVariantIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'variantId', Sort.desc);
    });
  }
}

extension InventoryLocalQuerySortThenBy
    on QueryBuilder<InventoryLocal, InventoryLocal, QSortThenBy> {
  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> thenByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      thenByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> thenByStoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeId', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      thenByStoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeId', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      thenBySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      thenBySupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy> thenByVariantId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'variantId', Sort.asc);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QAfterSortBy>
      thenByVariantIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'variantId', Sort.desc);
    });
  }
}

extension InventoryLocalQueryWhereDistinct
    on QueryBuilder<InventoryLocal, InventoryLocal, QDistinct> {
  QueryBuilder<InventoryLocal, InventoryLocal, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QDistinct> distinctByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quantity');
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QDistinct> distinctByStoreId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QDistinct> distinctBySupabaseId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'supabaseId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<InventoryLocal, InventoryLocal, QDistinct> distinctByVariantId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'variantId', caseSensitive: caseSensitive);
    });
  }
}

extension InventoryLocalQueryProperty
    on QueryBuilder<InventoryLocal, InventoryLocal, QQueryProperty> {
  QueryBuilder<InventoryLocal, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<InventoryLocal, DateTime?, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<InventoryLocal, int, QQueryOperations> quantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quantity');
    });
  }

  QueryBuilder<InventoryLocal, String, QQueryOperations> storeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storeId');
    });
  }

  QueryBuilder<InventoryLocal, String, QQueryOperations> supabaseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'supabaseId');
    });
  }

  QueryBuilder<InventoryLocal, DateTime?, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<InventoryLocal, String, QQueryOperations> variantIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'variantId');
    });
  }
}
