// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_local.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSettingsLocalCollection on Isar {
  IsarCollection<SettingsLocal> get settingsLocals => this.collection();
}

const SettingsLocalSchema = CollectionSchema(
  name: r'SettingsLocal',
  id: -4766441457459943005,
  properties: {
    r'biometricEnabled': PropertySchema(
      id: 0,
      name: r'biometricEnabled',
      type: IsarType.bool,
    ),
    r'debtOverdueDays': PropertySchema(
      id: 1,
      name: r'debtOverdueDays',
      type: IsarType.long,
    ),
    r'inactivityTimeoutMinutes': PropertySchema(
      id: 2,
      name: r'inactivityTimeoutMinutes',
      type: IsarType.long,
    ),
    r'lastApiVersionCheck': PropertySchema(
      id: 3,
      name: r'lastApiVersionCheck',
      type: IsarType.long,
    ),
    r'locale': PropertySchema(
      id: 4,
      name: r'locale',
      type: IsarType.string,
    ),
    r'lowStockThreshold': PropertySchema(
      id: 5,
      name: r'lowStockThreshold',
      type: IsarType.long,
    ),
    r'pinHash': PropertySchema(
      id: 6,
      name: r'pinHash',
      type: IsarType.string,
    )
  },
  estimateSize: _settingsLocalEstimateSize,
  serialize: _settingsLocalSerialize,
  deserialize: _settingsLocalDeserialize,
  deserializeProp: _settingsLocalDeserializeProp,
  idName: r'isarId',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _settingsLocalGetId,
  getLinks: _settingsLocalGetLinks,
  attach: _settingsLocalAttach,
  version: '3.1.0+1',
);

int _settingsLocalEstimateSize(
  SettingsLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.locale.length * 3;
  {
    final value = object.pinHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _settingsLocalSerialize(
  SettingsLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.biometricEnabled);
  writer.writeLong(offsets[1], object.debtOverdueDays);
  writer.writeLong(offsets[2], object.inactivityTimeoutMinutes);
  writer.writeLong(offsets[3], object.lastApiVersionCheck);
  writer.writeString(offsets[4], object.locale);
  writer.writeLong(offsets[5], object.lowStockThreshold);
  writer.writeString(offsets[6], object.pinHash);
}

SettingsLocal _settingsLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SettingsLocal();
  object.biometricEnabled = reader.readBool(offsets[0]);
  object.debtOverdueDays = reader.readLong(offsets[1]);
  object.inactivityTimeoutMinutes = reader.readLong(offsets[2]);
  object.isarId = id;
  object.lastApiVersionCheck = reader.readLongOrNull(offsets[3]);
  object.locale = reader.readString(offsets[4]);
  object.lowStockThreshold = reader.readLong(offsets[5]);
  object.pinHash = reader.readStringOrNull(offsets[6]);
  return object;
}

P _settingsLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _settingsLocalGetId(SettingsLocal object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _settingsLocalGetLinks(SettingsLocal object) {
  return [];
}

void _settingsLocalAttach(
    IsarCollection<dynamic> col, Id id, SettingsLocal object) {
  object.isarId = id;
}

extension SettingsLocalQueryWhereSort
    on QueryBuilder<SettingsLocal, SettingsLocal, QWhere> {
  QueryBuilder<SettingsLocal, SettingsLocal, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SettingsLocalQueryWhere
    on QueryBuilder<SettingsLocal, SettingsLocal, QWhereClause> {
  QueryBuilder<SettingsLocal, SettingsLocal, QAfterWhereClause> isarIdEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterWhereClause>
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

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterWhereClause>
      isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterWhereClause> isarIdLessThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterWhereClause> isarIdBetween(
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
}

extension SettingsLocalQueryFilter
    on QueryBuilder<SettingsLocal, SettingsLocal, QFilterCondition> {
  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      biometricEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'biometricEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      debtOverdueDaysEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'debtOverdueDays',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      debtOverdueDaysGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'debtOverdueDays',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      debtOverdueDaysLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'debtOverdueDays',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      debtOverdueDaysBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'debtOverdueDays',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      inactivityTimeoutMinutesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'inactivityTimeoutMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      inactivityTimeoutMinutesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'inactivityTimeoutMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      inactivityTimeoutMinutesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'inactivityTimeoutMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      inactivityTimeoutMinutesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'inactivityTimeoutMinutes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
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

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
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

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
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

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lastApiVersionCheckIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastApiVersionCheck',
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lastApiVersionCheckIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastApiVersionCheck',
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lastApiVersionCheckEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastApiVersionCheck',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lastApiVersionCheckGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastApiVersionCheck',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lastApiVersionCheckLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastApiVersionCheck',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lastApiVersionCheckBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastApiVersionCheck',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'locale',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'locale',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'locale',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'locale',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'locale',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'locale',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'locale',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'locale',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'locale',
        value: '',
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      localeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'locale',
        value: '',
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lowStockThresholdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lowStockThreshold',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lowStockThresholdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lowStockThreshold',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lowStockThresholdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lowStockThreshold',
        value: value,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      lowStockThresholdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lowStockThreshold',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pinHash',
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pinHash',
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pinHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pinHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pinHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pinHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pinHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pinHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pinHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pinHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pinHash',
        value: '',
      ));
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterFilterCondition>
      pinHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pinHash',
        value: '',
      ));
    });
  }
}

