// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ow_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _walletSourceMeta = const VerificationMeta(
    'walletSource',
  );
  @override
  late final GeneratedColumn<String> walletSource = GeneratedColumn<String>(
    'wallet_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exchangeMeta = const VerificationMeta(
    'exchange',
  );
  @override
  late final GeneratedColumn<String> exchange = GeneratedColumn<String>(
    'exchange',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vaultItemIdMeta = const VerificationMeta(
    'vaultItemId',
  );
  @override
  late final GeneratedColumn<String> vaultItemId = GeneratedColumn<String>(
    'vault_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offlineBackedUpMeta = const VerificationMeta(
    'offlineBackedUp',
  );
  @override
  late final GeneratedColumn<bool> offlineBackedUp = GeneratedColumn<bool>(
    'offline_backed_up',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("offline_backed_up" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _offlineVerifiedAtMeta = const VerificationMeta(
    'offlineVerifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> offlineVerifiedAt =
      GeneratedColumn<DateTime>(
        'offline_verified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _keylessMeta = const VerificationMeta(
    'keyless',
  );
  @override
  late final GeneratedColumn<bool> keyless = GeneratedColumn<bool>(
    'keyless',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keyless" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    colorIndex,
    note,
    walletSource,
    exchange,
    vaultItemId,
    offlineBackedUp,
    offlineVerifiedAt,
    keyless,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorIndexMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('wallet_source')) {
      context.handle(
        _walletSourceMeta,
        walletSource.isAcceptableOrUnknown(
          data['wallet_source']!,
          _walletSourceMeta,
        ),
      );
    }
    if (data.containsKey('exchange')) {
      context.handle(
        _exchangeMeta,
        exchange.isAcceptableOrUnknown(data['exchange']!, _exchangeMeta),
      );
    }
    if (data.containsKey('vault_item_id')) {
      context.handle(
        _vaultItemIdMeta,
        vaultItemId.isAcceptableOrUnknown(
          data['vault_item_id']!,
          _vaultItemIdMeta,
        ),
      );
    }
    if (data.containsKey('offline_backed_up')) {
      context.handle(
        _offlineBackedUpMeta,
        offlineBackedUp.isAcceptableOrUnknown(
          data['offline_backed_up']!,
          _offlineBackedUpMeta,
        ),
      );
    }
    if (data.containsKey('offline_verified_at')) {
      context.handle(
        _offlineVerifiedAtMeta,
        offlineVerifiedAt.isAcceptableOrUnknown(
          data['offline_verified_at']!,
          _offlineVerifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('keyless')) {
      context.handle(
        _keylessMeta,
        keyless.isAcceptableOrUnknown(data['keyless']!, _keylessMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      walletSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet_source'],
      ),
      exchange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange'],
      ),
      vaultItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_item_id'],
      ),
      offlineBackedUp: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}offline_backed_up'],
      )!,
      offlineVerifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}offline_verified_at'],
      ),
      keyless: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keyless'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;
  final String type;
  final String name;
  final int colorIndex;
  final String note;
  final String? walletSource;
  final String? exchange;
  final String? vaultItemId;
  final bool offlineBackedUp;
  final DateTime? offlineVerifiedAt;
  final bool keyless;
  final DateTime createdAt;
  const AccountRow({
    required this.id,
    required this.type,
    required this.name,
    required this.colorIndex,
    required this.note,
    this.walletSource,
    this.exchange,
    this.vaultItemId,
    required this.offlineBackedUp,
    this.offlineVerifiedAt,
    required this.keyless,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['color_index'] = Variable<int>(colorIndex);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || walletSource != null) {
      map['wallet_source'] = Variable<String>(walletSource);
    }
    if (!nullToAbsent || exchange != null) {
      map['exchange'] = Variable<String>(exchange);
    }
    if (!nullToAbsent || vaultItemId != null) {
      map['vault_item_id'] = Variable<String>(vaultItemId);
    }
    map['offline_backed_up'] = Variable<bool>(offlineBackedUp);
    if (!nullToAbsent || offlineVerifiedAt != null) {
      map['offline_verified_at'] = Variable<DateTime>(offlineVerifiedAt);
    }
    map['keyless'] = Variable<bool>(keyless);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      colorIndex: Value(colorIndex),
      note: Value(note),
      walletSource: walletSource == null && nullToAbsent
          ? const Value.absent()
          : Value(walletSource),
      exchange: exchange == null && nullToAbsent
          ? const Value.absent()
          : Value(exchange),
      vaultItemId: vaultItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(vaultItemId),
      offlineBackedUp: Value(offlineBackedUp),
      offlineVerifiedAt: offlineVerifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(offlineVerifiedAt),
      keyless: Value(keyless),
      createdAt: Value(createdAt),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      note: serializer.fromJson<String>(json['note']),
      walletSource: serializer.fromJson<String?>(json['walletSource']),
      exchange: serializer.fromJson<String?>(json['exchange']),
      vaultItemId: serializer.fromJson<String?>(json['vaultItemId']),
      offlineBackedUp: serializer.fromJson<bool>(json['offlineBackedUp']),
      offlineVerifiedAt: serializer.fromJson<DateTime?>(
        json['offlineVerifiedAt'],
      ),
      keyless: serializer.fromJson<bool>(json['keyless']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'note': serializer.toJson<String>(note),
      'walletSource': serializer.toJson<String?>(walletSource),
      'exchange': serializer.toJson<String?>(exchange),
      'vaultItemId': serializer.toJson<String?>(vaultItemId),
      'offlineBackedUp': serializer.toJson<bool>(offlineBackedUp),
      'offlineVerifiedAt': serializer.toJson<DateTime?>(offlineVerifiedAt),
      'keyless': serializer.toJson<bool>(keyless),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AccountRow copyWith({
    String? id,
    String? type,
    String? name,
    int? colorIndex,
    String? note,
    Value<String?> walletSource = const Value.absent(),
    Value<String?> exchange = const Value.absent(),
    Value<String?> vaultItemId = const Value.absent(),
    bool? offlineBackedUp,
    Value<DateTime?> offlineVerifiedAt = const Value.absent(),
    bool? keyless,
    DateTime? createdAt,
  }) => AccountRow(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    note: note ?? this.note,
    walletSource: walletSource.present ? walletSource.value : this.walletSource,
    exchange: exchange.present ? exchange.value : this.exchange,
    vaultItemId: vaultItemId.present ? vaultItemId.value : this.vaultItemId,
    offlineBackedUp: offlineBackedUp ?? this.offlineBackedUp,
    offlineVerifiedAt: offlineVerifiedAt.present
        ? offlineVerifiedAt.value
        : this.offlineVerifiedAt,
    keyless: keyless ?? this.keyless,
    createdAt: createdAt ?? this.createdAt,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      note: data.note.present ? data.note.value : this.note,
      walletSource: data.walletSource.present
          ? data.walletSource.value
          : this.walletSource,
      exchange: data.exchange.present ? data.exchange.value : this.exchange,
      vaultItemId: data.vaultItemId.present
          ? data.vaultItemId.value
          : this.vaultItemId,
      offlineBackedUp: data.offlineBackedUp.present
          ? data.offlineBackedUp.value
          : this.offlineBackedUp,
      offlineVerifiedAt: data.offlineVerifiedAt.present
          ? data.offlineVerifiedAt.value
          : this.offlineVerifiedAt,
      keyless: data.keyless.present ? data.keyless.value : this.keyless,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('note: $note, ')
          ..write('walletSource: $walletSource, ')
          ..write('exchange: $exchange, ')
          ..write('vaultItemId: $vaultItemId, ')
          ..write('offlineBackedUp: $offlineBackedUp, ')
          ..write('offlineVerifiedAt: $offlineVerifiedAt, ')
          ..write('keyless: $keyless, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    colorIndex,
    note,
    walletSource,
    exchange,
    vaultItemId,
    offlineBackedUp,
    offlineVerifiedAt,
    keyless,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex &&
          other.note == this.note &&
          other.walletSource == this.walletSource &&
          other.exchange == this.exchange &&
          other.vaultItemId == this.vaultItemId &&
          other.offlineBackedUp == this.offlineBackedUp &&
          other.offlineVerifiedAt == this.offlineVerifiedAt &&
          other.keyless == this.keyless &&
          other.createdAt == this.createdAt);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> name;
  final Value<int> colorIndex;
  final Value<String> note;
  final Value<String?> walletSource;
  final Value<String?> exchange;
  final Value<String?> vaultItemId;
  final Value<bool> offlineBackedUp;
  final Value<DateTime?> offlineVerifiedAt;
  final Value<bool> keyless;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.note = const Value.absent(),
    this.walletSource = const Value.absent(),
    this.exchange = const Value.absent(),
    this.vaultItemId = const Value.absent(),
    this.offlineBackedUp = const Value.absent(),
    this.offlineVerifiedAt = const Value.absent(),
    this.keyless = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String type,
    required String name,
    required int colorIndex,
    this.note = const Value.absent(),
    this.walletSource = const Value.absent(),
    this.exchange = const Value.absent(),
    this.vaultItemId = const Value.absent(),
    this.offlineBackedUp = const Value.absent(),
    this.offlineVerifiedAt = const Value.absent(),
    this.keyless = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       name = Value(name),
       colorIndex = Value(colorIndex),
       createdAt = Value(createdAt);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<String>? note,
    Expression<String>? walletSource,
    Expression<String>? exchange,
    Expression<String>? vaultItemId,
    Expression<bool>? offlineBackedUp,
    Expression<DateTime>? offlineVerifiedAt,
    Expression<bool>? keyless,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (note != null) 'note': note,
      if (walletSource != null) 'wallet_source': walletSource,
      if (exchange != null) 'exchange': exchange,
      if (vaultItemId != null) 'vault_item_id': vaultItemId,
      if (offlineBackedUp != null) 'offline_backed_up': offlineBackedUp,
      if (offlineVerifiedAt != null) 'offline_verified_at': offlineVerifiedAt,
      if (keyless != null) 'keyless': keyless,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? name,
    Value<int>? colorIndex,
    Value<String>? note,
    Value<String?>? walletSource,
    Value<String?>? exchange,
    Value<String?>? vaultItemId,
    Value<bool>? offlineBackedUp,
    Value<DateTime?>? offlineVerifiedAt,
    Value<bool>? keyless,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      note: note ?? this.note,
      walletSource: walletSource ?? this.walletSource,
      exchange: exchange ?? this.exchange,
      vaultItemId: vaultItemId ?? this.vaultItemId,
      offlineBackedUp: offlineBackedUp ?? this.offlineBackedUp,
      offlineVerifiedAt: offlineVerifiedAt ?? this.offlineVerifiedAt,
      keyless: keyless ?? this.keyless,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (walletSource.present) {
      map['wallet_source'] = Variable<String>(walletSource.value);
    }
    if (exchange.present) {
      map['exchange'] = Variable<String>(exchange.value);
    }
    if (vaultItemId.present) {
      map['vault_item_id'] = Variable<String>(vaultItemId.value);
    }
    if (offlineBackedUp.present) {
      map['offline_backed_up'] = Variable<bool>(offlineBackedUp.value);
    }
    if (offlineVerifiedAt.present) {
      map['offline_verified_at'] = Variable<DateTime>(offlineVerifiedAt.value);
    }
    if (keyless.present) {
      map['keyless'] = Variable<bool>(keyless.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('note: $note, ')
          ..write('walletSource: $walletSource, ')
          ..write('exchange: $exchange, ')
          ..write('vaultItemId: $vaultItemId, ')
          ..write('offlineBackedUp: $offlineBackedUp, ')
          ..write('offlineVerifiedAt: $offlineVerifiedAt, ')
          ..write('keyless: $keyless, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AddressesTable extends Addresses
    with TableInfo<$AddressesTable, AddressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AddressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledChainIdsMeta = const VerificationMeta(
    'enabledChainIds',
  );
  @override
  late final GeneratedColumn<String> enabledChainIds = GeneratedColumn<String>(
    'enabled_chain_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemeMeta = const VerificationMeta('scheme');
  @override
  late final GeneratedColumn<String> scheme = GeneratedColumn<String>(
    'scheme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _derivationIndexMeta = const VerificationMeta(
    'derivationIndex',
  );
  @override
  late final GeneratedColumn<int> derivationIndex = GeneratedColumn<int>(
    'derivation_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    family,
    address,
    enabledChainIds,
    scheme,
    derivationIndex,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'addresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<AddressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    } else if (isInserting) {
      context.missing(_familyMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('enabled_chain_ids')) {
      context.handle(
        _enabledChainIdsMeta,
        enabledChainIds.isAcceptableOrUnknown(
          data['enabled_chain_ids']!,
          _enabledChainIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_enabledChainIdsMeta);
    }
    if (data.containsKey('scheme')) {
      context.handle(
        _schemeMeta,
        scheme.isAcceptableOrUnknown(data['scheme']!, _schemeMeta),
      );
    }
    if (data.containsKey('derivation_index')) {
      context.handle(
        _derivationIndexMeta,
        derivationIndex.isAcceptableOrUnknown(
          data['derivation_index']!,
          _derivationIndexMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AddressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AddressRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      enabledChainIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled_chain_ids'],
      )!,
      scheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheme'],
      ),
      derivationIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}derivation_index'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
    );
  }

  @override
  $AddressesTable createAlias(String alias) {
    return $AddressesTable(attachedDatabase, alias);
  }
}

class AddressRow extends DataClass implements Insertable<AddressRow> {
  final String id;
  final String accountId;
  final String family;
  final String address;

  /// JSON 字符串数组。
  final String enabledChainIds;
  final String? scheme;
  final int? derivationIndex;
  final String note;
  const AddressRow({
    required this.id,
    required this.accountId,
    required this.family,
    required this.address,
    required this.enabledChainIds,
    this.scheme,
    this.derivationIndex,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['family'] = Variable<String>(family);
    map['address'] = Variable<String>(address);
    map['enabled_chain_ids'] = Variable<String>(enabledChainIds);
    if (!nullToAbsent || scheme != null) {
      map['scheme'] = Variable<String>(scheme);
    }
    if (!nullToAbsent || derivationIndex != null) {
      map['derivation_index'] = Variable<int>(derivationIndex);
    }
    map['note'] = Variable<String>(note);
    return map;
  }

  AddressesCompanion toCompanion(bool nullToAbsent) {
    return AddressesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      family: Value(family),
      address: Value(address),
      enabledChainIds: Value(enabledChainIds),
      scheme: scheme == null && nullToAbsent
          ? const Value.absent()
          : Value(scheme),
      derivationIndex: derivationIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(derivationIndex),
      note: Value(note),
    );
  }

  factory AddressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AddressRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      family: serializer.fromJson<String>(json['family']),
      address: serializer.fromJson<String>(json['address']),
      enabledChainIds: serializer.fromJson<String>(json['enabledChainIds']),
      scheme: serializer.fromJson<String?>(json['scheme']),
      derivationIndex: serializer.fromJson<int?>(json['derivationIndex']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'family': serializer.toJson<String>(family),
      'address': serializer.toJson<String>(address),
      'enabledChainIds': serializer.toJson<String>(enabledChainIds),
      'scheme': serializer.toJson<String?>(scheme),
      'derivationIndex': serializer.toJson<int?>(derivationIndex),
      'note': serializer.toJson<String>(note),
    };
  }

  AddressRow copyWith({
    String? id,
    String? accountId,
    String? family,
    String? address,
    String? enabledChainIds,
    Value<String?> scheme = const Value.absent(),
    Value<int?> derivationIndex = const Value.absent(),
    String? note,
  }) => AddressRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    family: family ?? this.family,
    address: address ?? this.address,
    enabledChainIds: enabledChainIds ?? this.enabledChainIds,
    scheme: scheme.present ? scheme.value : this.scheme,
    derivationIndex: derivationIndex.present
        ? derivationIndex.value
        : this.derivationIndex,
    note: note ?? this.note,
  );
  AddressRow copyWithCompanion(AddressesCompanion data) {
    return AddressRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      family: data.family.present ? data.family.value : this.family,
      address: data.address.present ? data.address.value : this.address,
      enabledChainIds: data.enabledChainIds.present
          ? data.enabledChainIds.value
          : this.enabledChainIds,
      scheme: data.scheme.present ? data.scheme.value : this.scheme,
      derivationIndex: data.derivationIndex.present
          ? data.derivationIndex.value
          : this.derivationIndex,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AddressRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('family: $family, ')
          ..write('address: $address, ')
          ..write('enabledChainIds: $enabledChainIds, ')
          ..write('scheme: $scheme, ')
          ..write('derivationIndex: $derivationIndex, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    family,
    address,
    enabledChainIds,
    scheme,
    derivationIndex,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AddressRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.family == this.family &&
          other.address == this.address &&
          other.enabledChainIds == this.enabledChainIds &&
          other.scheme == this.scheme &&
          other.derivationIndex == this.derivationIndex &&
          other.note == this.note);
}

class AddressesCompanion extends UpdateCompanion<AddressRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> family;
  final Value<String> address;
  final Value<String> enabledChainIds;
  final Value<String?> scheme;
  final Value<int?> derivationIndex;
  final Value<String> note;
  final Value<int> rowid;
  const AddressesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.family = const Value.absent(),
    this.address = const Value.absent(),
    this.enabledChainIds = const Value.absent(),
    this.scheme = const Value.absent(),
    this.derivationIndex = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AddressesCompanion.insert({
    required String id,
    required String accountId,
    required String family,
    required String address,
    required String enabledChainIds,
    this.scheme = const Value.absent(),
    this.derivationIndex = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       family = Value(family),
       address = Value(address),
       enabledChainIds = Value(enabledChainIds);
  static Insertable<AddressRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? family,
    Expression<String>? address,
    Expression<String>? enabledChainIds,
    Expression<String>? scheme,
    Expression<int>? derivationIndex,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (family != null) 'family': family,
      if (address != null) 'address': address,
      if (enabledChainIds != null) 'enabled_chain_ids': enabledChainIds,
      if (scheme != null) 'scheme': scheme,
      if (derivationIndex != null) 'derivation_index': derivationIndex,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AddressesCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? family,
    Value<String>? address,
    Value<String>? enabledChainIds,
    Value<String?>? scheme,
    Value<int?>? derivationIndex,
    Value<String>? note,
    Value<int>? rowid,
  }) {
    return AddressesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      family: family ?? this.family,
      address: address ?? this.address,
      enabledChainIds: enabledChainIds ?? this.enabledChainIds,
      scheme: scheme ?? this.scheme,
      derivationIndex: derivationIndex ?? this.derivationIndex,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (enabledChainIds.present) {
      map['enabled_chain_ids'] = Variable<String>(enabledChainIds.value);
    }
    if (scheme.present) {
      map['scheme'] = Variable<String>(scheme.value);
    }
    if (derivationIndex.present) {
      map['derivation_index'] = Variable<int>(derivationIndex.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AddressesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('family: $family, ')
          ..write('address: $address, ')
          ..write('enabledChainIds: $enabledChainIds, ')
          ..write('scheme: $scheme, ')
          ..write('derivationIndex: $derivationIndex, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HoldingsTable extends Holdings
    with TableInfo<$HoldingsTable, HoldingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _locationKindMeta = const VerificationMeta(
    'locationKind',
  );
  @override
  late final GeneratedColumn<String> locationKind = GeneratedColumn<String>(
    'location_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chainIdMeta = const VerificationMeta(
    'chainId',
  );
  @override
  late final GeneratedColumn<String> chainId = GeneratedColumn<String>(
    'chain_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressIdMeta = const VerificationMeta(
    'addressId',
  );
  @override
  late final GeneratedColumn<String> addressId = GeneratedColumn<String>(
    'address_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exchangeSubMeta = const VerificationMeta(
    'exchangeSub',
  );
  @override
  late final GeneratedColumn<String> exchangeSub = GeneratedColumn<String>(
    'exchange_sub',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokenKindMeta = const VerificationMeta(
    'tokenKind',
  );
  @override
  late final GeneratedColumn<String> tokenKind = GeneratedColumn<String>(
    'token_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenChainIdMeta = const VerificationMeta(
    'tokenChainId',
  );
  @override
  late final GeneratedColumn<String> tokenChainId = GeneratedColumn<String>(
    'token_chain_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokenContractMeta = const VerificationMeta(
    'tokenContract',
  );
  @override
  late final GeneratedColumn<String> tokenContract = GeneratedColumn<String>(
    'token_contract',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokenSymbolMeta = const VerificationMeta(
    'tokenSymbol',
  );
  @override
  late final GeneratedColumn<String> tokenSymbol = GeneratedColumn<String>(
    'token_symbol',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displaySymbolMeta = const VerificationMeta(
    'displaySymbol',
  );
  @override
  late final GeneratedColumn<String> displaySymbol = GeneratedColumn<String>(
    'display_symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    locationKind,
    chainId,
    addressId,
    exchangeSub,
    tokenKind,
    tokenChainId,
    tokenContract,
    tokenSymbol,
    assetId,
    displaySymbol,
    amount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holdings';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoldingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('location_kind')) {
      context.handle(
        _locationKindMeta,
        locationKind.isAcceptableOrUnknown(
          data['location_kind']!,
          _locationKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locationKindMeta);
    }
    if (data.containsKey('chain_id')) {
      context.handle(
        _chainIdMeta,
        chainId.isAcceptableOrUnknown(data['chain_id']!, _chainIdMeta),
      );
    }
    if (data.containsKey('address_id')) {
      context.handle(
        _addressIdMeta,
        addressId.isAcceptableOrUnknown(data['address_id']!, _addressIdMeta),
      );
    }
    if (data.containsKey('exchange_sub')) {
      context.handle(
        _exchangeSubMeta,
        exchangeSub.isAcceptableOrUnknown(
          data['exchange_sub']!,
          _exchangeSubMeta,
        ),
      );
    }
    if (data.containsKey('token_kind')) {
      context.handle(
        _tokenKindMeta,
        tokenKind.isAcceptableOrUnknown(data['token_kind']!, _tokenKindMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenKindMeta);
    }
    if (data.containsKey('token_chain_id')) {
      context.handle(
        _tokenChainIdMeta,
        tokenChainId.isAcceptableOrUnknown(
          data['token_chain_id']!,
          _tokenChainIdMeta,
        ),
      );
    }
    if (data.containsKey('token_contract')) {
      context.handle(
        _tokenContractMeta,
        tokenContract.isAcceptableOrUnknown(
          data['token_contract']!,
          _tokenContractMeta,
        ),
      );
    }
    if (data.containsKey('token_symbol')) {
      context.handle(
        _tokenSymbolMeta,
        tokenSymbol.isAcceptableOrUnknown(
          data['token_symbol']!,
          _tokenSymbolMeta,
        ),
      );
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    }
    if (data.containsKey('display_symbol')) {
      context.handle(
        _displaySymbolMeta,
        displaySymbol.isAcceptableOrUnknown(
          data['display_symbol']!,
          _displaySymbolMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displaySymbolMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HoldingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoldingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      locationKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_kind'],
      )!,
      chainId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chain_id'],
      ),
      addressId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_id'],
      ),
      exchangeSub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange_sub'],
      ),
      tokenKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_kind'],
      )!,
      tokenChainId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_chain_id'],
      ),
      tokenContract: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_contract'],
      ),
      tokenSymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_symbol'],
      ),
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      ),
      displaySymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_symbol'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $HoldingsTable createAlias(String alias) {
    return $HoldingsTable(attachedDatabase, alias);
  }
}

class HoldingRow extends DataClass implements Insertable<HoldingRow> {
  final int id;
  final String accountId;

  /// `onchain` 或 `exchange`。
  final String locationKind;
  final String? chainId;
  final String? addressId;
  final String? exchangeSub;

  /// `native`、`contract` 或 `exchange`。
  final String tokenKind;

  /// native/contract 为链 id；exchange 为交易所 id（规格未给交易所列，复用本列）。
  final String? tokenChainId;
  final String? tokenContract;
  final String? tokenSymbol;
  final String? assetId;
  final String displaySymbol;
  final String amount;
  final DateTime updatedAt;
  const HoldingRow({
    required this.id,
    required this.accountId,
    required this.locationKind,
    this.chainId,
    this.addressId,
    this.exchangeSub,
    required this.tokenKind,
    this.tokenChainId,
    this.tokenContract,
    this.tokenSymbol,
    this.assetId,
    required this.displaySymbol,
    required this.amount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<String>(accountId);
    map['location_kind'] = Variable<String>(locationKind);
    if (!nullToAbsent || chainId != null) {
      map['chain_id'] = Variable<String>(chainId);
    }
    if (!nullToAbsent || addressId != null) {
      map['address_id'] = Variable<String>(addressId);
    }
    if (!nullToAbsent || exchangeSub != null) {
      map['exchange_sub'] = Variable<String>(exchangeSub);
    }
    map['token_kind'] = Variable<String>(tokenKind);
    if (!nullToAbsent || tokenChainId != null) {
      map['token_chain_id'] = Variable<String>(tokenChainId);
    }
    if (!nullToAbsent || tokenContract != null) {
      map['token_contract'] = Variable<String>(tokenContract);
    }
    if (!nullToAbsent || tokenSymbol != null) {
      map['token_symbol'] = Variable<String>(tokenSymbol);
    }
    if (!nullToAbsent || assetId != null) {
      map['asset_id'] = Variable<String>(assetId);
    }
    map['display_symbol'] = Variable<String>(displaySymbol);
    map['amount'] = Variable<String>(amount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HoldingsCompanion toCompanion(bool nullToAbsent) {
    return HoldingsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      locationKind: Value(locationKind),
      chainId: chainId == null && nullToAbsent
          ? const Value.absent()
          : Value(chainId),
      addressId: addressId == null && nullToAbsent
          ? const Value.absent()
          : Value(addressId),
      exchangeSub: exchangeSub == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeSub),
      tokenKind: Value(tokenKind),
      tokenChainId: tokenChainId == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenChainId),
      tokenContract: tokenContract == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenContract),
      tokenSymbol: tokenSymbol == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenSymbol),
      assetId: assetId == null && nullToAbsent
          ? const Value.absent()
          : Value(assetId),
      displaySymbol: Value(displaySymbol),
      amount: Value(amount),
      updatedAt: Value(updatedAt),
    );
  }

  factory HoldingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoldingRow(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      locationKind: serializer.fromJson<String>(json['locationKind']),
      chainId: serializer.fromJson<String?>(json['chainId']),
      addressId: serializer.fromJson<String?>(json['addressId']),
      exchangeSub: serializer.fromJson<String?>(json['exchangeSub']),
      tokenKind: serializer.fromJson<String>(json['tokenKind']),
      tokenChainId: serializer.fromJson<String?>(json['tokenChainId']),
      tokenContract: serializer.fromJson<String?>(json['tokenContract']),
      tokenSymbol: serializer.fromJson<String?>(json['tokenSymbol']),
      assetId: serializer.fromJson<String?>(json['assetId']),
      displaySymbol: serializer.fromJson<String>(json['displaySymbol']),
      amount: serializer.fromJson<String>(json['amount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<String>(accountId),
      'locationKind': serializer.toJson<String>(locationKind),
      'chainId': serializer.toJson<String?>(chainId),
      'addressId': serializer.toJson<String?>(addressId),
      'exchangeSub': serializer.toJson<String?>(exchangeSub),
      'tokenKind': serializer.toJson<String>(tokenKind),
      'tokenChainId': serializer.toJson<String?>(tokenChainId),
      'tokenContract': serializer.toJson<String?>(tokenContract),
      'tokenSymbol': serializer.toJson<String?>(tokenSymbol),
      'assetId': serializer.toJson<String?>(assetId),
      'displaySymbol': serializer.toJson<String>(displaySymbol),
      'amount': serializer.toJson<String>(amount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  HoldingRow copyWith({
    int? id,
    String? accountId,
    String? locationKind,
    Value<String?> chainId = const Value.absent(),
    Value<String?> addressId = const Value.absent(),
    Value<String?> exchangeSub = const Value.absent(),
    String? tokenKind,
    Value<String?> tokenChainId = const Value.absent(),
    Value<String?> tokenContract = const Value.absent(),
    Value<String?> tokenSymbol = const Value.absent(),
    Value<String?> assetId = const Value.absent(),
    String? displaySymbol,
    String? amount,
    DateTime? updatedAt,
  }) => HoldingRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    locationKind: locationKind ?? this.locationKind,
    chainId: chainId.present ? chainId.value : this.chainId,
    addressId: addressId.present ? addressId.value : this.addressId,
    exchangeSub: exchangeSub.present ? exchangeSub.value : this.exchangeSub,
    tokenKind: tokenKind ?? this.tokenKind,
    tokenChainId: tokenChainId.present ? tokenChainId.value : this.tokenChainId,
    tokenContract: tokenContract.present
        ? tokenContract.value
        : this.tokenContract,
    tokenSymbol: tokenSymbol.present ? tokenSymbol.value : this.tokenSymbol,
    assetId: assetId.present ? assetId.value : this.assetId,
    displaySymbol: displaySymbol ?? this.displaySymbol,
    amount: amount ?? this.amount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  HoldingRow copyWithCompanion(HoldingsCompanion data) {
    return HoldingRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      locationKind: data.locationKind.present
          ? data.locationKind.value
          : this.locationKind,
      chainId: data.chainId.present ? data.chainId.value : this.chainId,
      addressId: data.addressId.present ? data.addressId.value : this.addressId,
      exchangeSub: data.exchangeSub.present
          ? data.exchangeSub.value
          : this.exchangeSub,
      tokenKind: data.tokenKind.present ? data.tokenKind.value : this.tokenKind,
      tokenChainId: data.tokenChainId.present
          ? data.tokenChainId.value
          : this.tokenChainId,
      tokenContract: data.tokenContract.present
          ? data.tokenContract.value
          : this.tokenContract,
      tokenSymbol: data.tokenSymbol.present
          ? data.tokenSymbol.value
          : this.tokenSymbol,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      displaySymbol: data.displaySymbol.present
          ? data.displaySymbol.value
          : this.displaySymbol,
      amount: data.amount.present ? data.amount.value : this.amount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoldingRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('locationKind: $locationKind, ')
          ..write('chainId: $chainId, ')
          ..write('addressId: $addressId, ')
          ..write('exchangeSub: $exchangeSub, ')
          ..write('tokenKind: $tokenKind, ')
          ..write('tokenChainId: $tokenChainId, ')
          ..write('tokenContract: $tokenContract, ')
          ..write('tokenSymbol: $tokenSymbol, ')
          ..write('assetId: $assetId, ')
          ..write('displaySymbol: $displaySymbol, ')
          ..write('amount: $amount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    locationKind,
    chainId,
    addressId,
    exchangeSub,
    tokenKind,
    tokenChainId,
    tokenContract,
    tokenSymbol,
    assetId,
    displaySymbol,
    amount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoldingRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.locationKind == this.locationKind &&
          other.chainId == this.chainId &&
          other.addressId == this.addressId &&
          other.exchangeSub == this.exchangeSub &&
          other.tokenKind == this.tokenKind &&
          other.tokenChainId == this.tokenChainId &&
          other.tokenContract == this.tokenContract &&
          other.tokenSymbol == this.tokenSymbol &&
          other.assetId == this.assetId &&
          other.displaySymbol == this.displaySymbol &&
          other.amount == this.amount &&
          other.updatedAt == this.updatedAt);
}

class HoldingsCompanion extends UpdateCompanion<HoldingRow> {
  final Value<int> id;
  final Value<String> accountId;
  final Value<String> locationKind;
  final Value<String?> chainId;
  final Value<String?> addressId;
  final Value<String?> exchangeSub;
  final Value<String> tokenKind;
  final Value<String?> tokenChainId;
  final Value<String?> tokenContract;
  final Value<String?> tokenSymbol;
  final Value<String?> assetId;
  final Value<String> displaySymbol;
  final Value<String> amount;
  final Value<DateTime> updatedAt;
  const HoldingsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.locationKind = const Value.absent(),
    this.chainId = const Value.absent(),
    this.addressId = const Value.absent(),
    this.exchangeSub = const Value.absent(),
    this.tokenKind = const Value.absent(),
    this.tokenChainId = const Value.absent(),
    this.tokenContract = const Value.absent(),
    this.tokenSymbol = const Value.absent(),
    this.assetId = const Value.absent(),
    this.displaySymbol = const Value.absent(),
    this.amount = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  HoldingsCompanion.insert({
    this.id = const Value.absent(),
    required String accountId,
    required String locationKind,
    this.chainId = const Value.absent(),
    this.addressId = const Value.absent(),
    this.exchangeSub = const Value.absent(),
    required String tokenKind,
    this.tokenChainId = const Value.absent(),
    this.tokenContract = const Value.absent(),
    this.tokenSymbol = const Value.absent(),
    this.assetId = const Value.absent(),
    required String displaySymbol,
    required String amount,
    required DateTime updatedAt,
  }) : accountId = Value(accountId),
       locationKind = Value(locationKind),
       tokenKind = Value(tokenKind),
       displaySymbol = Value(displaySymbol),
       amount = Value(amount),
       updatedAt = Value(updatedAt);
  static Insertable<HoldingRow> custom({
    Expression<int>? id,
    Expression<String>? accountId,
    Expression<String>? locationKind,
    Expression<String>? chainId,
    Expression<String>? addressId,
    Expression<String>? exchangeSub,
    Expression<String>? tokenKind,
    Expression<String>? tokenChainId,
    Expression<String>? tokenContract,
    Expression<String>? tokenSymbol,
    Expression<String>? assetId,
    Expression<String>? displaySymbol,
    Expression<String>? amount,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (locationKind != null) 'location_kind': locationKind,
      if (chainId != null) 'chain_id': chainId,
      if (addressId != null) 'address_id': addressId,
      if (exchangeSub != null) 'exchange_sub': exchangeSub,
      if (tokenKind != null) 'token_kind': tokenKind,
      if (tokenChainId != null) 'token_chain_id': tokenChainId,
      if (tokenContract != null) 'token_contract': tokenContract,
      if (tokenSymbol != null) 'token_symbol': tokenSymbol,
      if (assetId != null) 'asset_id': assetId,
      if (displaySymbol != null) 'display_symbol': displaySymbol,
      if (amount != null) 'amount': amount,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  HoldingsCompanion copyWith({
    Value<int>? id,
    Value<String>? accountId,
    Value<String>? locationKind,
    Value<String?>? chainId,
    Value<String?>? addressId,
    Value<String?>? exchangeSub,
    Value<String>? tokenKind,
    Value<String?>? tokenChainId,
    Value<String?>? tokenContract,
    Value<String?>? tokenSymbol,
    Value<String?>? assetId,
    Value<String>? displaySymbol,
    Value<String>? amount,
    Value<DateTime>? updatedAt,
  }) {
    return HoldingsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      locationKind: locationKind ?? this.locationKind,
      chainId: chainId ?? this.chainId,
      addressId: addressId ?? this.addressId,
      exchangeSub: exchangeSub ?? this.exchangeSub,
      tokenKind: tokenKind ?? this.tokenKind,
      tokenChainId: tokenChainId ?? this.tokenChainId,
      tokenContract: tokenContract ?? this.tokenContract,
      tokenSymbol: tokenSymbol ?? this.tokenSymbol,
      assetId: assetId ?? this.assetId,
      displaySymbol: displaySymbol ?? this.displaySymbol,
      amount: amount ?? this.amount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (locationKind.present) {
      map['location_kind'] = Variable<String>(locationKind.value);
    }
    if (chainId.present) {
      map['chain_id'] = Variable<String>(chainId.value);
    }
    if (addressId.present) {
      map['address_id'] = Variable<String>(addressId.value);
    }
    if (exchangeSub.present) {
      map['exchange_sub'] = Variable<String>(exchangeSub.value);
    }
    if (tokenKind.present) {
      map['token_kind'] = Variable<String>(tokenKind.value);
    }
    if (tokenChainId.present) {
      map['token_chain_id'] = Variable<String>(tokenChainId.value);
    }
    if (tokenContract.present) {
      map['token_contract'] = Variable<String>(tokenContract.value);
    }
    if (tokenSymbol.present) {
      map['token_symbol'] = Variable<String>(tokenSymbol.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (displaySymbol.present) {
      map['display_symbol'] = Variable<String>(displaySymbol.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('locationKind: $locationKind, ')
          ..write('chainId: $chainId, ')
          ..write('addressId: $addressId, ')
          ..write('exchangeSub: $exchangeSub, ')
          ..write('tokenKind: $tokenKind, ')
          ..write('tokenChainId: $tokenChainId, ')
          ..write('tokenContract: $tokenContract, ')
          ..write('tokenSymbol: $tokenSymbol, ')
          ..write('assetId: $assetId, ')
          ..write('displaySymbol: $displaySymbol, ')
          ..write('amount: $amount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PricesTable extends Prices with TableInfo<$PricesTable, PriceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteMeta = const VerificationMeta('quote');
  @override
  late final GeneratedColumn<String> quote = GeneratedColumn<String>(
    'quote',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<String> price = GeneratedColumn<String>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _change24hPercentMeta = const VerificationMeta(
    'change24hPercent',
  );
  @override
  late final GeneratedColumn<String> change24hPercent = GeneratedColumn<String>(
    'change24h_percent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    assetId,
    quote,
    price,
    change24hPercent,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prices';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('quote')) {
      context.handle(
        _quoteMeta,
        quote.isAcceptableOrUnknown(data['quote']!, _quoteMeta),
      );
    } else if (isInserting) {
      context.missing(_quoteMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('change24h_percent')) {
      context.handle(
        _change24hPercentMeta,
        change24hPercent.isAcceptableOrUnknown(
          data['change24h_percent']!,
          _change24hPercentMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId, quote};
  @override
  PriceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceRow(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      quote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}price'],
      )!,
      change24hPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change24h_percent'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PricesTable createAlias(String alias) {
    return $PricesTable(attachedDatabase, alias);
  }
}

class PriceRow extends DataClass implements Insertable<PriceRow> {
  final String assetId;
  final String quote;
  final String price;
  final String? change24hPercent;
  final DateTime updatedAt;
  const PriceRow({
    required this.assetId,
    required this.quote,
    required this.price,
    this.change24hPercent,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['quote'] = Variable<String>(quote);
    map['price'] = Variable<String>(price);
    if (!nullToAbsent || change24hPercent != null) {
      map['change24h_percent'] = Variable<String>(change24hPercent);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PricesCompanion toCompanion(bool nullToAbsent) {
    return PricesCompanion(
      assetId: Value(assetId),
      quote: Value(quote),
      price: Value(price),
      change24hPercent: change24hPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(change24hPercent),
      updatedAt: Value(updatedAt),
    );
  }

  factory PriceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceRow(
      assetId: serializer.fromJson<String>(json['assetId']),
      quote: serializer.fromJson<String>(json['quote']),
      price: serializer.fromJson<String>(json['price']),
      change24hPercent: serializer.fromJson<String?>(json['change24hPercent']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'quote': serializer.toJson<String>(quote),
      'price': serializer.toJson<String>(price),
      'change24hPercent': serializer.toJson<String?>(change24hPercent),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PriceRow copyWith({
    String? assetId,
    String? quote,
    String? price,
    Value<String?> change24hPercent = const Value.absent(),
    DateTime? updatedAt,
  }) => PriceRow(
    assetId: assetId ?? this.assetId,
    quote: quote ?? this.quote,
    price: price ?? this.price,
    change24hPercent: change24hPercent.present
        ? change24hPercent.value
        : this.change24hPercent,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PriceRow copyWithCompanion(PricesCompanion data) {
    return PriceRow(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      quote: data.quote.present ? data.quote.value : this.quote,
      price: data.price.present ? data.price.value : this.price,
      change24hPercent: data.change24hPercent.present
          ? data.change24hPercent.value
          : this.change24hPercent,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceRow(')
          ..write('assetId: $assetId, ')
          ..write('quote: $quote, ')
          ..write('price: $price, ')
          ..write('change24hPercent: $change24hPercent, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(assetId, quote, price, change24hPercent, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceRow &&
          other.assetId == this.assetId &&
          other.quote == this.quote &&
          other.price == this.price &&
          other.change24hPercent == this.change24hPercent &&
          other.updatedAt == this.updatedAt);
}

class PricesCompanion extends UpdateCompanion<PriceRow> {
  final Value<String> assetId;
  final Value<String> quote;
  final Value<String> price;
  final Value<String?> change24hPercent;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PricesCompanion({
    this.assetId = const Value.absent(),
    this.quote = const Value.absent(),
    this.price = const Value.absent(),
    this.change24hPercent = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricesCompanion.insert({
    required String assetId,
    required String quote,
    required String price,
    this.change24hPercent = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       quote = Value(quote),
       price = Value(price),
       updatedAt = Value(updatedAt);
  static Insertable<PriceRow> custom({
    Expression<String>? assetId,
    Expression<String>? quote,
    Expression<String>? price,
    Expression<String>? change24hPercent,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (quote != null) 'quote': quote,
      if (price != null) 'price': price,
      if (change24hPercent != null) 'change24h_percent': change24hPercent,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricesCompanion copyWith({
    Value<String>? assetId,
    Value<String>? quote,
    Value<String>? price,
    Value<String?>? change24hPercent,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PricesCompanion(
      assetId: assetId ?? this.assetId,
      quote: quote ?? this.quote,
      price: price ?? this.price,
      change24hPercent: change24hPercent ?? this.change24hPercent,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (quote.present) {
      map['quote'] = Variable<String>(quote.value);
    }
    if (price.present) {
      map['price'] = Variable<String>(price.value);
    }
    if (change24hPercent.present) {
      map['change24h_percent'] = Variable<String>(change24hPercent.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricesCompanion(')
          ..write('assetId: $assetId, ')
          ..write('quote: $quote, ')
          ..write('price: $price, ')
          ..write('change24hPercent: $change24hPercent, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnapshotsTable extends Snapshots
    with TableInfo<$SnapshotsTable, SnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalUsdMeta = const VerificationMeta(
    'totalUsd',
  );
  @override
  late final GeneratedColumn<String> totalUsd = GeneratedColumn<String>(
    'total_usd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completeMeta = const VerificationMeta(
    'complete',
  );
  @override
  late final GeneratedColumn<bool> complete = GeneratedColumn<bool>(
    'complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("complete" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [date, totalUsd, complete];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('total_usd')) {
      context.handle(
        _totalUsdMeta,
        totalUsd.isAcceptableOrUnknown(data['total_usd']!, _totalUsdMeta),
      );
    } else if (isInserting) {
      context.missing(_totalUsdMeta);
    }
    if (data.containsKey('complete')) {
      context.handle(
        _completeMeta,
        complete.isAcceptableOrUnknown(data['complete']!, _completeMeta),
      );
    } else if (isInserting) {
      context.missing(_completeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  SnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      totalUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}total_usd'],
      )!,
      complete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}complete'],
      )!,
    );
  }

  @override
  $SnapshotsTable createAlias(String alias) {
    return $SnapshotsTable(attachedDatabase, alias);
  }
}

class SnapshotRow extends DataClass implements Insertable<SnapshotRow> {
  final DateTime date;
  final String totalUsd;
  final bool complete;
  const SnapshotRow({
    required this.date,
    required this.totalUsd,
    required this.complete,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['total_usd'] = Variable<String>(totalUsd);
    map['complete'] = Variable<bool>(complete);
    return map;
  }

  SnapshotsCompanion toCompanion(bool nullToAbsent) {
    return SnapshotsCompanion(
      date: Value(date),
      totalUsd: Value(totalUsd),
      complete: Value(complete),
    );
  }

  factory SnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotRow(
      date: serializer.fromJson<DateTime>(json['date']),
      totalUsd: serializer.fromJson<String>(json['totalUsd']),
      complete: serializer.fromJson<bool>(json['complete']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'totalUsd': serializer.toJson<String>(totalUsd),
      'complete': serializer.toJson<bool>(complete),
    };
  }

  SnapshotRow copyWith({DateTime? date, String? totalUsd, bool? complete}) =>
      SnapshotRow(
        date: date ?? this.date,
        totalUsd: totalUsd ?? this.totalUsd,
        complete: complete ?? this.complete,
      );
  SnapshotRow copyWithCompanion(SnapshotsCompanion data) {
    return SnapshotRow(
      date: data.date.present ? data.date.value : this.date,
      totalUsd: data.totalUsd.present ? data.totalUsd.value : this.totalUsd,
      complete: data.complete.present ? data.complete.value : this.complete,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotRow(')
          ..write('date: $date, ')
          ..write('totalUsd: $totalUsd, ')
          ..write('complete: $complete')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, totalUsd, complete);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotRow &&
          other.date == this.date &&
          other.totalUsd == this.totalUsd &&
          other.complete == this.complete);
}

class SnapshotsCompanion extends UpdateCompanion<SnapshotRow> {
  final Value<DateTime> date;
  final Value<String> totalUsd;
  final Value<bool> complete;
  final Value<int> rowid;
  const SnapshotsCompanion({
    this.date = const Value.absent(),
    this.totalUsd = const Value.absent(),
    this.complete = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnapshotsCompanion.insert({
    required DateTime date,
    required String totalUsd,
    required bool complete,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       totalUsd = Value(totalUsd),
       complete = Value(complete);
  static Insertable<SnapshotRow> custom({
    Expression<DateTime>? date,
    Expression<String>? totalUsd,
    Expression<bool>? complete,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (totalUsd != null) 'total_usd': totalUsd,
      if (complete != null) 'complete': complete,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnapshotsCompanion copyWith({
    Value<DateTime>? date,
    Value<String>? totalUsd,
    Value<bool>? complete,
    Value<int>? rowid,
  }) {
    return SnapshotsCompanion(
      date: date ?? this.date,
      totalUsd: totalUsd ?? this.totalUsd,
      complete: complete ?? this.complete,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (totalUsd.present) {
      map['total_usd'] = Variable<String>(totalUsd.value);
    }
    if (complete.present) {
      map['complete'] = Variable<bool>(complete.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotsCompanion(')
          ..write('date: $date, ')
          ..write('totalUsd: $totalUsd, ')
          ..write('complete: $complete, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnapshotItemsTable extends SnapshotItems
    with TableInfo<$SnapshotItemsTable, SnapshotItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES snapshots (date) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueUsdMeta = const VerificationMeta(
    'valueUsd',
  );
  @override
  late final GeneratedColumn<String> valueUsd = GeneratedColumn<String>(
    'value_usd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date, kind, key, valueUsd];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_usd')) {
      context.handle(
        _valueUsdMeta,
        valueUsd.isAcceptableOrUnknown(data['value_usd']!, _valueUsdMeta),
      );
    } else if (isInserting) {
      context.missing(_valueUsdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, kind, key};
  @override
  SnapshotItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotItemRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_usd'],
      )!,
    );
  }

  @override
  $SnapshotItemsTable createAlias(String alias) {
    return $SnapshotItemsTable(attachedDatabase, alias);
  }
}

class SnapshotItemRow extends DataClass implements Insertable<SnapshotItemRow> {
  final DateTime date;
  final String kind;
  final String key;
  final String valueUsd;
  const SnapshotItemRow({
    required this.date,
    required this.kind,
    required this.key,
    required this.valueUsd,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['kind'] = Variable<String>(kind);
    map['key'] = Variable<String>(key);
    map['value_usd'] = Variable<String>(valueUsd);
    return map;
  }

  SnapshotItemsCompanion toCompanion(bool nullToAbsent) {
    return SnapshotItemsCompanion(
      date: Value(date),
      kind: Value(kind),
      key: Value(key),
      valueUsd: Value(valueUsd),
    );
  }

  factory SnapshotItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotItemRow(
      date: serializer.fromJson<DateTime>(json['date']),
      kind: serializer.fromJson<String>(json['kind']),
      key: serializer.fromJson<String>(json['key']),
      valueUsd: serializer.fromJson<String>(json['valueUsd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'kind': serializer.toJson<String>(kind),
      'key': serializer.toJson<String>(key),
      'valueUsd': serializer.toJson<String>(valueUsd),
    };
  }

  SnapshotItemRow copyWith({
    DateTime? date,
    String? kind,
    String? key,
    String? valueUsd,
  }) => SnapshotItemRow(
    date: date ?? this.date,
    kind: kind ?? this.kind,
    key: key ?? this.key,
    valueUsd: valueUsd ?? this.valueUsd,
  );
  SnapshotItemRow copyWithCompanion(SnapshotItemsCompanion data) {
    return SnapshotItemRow(
      date: data.date.present ? data.date.value : this.date,
      kind: data.kind.present ? data.kind.value : this.kind,
      key: data.key.present ? data.key.value : this.key,
      valueUsd: data.valueUsd.present ? data.valueUsd.value : this.valueUsd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotItemRow(')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('key: $key, ')
          ..write('valueUsd: $valueUsd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, kind, key, valueUsd);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotItemRow &&
          other.date == this.date &&
          other.kind == this.kind &&
          other.key == this.key &&
          other.valueUsd == this.valueUsd);
}

class SnapshotItemsCompanion extends UpdateCompanion<SnapshotItemRow> {
  final Value<DateTime> date;
  final Value<String> kind;
  final Value<String> key;
  final Value<String> valueUsd;
  final Value<int> rowid;
  const SnapshotItemsCompanion({
    this.date = const Value.absent(),
    this.kind = const Value.absent(),
    this.key = const Value.absent(),
    this.valueUsd = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnapshotItemsCompanion.insert({
    required DateTime date,
    required String kind,
    required String key,
    required String valueUsd,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       kind = Value(kind),
       key = Value(key),
       valueUsd = Value(valueUsd);
  static Insertable<SnapshotItemRow> custom({
    Expression<DateTime>? date,
    Expression<String>? kind,
    Expression<String>? key,
    Expression<String>? valueUsd,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (kind != null) 'kind': kind,
      if (key != null) 'key': key,
      if (valueUsd != null) 'value_usd': valueUsd,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnapshotItemsCompanion copyWith({
    Value<DateTime>? date,
    Value<String>? kind,
    Value<String>? key,
    Value<String>? valueUsd,
    Value<int>? rowid,
  }) {
    return SnapshotItemsCompanion(
      date: date ?? this.date,
      kind: kind ?? this.kind,
      key: key ?? this.key,
      valueUsd: valueUsd ?? this.valueUsd,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueUsd.present) {
      map['value_usd'] = Variable<String>(valueUsd.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotItemsCompanion(')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('key: $key, ')
          ..write('valueUsd: $valueUsd, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultItemsMetaTable extends VaultItemsMeta
    with TableInfo<$VaultItemsMetaTable, VaultItemMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultItemsMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasPassphraseMeta = const VerificationMeta(
    'hasPassphrase',
  );
  @override
  late final GeneratedColumn<bool> hasPassphrase = GeneratedColumn<bool>(
    'has_passphrase',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_passphrase" IN (0, 1))',
    ),
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    wordCount,
    family,
    hasPassphrase,
    fingerprint,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_items_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultItemMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    }
    if (data.containsKey('has_passphrase')) {
      context.handle(
        _hasPassphraseMeta,
        hasPassphrase.isAcceptableOrUnknown(
          data['has_passphrase']!,
          _hasPassphraseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasPassphraseMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultItemMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultItemMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      ),
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      ),
      hasPassphrase: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_passphrase'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VaultItemsMetaTable createAlias(String alias) {
    return $VaultItemsMetaTable(attachedDatabase, alias);
  }
}

class VaultItemMetaRow extends DataClass
    implements Insertable<VaultItemMetaRow> {
  final String id;
  final String name;
  final String kind;
  final int? wordCount;
  final String? family;
  final bool hasPassphrase;
  final String fingerprint;
  final DateTime createdAt;
  const VaultItemMetaRow({
    required this.id,
    required this.name,
    required this.kind,
    this.wordCount,
    this.family,
    required this.hasPassphrase,
    required this.fingerprint,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || wordCount != null) {
      map['word_count'] = Variable<int>(wordCount);
    }
    if (!nullToAbsent || family != null) {
      map['family'] = Variable<String>(family);
    }
    map['has_passphrase'] = Variable<bool>(hasPassphrase);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VaultItemsMetaCompanion toCompanion(bool nullToAbsent) {
    return VaultItemsMetaCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      wordCount: wordCount == null && nullToAbsent
          ? const Value.absent()
          : Value(wordCount),
      family: family == null && nullToAbsent
          ? const Value.absent()
          : Value(family),
      hasPassphrase: Value(hasPassphrase),
      fingerprint: Value(fingerprint),
      createdAt: Value(createdAt),
    );
  }

  factory VaultItemMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultItemMetaRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      wordCount: serializer.fromJson<int?>(json['wordCount']),
      family: serializer.fromJson<String?>(json['family']),
      hasPassphrase: serializer.fromJson<bool>(json['hasPassphrase']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'wordCount': serializer.toJson<int?>(wordCount),
      'family': serializer.toJson<String?>(family),
      'hasPassphrase': serializer.toJson<bool>(hasPassphrase),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VaultItemMetaRow copyWith({
    String? id,
    String? name,
    String? kind,
    Value<int?> wordCount = const Value.absent(),
    Value<String?> family = const Value.absent(),
    bool? hasPassphrase,
    String? fingerprint,
    DateTime? createdAt,
  }) => VaultItemMetaRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    wordCount: wordCount.present ? wordCount.value : this.wordCount,
    family: family.present ? family.value : this.family,
    hasPassphrase: hasPassphrase ?? this.hasPassphrase,
    fingerprint: fingerprint ?? this.fingerprint,
    createdAt: createdAt ?? this.createdAt,
  );
  VaultItemMetaRow copyWithCompanion(VaultItemsMetaCompanion data) {
    return VaultItemMetaRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      family: data.family.present ? data.family.value : this.family,
      hasPassphrase: data.hasPassphrase.present
          ? data.hasPassphrase.value
          : this.hasPassphrase,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultItemMetaRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('wordCount: $wordCount, ')
          ..write('family: $family, ')
          ..write('hasPassphrase: $hasPassphrase, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    wordCount,
    family,
    hasPassphrase,
    fingerprint,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultItemMetaRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.wordCount == this.wordCount &&
          other.family == this.family &&
          other.hasPassphrase == this.hasPassphrase &&
          other.fingerprint == this.fingerprint &&
          other.createdAt == this.createdAt);
}

class VaultItemsMetaCompanion extends UpdateCompanion<VaultItemMetaRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<int?> wordCount;
  final Value<String?> family;
  final Value<bool> hasPassphrase;
  final Value<String> fingerprint;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VaultItemsMetaCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.family = const Value.absent(),
    this.hasPassphrase = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultItemsMetaCompanion.insert({
    required String id,
    required String name,
    required String kind,
    this.wordCount = const Value.absent(),
    this.family = const Value.absent(),
    required bool hasPassphrase,
    required String fingerprint,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind),
       hasPassphrase = Value(hasPassphrase),
       fingerprint = Value(fingerprint),
       createdAt = Value(createdAt);
  static Insertable<VaultItemMetaRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? wordCount,
    Expression<String>? family,
    Expression<bool>? hasPassphrase,
    Expression<String>? fingerprint,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (wordCount != null) 'word_count': wordCount,
      if (family != null) 'family': family,
      if (hasPassphrase != null) 'has_passphrase': hasPassphrase,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultItemsMetaCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<int?>? wordCount,
    Value<String?>? family,
    Value<bool>? hasPassphrase,
    Value<String>? fingerprint,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VaultItemsMetaCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      wordCount: wordCount ?? this.wordCount,
      family: family ?? this.family,
      hasPassphrase: hasPassphrase ?? this.hasPassphrase,
      fingerprint: fingerprint ?? this.fingerprint,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (hasPassphrase.present) {
      map['has_passphrase'] = Variable<bool>(hasPassphrase.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultItemsMetaCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('wordCount: $wordCount, ')
          ..write('family: $family, ')
          ..write('hasPassphrase: $hasPassphrase, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRecordsTable extends SyncRecords
    with TableInfo<$SyncRecordsTable, SyncRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failureTypeMeta = const VerificationMeta(
    'failureType',
  );
  @override
  late final GeneratedColumn<String> failureType = GeneratedColumn<String>(
    'failure_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    startedAt,
    finishedAt,
    status,
    failureType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('failure_type')) {
      context.handle(
        _failureTypeMeta,
        failureType.isAcceptableOrUnknown(
          data['failure_type']!,
          _failureTypeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      failureType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_type'],
      ),
    );
  }

  @override
  $SyncRecordsTable createAlias(String alias) {
    return $SyncRecordsTable(attachedDatabase, alias);
  }
}

class SyncRecordRow extends DataClass implements Insertable<SyncRecordRow> {
  final int id;
  final String accountId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String status;
  final String? failureType;
  const SyncRecordRow({
    required this.id,
    required this.accountId,
    required this.startedAt,
    this.finishedAt,
    required this.status,
    this.failureType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<String>(accountId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || failureType != null) {
      map['failure_type'] = Variable<String>(failureType);
    }
    return map;
  }

  SyncRecordsCompanion toCompanion(bool nullToAbsent) {
    return SyncRecordsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      status: Value(status),
      failureType: failureType == null && nullToAbsent
          ? const Value.absent()
          : Value(failureType),
    );
  }

  factory SyncRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRecordRow(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      status: serializer.fromJson<String>(json['status']),
      failureType: serializer.fromJson<String?>(json['failureType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<String>(accountId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'status': serializer.toJson<String>(status),
      'failureType': serializer.toJson<String?>(failureType),
    };
  }

  SyncRecordRow copyWith({
    int? id,
    String? accountId,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    String? status,
    Value<String?> failureType = const Value.absent(),
  }) => SyncRecordRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    status: status ?? this.status,
    failureType: failureType.present ? failureType.value : this.failureType,
  );
  SyncRecordRow copyWithCompanion(SyncRecordsCompanion data) {
    return SyncRecordRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      status: data.status.present ? data.status.value : this.status,
      failureType: data.failureType.present
          ? data.failureType.value
          : this.failureType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('status: $status, ')
          ..write('failureType: $failureType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, accountId, startedAt, finishedAt, status, failureType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRecordRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.status == this.status &&
          other.failureType == this.failureType);
}

class SyncRecordsCompanion extends UpdateCompanion<SyncRecordRow> {
  final Value<int> id;
  final Value<String> accountId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<String> status;
  final Value<String?> failureType;
  const SyncRecordsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.failureType = const Value.absent(),
  });
  SyncRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String accountId,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    required String status,
    this.failureType = const Value.absent(),
  }) : accountId = Value(accountId),
       startedAt = Value(startedAt),
       status = Value(status);
  static Insertable<SyncRecordRow> custom({
    Expression<int>? id,
    Expression<String>? accountId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? status,
    Expression<String>? failureType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (status != null) 'status': status,
      if (failureType != null) 'failure_type': failureType,
    });
  }

  SyncRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? accountId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<String>? status,
    Value<String?>? failureType,
  }) {
    return SyncRecordsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      failureType: failureType ?? this.failureType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (failureType.present) {
      map['failure_type'] = Variable<String>(failureType.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('status: $status, ')
          ..write('failureType: $failureType')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TokenVisibilityTable extends TokenVisibility
    with TableInfo<$TokenVisibilityTable, TokenVisibilityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TokenVisibilityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tokenKeyMeta = const VerificationMeta(
    'tokenKey',
  );
  @override
  late final GeneratedColumn<String> tokenKey = GeneratedColumn<String>(
    'token_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [tokenKey, hidden];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'token_visibility';
  @override
  VerificationContext validateIntegrity(
    Insertable<TokenVisibilityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('token_key')) {
      context.handle(
        _tokenKeyMeta,
        tokenKey.isAcceptableOrUnknown(data['token_key']!, _tokenKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenKeyMeta);
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    } else if (isInserting) {
      context.missing(_hiddenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tokenKey};
  @override
  TokenVisibilityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TokenVisibilityRow(
      tokenKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_key'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
    );
  }

  @override
  $TokenVisibilityTable createAlias(String alias) {
    return $TokenVisibilityTable(attachedDatabase, alias);
  }
}

class TokenVisibilityRow extends DataClass
    implements Insertable<TokenVisibilityRow> {
  final String tokenKey;
  final bool hidden;
  const TokenVisibilityRow({required this.tokenKey, required this.hidden});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['token_key'] = Variable<String>(tokenKey);
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  TokenVisibilityCompanion toCompanion(bool nullToAbsent) {
    return TokenVisibilityCompanion(
      tokenKey: Value(tokenKey),
      hidden: Value(hidden),
    );
  }

  factory TokenVisibilityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TokenVisibilityRow(
      tokenKey: serializer.fromJson<String>(json['tokenKey']),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tokenKey': serializer.toJson<String>(tokenKey),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  TokenVisibilityRow copyWith({String? tokenKey, bool? hidden}) =>
      TokenVisibilityRow(
        tokenKey: tokenKey ?? this.tokenKey,
        hidden: hidden ?? this.hidden,
      );
  TokenVisibilityRow copyWithCompanion(TokenVisibilityCompanion data) {
    return TokenVisibilityRow(
      tokenKey: data.tokenKey.present ? data.tokenKey.value : this.tokenKey,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TokenVisibilityRow(')
          ..write('tokenKey: $tokenKey, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tokenKey, hidden);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TokenVisibilityRow &&
          other.tokenKey == this.tokenKey &&
          other.hidden == this.hidden);
}

class TokenVisibilityCompanion extends UpdateCompanion<TokenVisibilityRow> {
  final Value<String> tokenKey;
  final Value<bool> hidden;
  final Value<int> rowid;
  const TokenVisibilityCompanion({
    this.tokenKey = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TokenVisibilityCompanion.insert({
    required String tokenKey,
    required bool hidden,
    this.rowid = const Value.absent(),
  }) : tokenKey = Value(tokenKey),
       hidden = Value(hidden);
  static Insertable<TokenVisibilityRow> custom({
    Expression<String>? tokenKey,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tokenKey != null) 'token_key': tokenKey,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TokenVisibilityCompanion copyWith({
    Value<String>? tokenKey,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return TokenVisibilityCompanion(
      tokenKey: tokenKey ?? this.tokenKey,
      hidden: hidden ?? this.hidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tokenKey.present) {
      map['token_key'] = Variable<String>(tokenKey.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TokenVisibilityCompanion(')
          ..write('tokenKey: $tokenKey, ')
          ..write('hidden: $hidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OwDatabase extends GeneratedDatabase {
  _$OwDatabase(QueryExecutor e) : super(e);
  $OwDatabaseManager get managers => $OwDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $AddressesTable addresses = $AddressesTable(this);
  late final $HoldingsTable holdings = $HoldingsTable(this);
  late final $PricesTable prices = $PricesTable(this);
  late final $SnapshotsTable snapshots = $SnapshotsTable(this);
  late final $SnapshotItemsTable snapshotItems = $SnapshotItemsTable(this);
  late final $VaultItemsMetaTable vaultItemsMeta = $VaultItemsMetaTable(this);
  late final $SyncRecordsTable syncRecords = $SyncRecordsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $TokenVisibilityTable tokenVisibility = $TokenVisibilityTable(
    this,
  );
  late final Index idxAddressesFamilyAddress = Index(
    'idx_addresses_family_address',
    'CREATE UNIQUE INDEX idx_addresses_family_address ON addresses (family, address)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    addresses,
    holdings,
    prices,
    snapshots,
    snapshotItems,
    vaultItemsMeta,
    syncRecords,
    settings,
    tokenVisibility,
    idxAddressesFamilyAddress,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('addresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('holdings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'snapshots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('snapshot_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sync_records', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String id,
  required String type,
  required String name,
  required int colorIndex,
  Value<String> note,
  Value<String?> walletSource,
  Value<String?> exchange,
  Value<String?> vaultItemId,
  Value<bool> offlineBackedUp,
  Value<DateTime?> offlineVerifiedAt,
  Value<bool> keyless,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> name,
  Value<int> colorIndex,
  Value<String> note,
  Value<String?> walletSource,
  Value<String?> exchange,
  Value<String?> vaultItemId,
  Value<bool> offlineBackedUp,
  Value<DateTime?> offlineVerifiedAt,
  Value<bool> keyless,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$OwDatabase, $AccountsTable, AccountRow> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AddressesTable, List<AddressRow>>
  _addressesRefsTable(_$OwDatabase db) => MultiTypedResultKey.fromTable(
    db.addresses,
    aliasName: 'accounts__id__addresses__account_id',
  );

  $$AddressesTableProcessedTableManager get addressesRefs {
    final manager = $$AddressesTableTableManager(
      $_db,
      $_db.addresses,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_addressesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HoldingsTable, List<HoldingRow>>
  _holdingsRefsTable(_$OwDatabase db) => MultiTypedResultKey.fromTable(
    db.holdings,
    aliasName: 'accounts__id__holdings__account_id',
  );

  $$HoldingsTableProcessedTableManager get holdingsRefs {
    final manager = $$HoldingsTableTableManager(
      $_db,
      $_db.holdings,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_holdingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SyncRecordsTable, List<SyncRecordRow>>
  _syncRecordsRefsTable(_$OwDatabase db) => MultiTypedResultKey.fromTable(
    db.syncRecords,
    aliasName: 'accounts__id__sync_records__account_id',
  );

  $$SyncRecordsTableProcessedTableManager get syncRecordsRefs {
    final manager = $$SyncRecordsTableTableManager(
      $_db,
      $_db.syncRecords,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$OwDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get walletSource => $composableBuilder(
    column: $table.walletSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaultItemId => $composableBuilder(
    column: $table.vaultItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get offlineBackedUp => $composableBuilder(
    column: $table.offlineBackedUp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get offlineVerifiedAt => $composableBuilder(
    column: $table.offlineVerifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keyless => $composableBuilder(
    column: $table.keyless,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> addressesRefs(
    Expression<bool> Function($$AddressesTableFilterComposer f) f,
  ) {
    final $$AddressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.addresses,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AddressesTableFilterComposer(
            $db: $db,
            $table: $db.addresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> holdingsRefs(
    Expression<bool> Function($$HoldingsTableFilterComposer f) f,
  ) {
    final $$HoldingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.holdings,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoldingsTableFilterComposer(
            $db: $db,
            $table: $db.holdings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncRecordsRefs(
    Expression<bool> Function($$SyncRecordsTableFilterComposer f) f,
  ) {
    final $$SyncRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncRecords,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncRecordsTableFilterComposer(
            $db: $db,
            $table: $db.syncRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$OwDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get walletSource => $composableBuilder(
    column: $table.walletSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaultItemId => $composableBuilder(
    column: $table.vaultItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get offlineBackedUp => $composableBuilder(
    column: $table.offlineBackedUp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get offlineVerifiedAt => $composableBuilder(
    column: $table.offlineVerifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keyless => $composableBuilder(
    column: $table.keyless,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$OwDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get walletSource => $composableBuilder(
    column: $table.walletSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchange =>
      $composableBuilder(column: $table.exchange, builder: (column) => column);

  GeneratedColumn<String> get vaultItemId => $composableBuilder(
    column: $table.vaultItemId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get offlineBackedUp => $composableBuilder(
    column: $table.offlineBackedUp,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get offlineVerifiedAt => $composableBuilder(
    column: $table.offlineVerifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get keyless =>
      $composableBuilder(column: $table.keyless, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> addressesRefs<T extends Object>(
    Expression<T> Function($$AddressesTableAnnotationComposer a) f,
  ) {
    final $$AddressesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.addresses,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AddressesTableAnnotationComposer(
            $db: $db,
            $table: $db.addresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> holdingsRefs<T extends Object>(
    Expression<T> Function($$HoldingsTableAnnotationComposer a) f,
  ) {
    final $$HoldingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.holdings,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoldingsTableAnnotationComposer(
            $db: $db,
            $table: $db.holdings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncRecordsRefs<T extends Object>(
    Expression<T> Function($$SyncRecordsTableAnnotationComposer a) f,
  ) {
    final $$SyncRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncRecords,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.syncRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (AccountRow, $$AccountsTableReferences),
          AccountRow,
          PrefetchHooks Function({
            bool addressesRefs,
            bool holdingsRefs,
            bool syncRecordsRefs,
          })
        > {
  $$AccountsTableTableManager(_$OwDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> walletSource = const Value.absent(),
                Value<String?> exchange = const Value.absent(),
                Value<String?> vaultItemId = const Value.absent(),
                Value<bool> offlineBackedUp = const Value.absent(),
                Value<DateTime?> offlineVerifiedAt = const Value.absent(),
                Value<bool> keyless = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                type: type,
                name: name,
                colorIndex: colorIndex,
                note: note,
                walletSource: walletSource,
                exchange: exchange,
                vaultItemId: vaultItemId,
                offlineBackedUp: offlineBackedUp,
                offlineVerifiedAt: offlineVerifiedAt,
                keyless: keyless,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String name,
                required int colorIndex,
                Value<String> note = const Value.absent(),
                Value<String?> walletSource = const Value.absent(),
                Value<String?> exchange = const Value.absent(),
                Value<String?> vaultItemId = const Value.absent(),
                Value<bool> offlineBackedUp = const Value.absent(),
                Value<DateTime?> offlineVerifiedAt = const Value.absent(),
                Value<bool> keyless = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                type: type,
                name: name,
                colorIndex: colorIndex,
                note: note,
                walletSource: walletSource,
                exchange: exchange,
                vaultItemId: vaultItemId,
                offlineBackedUp: offlineBackedUp,
                offlineVerifiedAt: offlineVerifiedAt,
                keyless: keyless,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, AccountRow>(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                addressesRefs = false,
                holdingsRefs = false,
                syncRecordsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (addressesRefs) db.addresses,
                    if (holdingsRefs) db.holdings,
                    if (syncRecordsRefs) db.syncRecords,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (addressesRefs)
                        await $_getPrefetchedDataByColumns<
                          AccountRow,
                          $AccountsTable,
                          AddressRow,
                          $AddressesTable
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._addressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).addressesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                      if (holdingsRefs)
                        await $_getPrefetchedDataByColumns<
                          AccountRow,
                          $AccountsTable,
                          HoldingRow,
                          $HoldingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._holdingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).holdingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                      if (syncRecordsRefs)
                        await $_getPrefetchedDataByColumns<
                          AccountRow,
                          $AccountsTable,
                          SyncRecordRow,
                          $SyncRecordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._syncRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).syncRecordsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (AccountRow, $$AccountsTableReferences),
      AccountRow,
      PrefetchHooks Function({
        bool addressesRefs,
        bool holdingsRefs,
        bool syncRecordsRefs,
      })
    >;
typedef $$AddressesTableCreateCompanionBuilder = AddressesCompanion Function({
  required String id,
  required String accountId,
  required String family,
  required String address,
  required String enabledChainIds,
  Value<String?> scheme,
  Value<int?> derivationIndex,
  Value<String> note,
  Value<int> rowid,
});
typedef $$AddressesTableUpdateCompanionBuilder = AddressesCompanion Function({
  Value<String> id,
  Value<String> accountId,
  Value<String> family,
  Value<String> address,
  Value<String> enabledChainIds,
  Value<String?> scheme,
  Value<int?> derivationIndex,
  Value<String> note,
  Value<int> rowid,
});

final class $$AddressesTableReferences
    extends BaseReferences<_$OwDatabase, $AddressesTable, AddressRow> {
  $$AddressesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$OwDatabase db) =>
      db.accounts.createAlias('addresses__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AddressesTableFilterComposer
    extends Composer<_$OwDatabase, $AddressesTable> {
  $$AddressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabledChainIds => $composableBuilder(
    column: $table.enabledChainIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheme => $composableBuilder(
    column: $table.scheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get derivationIndex => $composableBuilder(
    column: $table.derivationIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AddressesTableOrderingComposer
    extends Composer<_$OwDatabase, $AddressesTable> {
  $$AddressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabledChainIds => $composableBuilder(
    column: $table.enabledChainIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheme => $composableBuilder(
    column: $table.scheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get derivationIndex => $composableBuilder(
    column: $table.derivationIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AddressesTableAnnotationComposer
    extends Composer<_$OwDatabase, $AddressesTable> {
  $$AddressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get enabledChainIds => $composableBuilder(
    column: $table.enabledChainIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheme =>
      $composableBuilder(column: $table.scheme, builder: (column) => column);

  GeneratedColumn<int> get derivationIndex => $composableBuilder(
    column: $table.derivationIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AddressesTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $AddressesTable,
          AddressRow,
          $$AddressesTableFilterComposer,
          $$AddressesTableOrderingComposer,
          $$AddressesTableAnnotationComposer,
          $$AddressesTableCreateCompanionBuilder,
          $$AddressesTableUpdateCompanionBuilder,
          (AddressRow, $$AddressesTableReferences),
          AddressRow,
          PrefetchHooks Function({bool accountId})
        > {
  $$AddressesTableTableManager(_$OwDatabase db, $AddressesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AddressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AddressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AddressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> family = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> enabledChainIds = const Value.absent(),
                Value<String?> scheme = const Value.absent(),
                Value<int?> derivationIndex = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AddressesCompanion(
                id: id,
                accountId: accountId,
                family: family,
                address: address,
                enabledChainIds: enabledChainIds,
                scheme: scheme,
                derivationIndex: derivationIndex,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String family,
                required String address,
                required String enabledChainIds,
                Value<String?> scheme = const Value.absent(),
                Value<int?> derivationIndex = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AddressesCompanion.insert(
                id: id,
                accountId: accountId,
                family: family,
                address: address,
                enabledChainIds: enabledChainIds,
                scheme: scheme,
                derivationIndex: derivationIndex,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AddressesTable, AddressRow>(table),
                  $$AddressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$AddressesTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$AddressesTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AddressesTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $AddressesTable,
      AddressRow,
      $$AddressesTableFilterComposer,
      $$AddressesTableOrderingComposer,
      $$AddressesTableAnnotationComposer,
      $$AddressesTableCreateCompanionBuilder,
      $$AddressesTableUpdateCompanionBuilder,
      (AddressRow, $$AddressesTableReferences),
      AddressRow,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$HoldingsTableCreateCompanionBuilder = HoldingsCompanion Function({
  Value<int> id,
  required String accountId,
  required String locationKind,
  Value<String?> chainId,
  Value<String?> addressId,
  Value<String?> exchangeSub,
  required String tokenKind,
  Value<String?> tokenChainId,
  Value<String?> tokenContract,
  Value<String?> tokenSymbol,
  Value<String?> assetId,
  required String displaySymbol,
  required String amount,
  required DateTime updatedAt,
});
typedef $$HoldingsTableUpdateCompanionBuilder = HoldingsCompanion Function({
  Value<int> id,
  Value<String> accountId,
  Value<String> locationKind,
  Value<String?> chainId,
  Value<String?> addressId,
  Value<String?> exchangeSub,
  Value<String> tokenKind,
  Value<String?> tokenChainId,
  Value<String?> tokenContract,
  Value<String?> tokenSymbol,
  Value<String?> assetId,
  Value<String> displaySymbol,
  Value<String> amount,
  Value<DateTime> updatedAt,
});

final class $$HoldingsTableReferences
    extends BaseReferences<_$OwDatabase, $HoldingsTable, HoldingRow> {
  $$HoldingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$OwDatabase db) =>
      db.accounts.createAlias('holdings__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HoldingsTableFilterComposer
    extends Composer<_$OwDatabase, $HoldingsTable> {
  $$HoldingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationKind => $composableBuilder(
    column: $table.locationKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chainId => $composableBuilder(
    column: $table.chainId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressId => $composableBuilder(
    column: $table.addressId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchangeSub => $composableBuilder(
    column: $table.exchangeSub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenKind => $composableBuilder(
    column: $table.tokenKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenChainId => $composableBuilder(
    column: $table.tokenChainId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenContract => $composableBuilder(
    column: $table.tokenContract,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenSymbol => $composableBuilder(
    column: $table.tokenSymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displaySymbol => $composableBuilder(
    column: $table.displaySymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoldingsTableOrderingComposer
    extends Composer<_$OwDatabase, $HoldingsTable> {
  $$HoldingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationKind => $composableBuilder(
    column: $table.locationKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chainId => $composableBuilder(
    column: $table.chainId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressId => $composableBuilder(
    column: $table.addressId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchangeSub => $composableBuilder(
    column: $table.exchangeSub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenKind => $composableBuilder(
    column: $table.tokenKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenChainId => $composableBuilder(
    column: $table.tokenChainId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenContract => $composableBuilder(
    column: $table.tokenContract,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenSymbol => $composableBuilder(
    column: $table.tokenSymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displaySymbol => $composableBuilder(
    column: $table.displaySymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoldingsTableAnnotationComposer
    extends Composer<_$OwDatabase, $HoldingsTable> {
  $$HoldingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationKind => $composableBuilder(
    column: $table.locationKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chainId =>
      $composableBuilder(column: $table.chainId, builder: (column) => column);

  GeneratedColumn<String> get addressId =>
      $composableBuilder(column: $table.addressId, builder: (column) => column);

  GeneratedColumn<String> get exchangeSub => $composableBuilder(
    column: $table.exchangeSub,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokenKind =>
      $composableBuilder(column: $table.tokenKind, builder: (column) => column);

  GeneratedColumn<String> get tokenChainId => $composableBuilder(
    column: $table.tokenChainId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokenContract => $composableBuilder(
    column: $table.tokenContract,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokenSymbol => $composableBuilder(
    column: $table.tokenSymbol,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get displaySymbol => $composableBuilder(
    column: $table.displaySymbol,
    builder: (column) => column,
  );

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoldingsTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $HoldingsTable,
          HoldingRow,
          $$HoldingsTableFilterComposer,
          $$HoldingsTableOrderingComposer,
          $$HoldingsTableAnnotationComposer,
          $$HoldingsTableCreateCompanionBuilder,
          $$HoldingsTableUpdateCompanionBuilder,
          (HoldingRow, $$HoldingsTableReferences),
          HoldingRow,
          PrefetchHooks Function({bool accountId})
        > {
  $$HoldingsTableTableManager(_$OwDatabase db, $HoldingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoldingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> locationKind = const Value.absent(),
                Value<String?> chainId = const Value.absent(),
                Value<String?> addressId = const Value.absent(),
                Value<String?> exchangeSub = const Value.absent(),
                Value<String> tokenKind = const Value.absent(),
                Value<String?> tokenChainId = const Value.absent(),
                Value<String?> tokenContract = const Value.absent(),
                Value<String?> tokenSymbol = const Value.absent(),
                Value<String?> assetId = const Value.absent(),
                Value<String> displaySymbol = const Value.absent(),
                Value<String> amount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => HoldingsCompanion(
                id: id,
                accountId: accountId,
                locationKind: locationKind,
                chainId: chainId,
                addressId: addressId,
                exchangeSub: exchangeSub,
                tokenKind: tokenKind,
                tokenChainId: tokenChainId,
                tokenContract: tokenContract,
                tokenSymbol: tokenSymbol,
                assetId: assetId,
                displaySymbol: displaySymbol,
                amount: amount,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String accountId,
                required String locationKind,
                Value<String?> chainId = const Value.absent(),
                Value<String?> addressId = const Value.absent(),
                Value<String?> exchangeSub = const Value.absent(),
                required String tokenKind,
                Value<String?> tokenChainId = const Value.absent(),
                Value<String?> tokenContract = const Value.absent(),
                Value<String?> tokenSymbol = const Value.absent(),
                Value<String?> assetId = const Value.absent(),
                required String displaySymbol,
                required String amount,
                required DateTime updatedAt,
              }) => HoldingsCompanion.insert(
                id: id,
                accountId: accountId,
                locationKind: locationKind,
                chainId: chainId,
                addressId: addressId,
                exchangeSub: exchangeSub,
                tokenKind: tokenKind,
                tokenChainId: tokenChainId,
                tokenContract: tokenContract,
                tokenSymbol: tokenSymbol,
                assetId: assetId,
                displaySymbol: displaySymbol,
                amount: amount,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HoldingsTable, HoldingRow>(table),
                  $$HoldingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$HoldingsTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$HoldingsTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HoldingsTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $HoldingsTable,
      HoldingRow,
      $$HoldingsTableFilterComposer,
      $$HoldingsTableOrderingComposer,
      $$HoldingsTableAnnotationComposer,
      $$HoldingsTableCreateCompanionBuilder,
      $$HoldingsTableUpdateCompanionBuilder,
      (HoldingRow, $$HoldingsTableReferences),
      HoldingRow,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$PricesTableCreateCompanionBuilder = PricesCompanion Function({
  required String assetId,
  required String quote,
  required String price,
  Value<String?> change24hPercent,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PricesTableUpdateCompanionBuilder = PricesCompanion Function({
  Value<String> assetId,
  Value<String> quote,
  Value<String> price,
  Value<String?> change24hPercent,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PricesTableFilterComposer extends Composer<_$OwDatabase, $PricesTable> {
  $$PricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quote => $composableBuilder(
    column: $table.quote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get change24hPercent => $composableBuilder(
    column: $table.change24hPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PricesTableOrderingComposer
    extends Composer<_$OwDatabase, $PricesTable> {
  $$PricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quote => $composableBuilder(
    column: $table.quote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get change24hPercent => $composableBuilder(
    column: $table.change24hPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PricesTableAnnotationComposer
    extends Composer<_$OwDatabase, $PricesTable> {
  $$PricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get quote =>
      $composableBuilder(column: $table.quote, builder: (column) => column);

  GeneratedColumn<String> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get change24hPercent => $composableBuilder(
    column: $table.change24hPercent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PricesTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $PricesTable,
          PriceRow,
          $$PricesTableFilterComposer,
          $$PricesTableOrderingComposer,
          $$PricesTableAnnotationComposer,
          $$PricesTableCreateCompanionBuilder,
          $$PricesTableUpdateCompanionBuilder,
          (PriceRow, BaseReferences<_$OwDatabase, $PricesTable, PriceRow>),
          PriceRow,
          PrefetchHooks Function()
        > {
  $$PricesTableTableManager(_$OwDatabase db, $PricesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PricesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PricesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PricesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<String> quote = const Value.absent(),
                Value<String> price = const Value.absent(),
                Value<String?> change24hPercent = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricesCompanion(
                assetId: assetId,
                quote: quote,
                price: price,
                change24hPercent: change24hPercent,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required String quote,
                required String price,
                Value<String?> change24hPercent = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PricesCompanion.insert(
                assetId: assetId,
                quote: quote,
                price: price,
                change24hPercent: change24hPercent,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PricesTable, PriceRow>(table),
                  BaseReferences<_$OwDatabase, $PricesTable, PriceRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PricesTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $PricesTable,
      PriceRow,
      $$PricesTableFilterComposer,
      $$PricesTableOrderingComposer,
      $$PricesTableAnnotationComposer,
      $$PricesTableCreateCompanionBuilder,
      $$PricesTableUpdateCompanionBuilder,
      (PriceRow, BaseReferences<_$OwDatabase, $PricesTable, PriceRow>),
      PriceRow,
      PrefetchHooks Function()
    >;
typedef $$SnapshotsTableCreateCompanionBuilder = SnapshotsCompanion Function({
  required DateTime date,
  required String totalUsd,
  required bool complete,
  Value<int> rowid,
});
typedef $$SnapshotsTableUpdateCompanionBuilder = SnapshotsCompanion Function({
  Value<DateTime> date,
  Value<String> totalUsd,
  Value<bool> complete,
  Value<int> rowid,
});

final class $$SnapshotsTableReferences
    extends BaseReferences<_$OwDatabase, $SnapshotsTable, SnapshotRow> {
  $$SnapshotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SnapshotItemsTable, List<SnapshotItemRow>>
  _snapshotItemsRefsTable(_$OwDatabase db) => MultiTypedResultKey.fromTable(
    db.snapshotItems,
    aliasName: 'snapshots__date__snapshot_items__date',
  );

  $$SnapshotItemsTableProcessedTableManager get snapshotItemsRefs {
    final manager = $$SnapshotItemsTableTableManager(
      $_db,
      $_db.snapshotItems,
    ).filter((f) => f.date.date.sqlEquals($_itemColumn<DateTime>('date')!));

    final cache = $_typedResult.readTableOrNull(_snapshotItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SnapshotsTableFilterComposer
    extends Composer<_$OwDatabase, $SnapshotsTable> {
  $$SnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totalUsd => $composableBuilder(
    column: $table.totalUsd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> snapshotItemsRefs(
    Expression<bool> Function($$SnapshotItemsTableFilterComposer f) f,
  ) {
    final $$SnapshotItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.snapshotItems,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotItemsTableFilterComposer(
            $db: $db,
            $table: $db.snapshotItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SnapshotsTableOrderingComposer
    extends Composer<_$OwDatabase, $SnapshotsTable> {
  $$SnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalUsd => $composableBuilder(
    column: $table.totalUsd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnapshotsTableAnnotationComposer
    extends Composer<_$OwDatabase, $SnapshotsTable> {
  $$SnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get totalUsd =>
      $composableBuilder(column: $table.totalUsd, builder: (column) => column);

  GeneratedColumn<bool> get complete =>
      $composableBuilder(column: $table.complete, builder: (column) => column);

  Expression<T> snapshotItemsRefs<T extends Object>(
    Expression<T> Function($$SnapshotItemsTableAnnotationComposer a) f,
  ) {
    final $$SnapshotItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.snapshotItems,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.snapshotItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SnapshotsTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $SnapshotsTable,
          SnapshotRow,
          $$SnapshotsTableFilterComposer,
          $$SnapshotsTableOrderingComposer,
          $$SnapshotsTableAnnotationComposer,
          $$SnapshotsTableCreateCompanionBuilder,
          $$SnapshotsTableUpdateCompanionBuilder,
          (SnapshotRow, $$SnapshotsTableReferences),
          SnapshotRow,
          PrefetchHooks Function({bool snapshotItemsRefs})
        > {
  $$SnapshotsTableTableManager(_$OwDatabase db, $SnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<String> totalUsd = const Value.absent(),
                Value<bool> complete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnapshotsCompanion(
                date: date,
                totalUsd: totalUsd,
                complete: complete,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required String totalUsd,
                required bool complete,
                Value<int> rowid = const Value.absent(),
              }) => SnapshotsCompanion.insert(
                date: date,
                totalUsd: totalUsd,
                complete: complete,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SnapshotsTable, SnapshotRow>(table),
                  $$SnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snapshotItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (snapshotItemsRefs) db.snapshotItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (snapshotItemsRefs)
                    await $_getPrefetchedDataByColumns<
                      SnapshotRow,
                      $SnapshotsTable,
                      SnapshotItemRow,
                      $SnapshotItemsTable
                    >(
                      currentTable: table,
                      referencedTable: $$SnapshotsTableReferences
                          ._snapshotItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SnapshotsTableReferences(
                            db,
                            table,
                            p0,
                          ).snapshotItemsRefs,
                      currentColumn: 'date',
                      referencedColumn: 'date',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $SnapshotsTable,
      SnapshotRow,
      $$SnapshotsTableFilterComposer,
      $$SnapshotsTableOrderingComposer,
      $$SnapshotsTableAnnotationComposer,
      $$SnapshotsTableCreateCompanionBuilder,
      $$SnapshotsTableUpdateCompanionBuilder,
      (SnapshotRow, $$SnapshotsTableReferences),
      SnapshotRow,
      PrefetchHooks Function({bool snapshotItemsRefs})
    >;
typedef $$SnapshotItemsTableCreateCompanionBuilder =
    SnapshotItemsCompanion Function({
      required DateTime date,
      required String kind,
      required String key,
      required String valueUsd,
      Value<int> rowid,
    });
typedef $$SnapshotItemsTableUpdateCompanionBuilder =
    SnapshotItemsCompanion Function({
      Value<DateTime> date,
      Value<String> kind,
      Value<String> key,
      Value<String> valueUsd,
      Value<int> rowid,
    });

final class $$SnapshotItemsTableReferences
    extends BaseReferences<_$OwDatabase, $SnapshotItemsTable, SnapshotItemRow> {
  $$SnapshotItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SnapshotsTable _dateTable(_$OwDatabase db) =>
      db.snapshots.createAlias('snapshot_items__date__snapshots__date');

  $$SnapshotsTableProcessedTableManager get date {
    final $_column = $_itemColumn<DateTime>('date')!;

    final manager = $$SnapshotsTableTableManager(
      $_db,
      $_db.snapshots,
    ).filter((f) => f.date.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dateTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SnapshotItemsTableFilterComposer
    extends Composer<_$OwDatabase, $SnapshotItemsTable> {
  $$SnapshotItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueUsd => $composableBuilder(
    column: $table.valueUsd,
    builder: (column) => ColumnFilters(column),
  );

  $$SnapshotsTableFilterComposer get date {
    final $$SnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotItemsTableOrderingComposer
    extends Composer<_$OwDatabase, $SnapshotItemsTable> {
  $$SnapshotItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueUsd => $composableBuilder(
    column: $table.valueUsd,
    builder: (column) => ColumnOrderings(column),
  );

  $$SnapshotsTableOrderingComposer get date {
    final $$SnapshotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableOrderingComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotItemsTableAnnotationComposer
    extends Composer<_$OwDatabase, $SnapshotItemsTable> {
  $$SnapshotItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueUsd =>
      $composableBuilder(column: $table.valueUsd, builder: (column) => column);

  $$SnapshotsTableAnnotationComposer get date {
    final $$SnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotItemsTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $SnapshotItemsTable,
          SnapshotItemRow,
          $$SnapshotItemsTableFilterComposer,
          $$SnapshotItemsTableOrderingComposer,
          $$SnapshotItemsTableAnnotationComposer,
          $$SnapshotItemsTableCreateCompanionBuilder,
          $$SnapshotItemsTableUpdateCompanionBuilder,
          (SnapshotItemRow, $$SnapshotItemsTableReferences),
          SnapshotItemRow,
          PrefetchHooks Function({bool date})
        > {
  $$SnapshotItemsTableTableManager(_$OwDatabase db, $SnapshotItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> valueUsd = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnapshotItemsCompanion(
                date: date,
                kind: kind,
                key: key,
                valueUsd: valueUsd,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required String kind,
                required String key,
                required String valueUsd,
                Value<int> rowid = const Value.absent(),
              }) => SnapshotItemsCompanion.insert(
                date: date,
                kind: kind,
                key: key,
                valueUsd: valueUsd,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SnapshotItemsTable, SnapshotItemRow>(table),
                  $$SnapshotItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({date = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (date) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.date,
                        referencedTable: $$SnapshotItemsTableReferences
                            ._dateTable(db),
                        referencedColumn: $$SnapshotItemsTableReferences
                            ._dateTable(db)
                            .date,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SnapshotItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $SnapshotItemsTable,
      SnapshotItemRow,
      $$SnapshotItemsTableFilterComposer,
      $$SnapshotItemsTableOrderingComposer,
      $$SnapshotItemsTableAnnotationComposer,
      $$SnapshotItemsTableCreateCompanionBuilder,
      $$SnapshotItemsTableUpdateCompanionBuilder,
      (SnapshotItemRow, $$SnapshotItemsTableReferences),
      SnapshotItemRow,
      PrefetchHooks Function({bool date})
    >;
typedef $$VaultItemsMetaTableCreateCompanionBuilder =
    VaultItemsMetaCompanion Function({
      required String id,
      required String name,
      required String kind,
      Value<int?> wordCount,
      Value<String?> family,
      required bool hasPassphrase,
      required String fingerprint,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$VaultItemsMetaTableUpdateCompanionBuilder =
    VaultItemsMetaCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> kind,
      Value<int?> wordCount,
      Value<String?> family,
      Value<bool> hasPassphrase,
      Value<String> fingerprint,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$VaultItemsMetaTableFilterComposer
    extends Composer<_$OwDatabase, $VaultItemsMetaTable> {
  $$VaultItemsMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasPassphrase => $composableBuilder(
    column: $table.hasPassphrase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultItemsMetaTableOrderingComposer
    extends Composer<_$OwDatabase, $VaultItemsMetaTable> {
  $$VaultItemsMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasPassphrase => $composableBuilder(
    column: $table.hasPassphrase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultItemsMetaTableAnnotationComposer
    extends Composer<_$OwDatabase, $VaultItemsMetaTable> {
  $$VaultItemsMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<bool> get hasPassphrase => $composableBuilder(
    column: $table.hasPassphrase,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$VaultItemsMetaTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $VaultItemsMetaTable,
          VaultItemMetaRow,
          $$VaultItemsMetaTableFilterComposer,
          $$VaultItemsMetaTableOrderingComposer,
          $$VaultItemsMetaTableAnnotationComposer,
          $$VaultItemsMetaTableCreateCompanionBuilder,
          $$VaultItemsMetaTableUpdateCompanionBuilder,
          (
            VaultItemMetaRow,
            BaseReferences<
              _$OwDatabase,
              $VaultItemsMetaTable,
              VaultItemMetaRow
            >,
          ),
          VaultItemMetaRow,
          PrefetchHooks Function()
        > {
  $$VaultItemsMetaTableTableManager(_$OwDatabase db, $VaultItemsMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultItemsMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultItemsMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultItemsMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> wordCount = const Value.absent(),
                Value<String?> family = const Value.absent(),
                Value<bool> hasPassphrase = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultItemsMetaCompanion(
                id: id,
                name: name,
                kind: kind,
                wordCount: wordCount,
                family: family,
                hasPassphrase: hasPassphrase,
                fingerprint: fingerprint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                Value<int?> wordCount = const Value.absent(),
                Value<String?> family = const Value.absent(),
                required bool hasPassphrase,
                required String fingerprint,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VaultItemsMetaCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                wordCount: wordCount,
                family: family,
                hasPassphrase: hasPassphrase,
                fingerprint: fingerprint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultItemsMetaTable, VaultItemMetaRow>(table),
                  BaseReferences<
                    _$OwDatabase,
                    $VaultItemsMetaTable,
                    VaultItemMetaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultItemsMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $VaultItemsMetaTable,
      VaultItemMetaRow,
      $$VaultItemsMetaTableFilterComposer,
      $$VaultItemsMetaTableOrderingComposer,
      $$VaultItemsMetaTableAnnotationComposer,
      $$VaultItemsMetaTableCreateCompanionBuilder,
      $$VaultItemsMetaTableUpdateCompanionBuilder,
      (
        VaultItemMetaRow,
        BaseReferences<_$OwDatabase, $VaultItemsMetaTable, VaultItemMetaRow>,
      ),
      VaultItemMetaRow,
      PrefetchHooks Function()
    >;
typedef $$SyncRecordsTableCreateCompanionBuilder =
    SyncRecordsCompanion Function({
      Value<int> id,
      required String accountId,
      required DateTime startedAt,
      Value<DateTime?> finishedAt,
      required String status,
      Value<String?> failureType,
    });
typedef $$SyncRecordsTableUpdateCompanionBuilder =
    SyncRecordsCompanion Function({
      Value<int> id,
      Value<String> accountId,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<String> status,
      Value<String?> failureType,
    });

final class $$SyncRecordsTableReferences
    extends BaseReferences<_$OwDatabase, $SyncRecordsTable, SyncRecordRow> {
  $$SyncRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$OwDatabase db) =>
      db.accounts.createAlias('sync_records__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncRecordsTableFilterComposer
    extends Composer<_$OwDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureType => $composableBuilder(
    column: $table.failureType,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRecordsTableOrderingComposer
    extends Composer<_$OwDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureType => $composableBuilder(
    column: $table.failureType,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRecordsTableAnnotationComposer
    extends Composer<_$OwDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get failureType => $composableBuilder(
    column: $table.failureType,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRecordsTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $SyncRecordsTable,
          SyncRecordRow,
          $$SyncRecordsTableFilterComposer,
          $$SyncRecordsTableOrderingComposer,
          $$SyncRecordsTableAnnotationComposer,
          $$SyncRecordsTableCreateCompanionBuilder,
          $$SyncRecordsTableUpdateCompanionBuilder,
          (SyncRecordRow, $$SyncRecordsTableReferences),
          SyncRecordRow,
          PrefetchHooks Function({bool accountId})
        > {
  $$SyncRecordsTableTableManager(_$OwDatabase db, $SyncRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> failureType = const Value.absent(),
              }) => SyncRecordsCompanion(
                id: id,
                accountId: accountId,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
                failureType: failureType,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String accountId,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                required String status,
                Value<String?> failureType = const Value.absent(),
              }) => SyncRecordsCompanion.insert(
                id: id,
                accountId: accountId,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
                failureType: failureType,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncRecordsTable, SyncRecordRow>(table),
                  $$SyncRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$SyncRecordsTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$SyncRecordsTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SyncRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $SyncRecordsTable,
      SyncRecordRow,
      $$SyncRecordsTableFilterComposer,
      $$SyncRecordsTableOrderingComposer,
      $$SyncRecordsTableAnnotationComposer,
      $$SyncRecordsTableCreateCompanionBuilder,
      $$SyncRecordsTableUpdateCompanionBuilder,
      (SyncRecordRow, $$SyncRecordsTableReferences),
      SyncRecordRow,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$OwDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$OwDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$OwDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$OwDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$OwDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$OwDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$OwDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$TokenVisibilityTableCreateCompanionBuilder =
    TokenVisibilityCompanion Function({
      required String tokenKey,
      required bool hidden,
      Value<int> rowid,
    });
typedef $$TokenVisibilityTableUpdateCompanionBuilder =
    TokenVisibilityCompanion Function({
      Value<String> tokenKey,
      Value<bool> hidden,
      Value<int> rowid,
    });

class $$TokenVisibilityTableFilterComposer
    extends Composer<_$OwDatabase, $TokenVisibilityTable> {
  $$TokenVisibilityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tokenKey => $composableBuilder(
    column: $table.tokenKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TokenVisibilityTableOrderingComposer
    extends Composer<_$OwDatabase, $TokenVisibilityTable> {
  $$TokenVisibilityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tokenKey => $composableBuilder(
    column: $table.tokenKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TokenVisibilityTableAnnotationComposer
    extends Composer<_$OwDatabase, $TokenVisibilityTable> {
  $$TokenVisibilityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tokenKey =>
      $composableBuilder(column: $table.tokenKey, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);
}

class $$TokenVisibilityTableTableManager
    extends
        RootTableManager<
          _$OwDatabase,
          $TokenVisibilityTable,
          TokenVisibilityRow,
          $$TokenVisibilityTableFilterComposer,
          $$TokenVisibilityTableOrderingComposer,
          $$TokenVisibilityTableAnnotationComposer,
          $$TokenVisibilityTableCreateCompanionBuilder,
          $$TokenVisibilityTableUpdateCompanionBuilder,
          (
            TokenVisibilityRow,
            BaseReferences<
              _$OwDatabase,
              $TokenVisibilityTable,
              TokenVisibilityRow
            >,
          ),
          TokenVisibilityRow,
          PrefetchHooks Function()
        > {
  $$TokenVisibilityTableTableManager(
    _$OwDatabase db,
    $TokenVisibilityTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TokenVisibilityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TokenVisibilityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TokenVisibilityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tokenKey = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TokenVisibilityCompanion(
                tokenKey: tokenKey,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tokenKey,
                required bool hidden,
                Value<int> rowid = const Value.absent(),
              }) => TokenVisibilityCompanion.insert(
                tokenKey: tokenKey,
                hidden: hidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TokenVisibilityTable, TokenVisibilityRow>(table),
                  BaseReferences<
                    _$OwDatabase,
                    $TokenVisibilityTable,
                    TokenVisibilityRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TokenVisibilityTableProcessedTableManager =
    ProcessedTableManager<
      _$OwDatabase,
      $TokenVisibilityTable,
      TokenVisibilityRow,
      $$TokenVisibilityTableFilterComposer,
      $$TokenVisibilityTableOrderingComposer,
      $$TokenVisibilityTableAnnotationComposer,
      $$TokenVisibilityTableCreateCompanionBuilder,
      $$TokenVisibilityTableUpdateCompanionBuilder,
      (
        TokenVisibilityRow,
        BaseReferences<_$OwDatabase, $TokenVisibilityTable, TokenVisibilityRow>,
      ),
      TokenVisibilityRow,
      PrefetchHooks Function()
    >;

class $OwDatabaseManager {
  final _$OwDatabase _db;
  $OwDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$AddressesTableTableManager get addresses =>
      $$AddressesTableTableManager(_db, _db.addresses);
  $$HoldingsTableTableManager get holdings =>
      $$HoldingsTableTableManager(_db, _db.holdings);
  $$PricesTableTableManager get prices =>
      $$PricesTableTableManager(_db, _db.prices);
  $$SnapshotsTableTableManager get snapshots =>
      $$SnapshotsTableTableManager(_db, _db.snapshots);
  $$SnapshotItemsTableTableManager get snapshotItems =>
      $$SnapshotItemsTableTableManager(_db, _db.snapshotItems);
  $$VaultItemsMetaTableTableManager get vaultItemsMeta =>
      $$VaultItemsMetaTableTableManager(_db, _db.vaultItemsMeta);
  $$SyncRecordsTableTableManager get syncRecords =>
      $$SyncRecordsTableTableManager(_db, _db.syncRecords);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$TokenVisibilityTableTableManager get tokenVisibility =>
      $$TokenVisibilityTableTableManager(_db, _db.tokenVisibility);
}