extension SettingsLocalQueryObject
    on QueryBuilder<SettingsLocal, SettingsLocal, QFilterCondition> {}

extension SettingsLocalQueryLinks
    on QueryBuilder<SettingsLocal, SettingsLocal, QFilterCondition> {}

extension SettingsLocalQuerySortBy
    on QueryBuilder<SettingsLocal, SettingsLocal, QSortBy> {
  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByBiometricEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'biometricEnabled', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByBiometricEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'biometricEnabled', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByDebtOverdueDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debtOverdueDays', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByDebtOverdueDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debtOverdueDays', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByInactivityTimeoutMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inactivityTimeoutMinutes', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByInactivityTimeoutMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inactivityTimeoutMinutes', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByLastApiVersionCheck() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastApiVersionCheck', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByLastApiVersionCheckDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastApiVersionCheck', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> sortByLocale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locale', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> sortByLocaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locale', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByLowStockThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lowStockThreshold', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      sortByLowStockThresholdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lowStockThreshold', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> sortByPinHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinHash', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> sortByPinHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinHash', Sort.desc);
    });
  }
}

extension SettingsLocalQuerySortThenBy
    on QueryBuilder<SettingsLocal, SettingsLocal, QSortThenBy> {
  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByBiometricEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'biometricEnabled', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByBiometricEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'biometricEnabled', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByDebtOverdueDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debtOverdueDays', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByDebtOverdueDaysDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debtOverdueDays', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByInactivityTimeoutMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inactivityTimeoutMinutes', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByInactivityTimeoutMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inactivityTimeoutMinutes', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByLastApiVersionCheck() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastApiVersionCheck', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByLastApiVersionCheckDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastApiVersionCheck', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> thenByLocale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locale', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> thenByLocaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locale', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByLowStockThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lowStockThreshold', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy>
      thenByLowStockThresholdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lowStockThreshold', Sort.desc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> thenByPinHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinHash', Sort.asc);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QAfterSortBy> thenByPinHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinHash', Sort.desc);
    });
  }
}

extension SettingsLocalQueryWhereDistinct
    on QueryBuilder<SettingsLocal, SettingsLocal, QDistinct> {
  QueryBuilder<SettingsLocal, SettingsLocal, QDistinct>
      distinctByBiometricEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'biometricEnabled');
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QDistinct>
      distinctByDebtOverdueDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'debtOverdueDays');
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QDistinct>
      distinctByInactivityTimeoutMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inactivityTimeoutMinutes');
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QDistinct>
      distinctByLastApiVersionCheck() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastApiVersionCheck');
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QDistinct> distinctByLocale(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'locale', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QDistinct>
      distinctByLowStockThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lowStockThreshold');
    });
  }

  QueryBuilder<SettingsLocal, SettingsLocal, QDistinct> distinctByPinHash(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pinHash', caseSensitive: caseSensitive);
    });
  }
}

extension SettingsLocalQueryProperty
    on QueryBuilder<SettingsLocal, SettingsLocal, QQueryProperty> {
  QueryBuilder<SettingsLocal, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<SettingsLocal, bool, QQueryOperations>
      biometricEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'biometricEnabled');
    });
  }

  QueryBuilder<SettingsLocal, int, QQueryOperations> debtOverdueDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'debtOverdueDays');
    });
  }

  QueryBuilder<SettingsLocal, int, QQueryOperations>
      inactivityTimeoutMinutesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inactivityTimeoutMinutes');
    });
  }

  QueryBuilder<SettingsLocal, int?, QQueryOperations>
      lastApiVersionCheckProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastApiVersionCheck');
    });
  }

  QueryBuilder<SettingsLocal, String, QQueryOperations> localeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'locale');
    });
  }

  QueryBuilder<SettingsLocal, int, QQueryOperations>
      lowStockThresholdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lowStockThreshold');
    });
  }

  QueryBuilder<SettingsLocal, String?, QQueryOperations> pinHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pinHash');
    });
  }
}
