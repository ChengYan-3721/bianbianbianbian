// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserPrefTableTable extends UserPrefTable
    with TableInfo<$UserPrefTableTable, UserPrefEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPrefTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('id = 1'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentLedgerIdMeta = const VerificationMeta(
    'currentLedgerId',
  );
  @override
  late final GeneratedColumn<String> currentLedgerId = GeneratedColumn<String>(
    'current_ledger_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultCurrencyMeta = const VerificationMeta(
    'defaultCurrency',
  );
  @override
  late final GeneratedColumn<String> defaultCurrency = GeneratedColumn<String>(
    'default_currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CNY'),
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cream_bunny'),
  );
  static const VerificationMeta _lockEnabledMeta = const VerificationMeta(
    'lockEnabled',
  );
  @override
  late final GeneratedColumn<int> lockEnabled = GeneratedColumn<int>(
    'lock_enabled',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncEnabledMeta = const VerificationMeta(
    'syncEnabled',
  );
  @override
  late final GeneratedColumn<int> syncEnabled = GeneratedColumn<int>(
    'sync_enabled',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _multiCurrencyEnabledMeta =
      const VerificationMeta('multiCurrencyEnabled');
  @override
  late final GeneratedColumn<int> multiCurrencyEnabled = GeneratedColumn<int>(
    'multi_currency_enabled',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncAt = GeneratedColumn<int>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFxRefreshAtMeta = const VerificationMeta(
    'lastFxRefreshAt',
  );
  @override
  late final GeneratedColumn<int> lastFxRefreshAt = GeneratedColumn<int>(
    'last_fx_refresh_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiApiEndpointMeta = const VerificationMeta(
    'aiApiEndpoint',
  );
  @override
  late final GeneratedColumn<String> aiApiEndpoint = GeneratedColumn<String>(
    'ai_api_endpoint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiApiKeyEncryptedMeta = const VerificationMeta(
    'aiApiKeyEncrypted',
  );
  @override
  late final GeneratedColumn<Uint8List> aiApiKeyEncrypted =
      GeneratedColumn<Uint8List>(
        'ai_api_key_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _aiApiModelMeta = const VerificationMeta(
    'aiApiModel',
  );
  @override
  late final GeneratedColumn<String> aiApiModel = GeneratedColumn<String>(
    'ai_api_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiApiPromptTemplateMeta =
      const VerificationMeta('aiApiPromptTemplate');
  @override
  late final GeneratedColumn<String> aiApiPromptTemplate =
      GeneratedColumn<String>(
        'ai_api_prompt_template',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _aiInputEnabledMeta = const VerificationMeta(
    'aiInputEnabled',
  );
  @override
  late final GeneratedColumn<int> aiInputEnabled = GeneratedColumn<int>(
    'ai_input_enabled',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fontSizeMeta = const VerificationMeta(
    'fontSize',
  );
  @override
  late final GeneratedColumn<String> fontSize = GeneratedColumn<String>(
    'font_size',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('standard'),
  );
  static const VerificationMeta _iconPackMeta = const VerificationMeta(
    'iconPack',
  );
  @override
  late final GeneratedColumn<String> iconPack = GeneratedColumn<String>(
    'icon_pack',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sticker'),
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<int> reminderEnabled = GeneratedColumn<int>(
    'reminder_enabled',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reminderTimeMeta = const VerificationMeta(
    'reminderTime',
  );
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
    'reminder_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    currentLedgerId,
    defaultCurrency,
    theme,
    lockEnabled,
    syncEnabled,
    multiCurrencyEnabled,
    lastSyncAt,
    lastFxRefreshAt,
    aiApiEndpoint,
    aiApiKeyEncrypted,
    aiApiModel,
    aiApiPromptTemplate,
    aiInputEnabled,
    fontSize,
    iconPack,
    reminderEnabled,
    reminderTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_pref';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPrefEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('current_ledger_id')) {
      context.handle(
        _currentLedgerIdMeta,
        currentLedgerId.isAcceptableOrUnknown(
          data['current_ledger_id']!,
          _currentLedgerIdMeta,
        ),
      );
    }
    if (data.containsKey('default_currency')) {
      context.handle(
        _defaultCurrencyMeta,
        defaultCurrency.isAcceptableOrUnknown(
          data['default_currency']!,
          _defaultCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    if (data.containsKey('lock_enabled')) {
      context.handle(
        _lockEnabledMeta,
        lockEnabled.isAcceptableOrUnknown(
          data['lock_enabled']!,
          _lockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('sync_enabled')) {
      context.handle(
        _syncEnabledMeta,
        syncEnabled.isAcceptableOrUnknown(
          data['sync_enabled']!,
          _syncEnabledMeta,
        ),
      );
    }
    if (data.containsKey('multi_currency_enabled')) {
      context.handle(
        _multiCurrencyEnabledMeta,
        multiCurrencyEnabled.isAcceptableOrUnknown(
          data['multi_currency_enabled']!,
          _multiCurrencyEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_fx_refresh_at')) {
      context.handle(
        _lastFxRefreshAtMeta,
        lastFxRefreshAt.isAcceptableOrUnknown(
          data['last_fx_refresh_at']!,
          _lastFxRefreshAtMeta,
        ),
      );
    }
    if (data.containsKey('ai_api_endpoint')) {
      context.handle(
        _aiApiEndpointMeta,
        aiApiEndpoint.isAcceptableOrUnknown(
          data['ai_api_endpoint']!,
          _aiApiEndpointMeta,
        ),
      );
    }
    if (data.containsKey('ai_api_key_encrypted')) {
      context.handle(
        _aiApiKeyEncryptedMeta,
        aiApiKeyEncrypted.isAcceptableOrUnknown(
          data['ai_api_key_encrypted']!,
          _aiApiKeyEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('ai_api_model')) {
      context.handle(
        _aiApiModelMeta,
        aiApiModel.isAcceptableOrUnknown(
          data['ai_api_model']!,
          _aiApiModelMeta,
        ),
      );
    }
    if (data.containsKey('ai_api_prompt_template')) {
      context.handle(
        _aiApiPromptTemplateMeta,
        aiApiPromptTemplate.isAcceptableOrUnknown(
          data['ai_api_prompt_template']!,
          _aiApiPromptTemplateMeta,
        ),
      );
    }
    if (data.containsKey('ai_input_enabled')) {
      context.handle(
        _aiInputEnabledMeta,
        aiInputEnabled.isAcceptableOrUnknown(
          data['ai_input_enabled']!,
          _aiInputEnabledMeta,
        ),
      );
    }
    if (data.containsKey('font_size')) {
      context.handle(
        _fontSizeMeta,
        fontSize.isAcceptableOrUnknown(data['font_size']!, _fontSizeMeta),
      );
    }
    if (data.containsKey('icon_pack')) {
      context.handle(
        _iconPackMeta,
        iconPack.isAcceptableOrUnknown(data['icon_pack']!, _iconPackMeta),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
        _reminderTimeMeta,
        reminderTime.isAcceptableOrUnknown(
          data['reminder_time']!,
          _reminderTimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPrefEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPrefEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      currentLedgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_ledger_id'],
      ),
      defaultCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_currency'],
      ),
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      ),
      lockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lock_enabled'],
      ),
      syncEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_enabled'],
      ),
      multiCurrencyEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}multi_currency_enabled'],
      ),
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync_at'],
      ),
      lastFxRefreshAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_fx_refresh_at'],
      ),
      aiApiEndpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_api_endpoint'],
      ),
      aiApiKeyEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}ai_api_key_encrypted'],
      ),
      aiApiModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_api_model'],
      ),
      aiApiPromptTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_api_prompt_template'],
      ),
      aiInputEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ai_input_enabled'],
      ),
      fontSize: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}font_size'],
      ),
      iconPack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_pack'],
      ),
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_enabled'],
      ),
      reminderTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_time'],
      ),
    );
  }

  @override
  $UserPrefTableTable createAlias(String alias) {
    return $UserPrefTableTable(attachedDatabase, alias);
  }
}

class UserPrefEntry extends DataClass implements Insertable<UserPrefEntry> {
  final int id;
  final String deviceId;
  final String? currentLedgerId;
  final String? defaultCurrency;
  final String? theme;
  final int? lockEnabled;
  final int? syncEnabled;

  /// Step 8.1：多币种全局开关。0 = 关闭（默认；记账页币种字段隐藏），
  /// 1 = 开启（记账页可选币种、统计页按账本默认币种换算展示）。
  final int? multiCurrencyEnabled;
  final int? lastSyncAt;

  /// Step 8.3：上次汇率自动刷新时间（epoch ms）。null = 从未刷新。
  /// 用于"每日最多一次"节流，[FxRateRefreshService.refreshIfDue] 据此判断。
  final int? lastFxRefreshAt;

  /// 历史遗留列（自 Step 4.2 user_pref 表初次落库即存在，但直到 Step 9.3
  /// 才被消费）：用户在"我的 → 快速输入 → AI 增强"页配置的 LLM endpoint URL。
  final String? aiApiEndpoint;

  /// 历史遗留列（同上）：API key 的存放位置。
  ///
  /// **当前实现（Step 9.3）**：UTF-8 编码后的 raw bytes（即"未加密"），整个 DB 由
  /// SQLCipher 加密保护，故 at-rest 安全已由 DB 级别覆盖；列名带 `_encrypted`
  /// 是为 Phase 11 [BianbianCrypto] 字段级加密预留的——届时会用同步密码派生
  /// 出的 key 重写读写路径，本列名保持不变。
  final Uint8List? aiApiKeyEncrypted;

  /// Step 9.3：AI 增强使用的模型名（如 `'gpt-4o-mini'` / `'qwen-turbo'`）。
  /// 用户在配置页填写；为空时 [AiInputSettings.hasMinimalConfig] = false。
  final String? aiApiModel;

  /// Step 9.3：AI 增强使用的 prompt 模板（含 `{NOW}` / `{TEXT}` / `{CATEGORIES}`
  /// 占位符）。为空时使用 [kDefaultAiInputPromptTemplate] 兜底。
  final String? aiApiPromptTemplate;

  /// Step 9.3：AI 增强全局开关。0/null = 关闭（默认；确认卡片不显示 AI 增强按钮），
  /// 1 = 开启（且只有 endpoint + key + model 三件齐全才会真正显示按钮）。
  final int? aiInputEnabled;

  /// Step 15.2：字号档位。'small' / 'standard'(默认) / 'large'。
  final String? fontSize;

  /// Step 15.3：分类图标包。'sticker'(默认/手绘贴纸) / 'flat'(扁平简约)。
  final String? iconPack;

  /// Step 16.1：每日记账提醒开关。0/null = 关闭（默认），1 = 开启。
  final int? reminderEnabled;

  /// Step 16.1：每日记账提醒时间，格式 'HH:mm'（如 '20:00'）。
  /// null = 从未设置（默认）；开启提醒时 UI 应要求用户先选时间。
  final String? reminderTime;
  const UserPrefEntry({
    required this.id,
    required this.deviceId,
    this.currentLedgerId,
    this.defaultCurrency,
    this.theme,
    this.lockEnabled,
    this.syncEnabled,
    this.multiCurrencyEnabled,
    this.lastSyncAt,
    this.lastFxRefreshAt,
    this.aiApiEndpoint,
    this.aiApiKeyEncrypted,
    this.aiApiModel,
    this.aiApiPromptTemplate,
    this.aiInputEnabled,
    this.fontSize,
    this.iconPack,
    this.reminderEnabled,
    this.reminderTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || currentLedgerId != null) {
      map['current_ledger_id'] = Variable<String>(currentLedgerId);
    }
    if (!nullToAbsent || defaultCurrency != null) {
      map['default_currency'] = Variable<String>(defaultCurrency);
    }
    if (!nullToAbsent || theme != null) {
      map['theme'] = Variable<String>(theme);
    }
    if (!nullToAbsent || lockEnabled != null) {
      map['lock_enabled'] = Variable<int>(lockEnabled);
    }
    if (!nullToAbsent || syncEnabled != null) {
      map['sync_enabled'] = Variable<int>(syncEnabled);
    }
    if (!nullToAbsent || multiCurrencyEnabled != null) {
      map['multi_currency_enabled'] = Variable<int>(multiCurrencyEnabled);
    }
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<int>(lastSyncAt);
    }
    if (!nullToAbsent || lastFxRefreshAt != null) {
      map['last_fx_refresh_at'] = Variable<int>(lastFxRefreshAt);
    }
    if (!nullToAbsent || aiApiEndpoint != null) {
      map['ai_api_endpoint'] = Variable<String>(aiApiEndpoint);
    }
    if (!nullToAbsent || aiApiKeyEncrypted != null) {
      map['ai_api_key_encrypted'] = Variable<Uint8List>(aiApiKeyEncrypted);
    }
    if (!nullToAbsent || aiApiModel != null) {
      map['ai_api_model'] = Variable<String>(aiApiModel);
    }
    if (!nullToAbsent || aiApiPromptTemplate != null) {
      map['ai_api_prompt_template'] = Variable<String>(aiApiPromptTemplate);
    }
    if (!nullToAbsent || aiInputEnabled != null) {
      map['ai_input_enabled'] = Variable<int>(aiInputEnabled);
    }
    if (!nullToAbsent || fontSize != null) {
      map['font_size'] = Variable<String>(fontSize);
    }
    if (!nullToAbsent || iconPack != null) {
      map['icon_pack'] = Variable<String>(iconPack);
    }
    if (!nullToAbsent || reminderEnabled != null) {
      map['reminder_enabled'] = Variable<int>(reminderEnabled);
    }
    if (!nullToAbsent || reminderTime != null) {
      map['reminder_time'] = Variable<String>(reminderTime);
    }
    return map;
  }

  UserPrefTableCompanion toCompanion(bool nullToAbsent) {
    return UserPrefTableCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      currentLedgerId: currentLedgerId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentLedgerId),
      defaultCurrency: defaultCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultCurrency),
      theme: theme == null && nullToAbsent
          ? const Value.absent()
          : Value(theme),
      lockEnabled: lockEnabled == null && nullToAbsent
          ? const Value.absent()
          : Value(lockEnabled),
      syncEnabled: syncEnabled == null && nullToAbsent
          ? const Value.absent()
          : Value(syncEnabled),
      multiCurrencyEnabled: multiCurrencyEnabled == null && nullToAbsent
          ? const Value.absent()
          : Value(multiCurrencyEnabled),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastFxRefreshAt: lastFxRefreshAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFxRefreshAt),
      aiApiEndpoint: aiApiEndpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(aiApiEndpoint),
      aiApiKeyEncrypted: aiApiKeyEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(aiApiKeyEncrypted),
      aiApiModel: aiApiModel == null && nullToAbsent
          ? const Value.absent()
          : Value(aiApiModel),
      aiApiPromptTemplate: aiApiPromptTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(aiApiPromptTemplate),
      aiInputEnabled: aiInputEnabled == null && nullToAbsent
          ? const Value.absent()
          : Value(aiInputEnabled),
      fontSize: fontSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fontSize),
      iconPack: iconPack == null && nullToAbsent
          ? const Value.absent()
          : Value(iconPack),
      reminderEnabled: reminderEnabled == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderEnabled),
      reminderTime: reminderTime == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderTime),
    );
  }

  factory UserPrefEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPrefEntry(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      currentLedgerId: serializer.fromJson<String?>(json['currentLedgerId']),
      defaultCurrency: serializer.fromJson<String?>(json['defaultCurrency']),
      theme: serializer.fromJson<String?>(json['theme']),
      lockEnabled: serializer.fromJson<int?>(json['lockEnabled']),
      syncEnabled: serializer.fromJson<int?>(json['syncEnabled']),
      multiCurrencyEnabled: serializer.fromJson<int?>(
        json['multiCurrencyEnabled'],
      ),
      lastSyncAt: serializer.fromJson<int?>(json['lastSyncAt']),
      lastFxRefreshAt: serializer.fromJson<int?>(json['lastFxRefreshAt']),
      aiApiEndpoint: serializer.fromJson<String?>(json['aiApiEndpoint']),
      aiApiKeyEncrypted: serializer.fromJson<Uint8List?>(
        json['aiApiKeyEncrypted'],
      ),
      aiApiModel: serializer.fromJson<String?>(json['aiApiModel']),
      aiApiPromptTemplate: serializer.fromJson<String?>(
        json['aiApiPromptTemplate'],
      ),
      aiInputEnabled: serializer.fromJson<int?>(json['aiInputEnabled']),
      fontSize: serializer.fromJson<String?>(json['fontSize']),
      iconPack: serializer.fromJson<String?>(json['iconPack']),
      reminderEnabled: serializer.fromJson<int?>(json['reminderEnabled']),
      reminderTime: serializer.fromJson<String?>(json['reminderTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'currentLedgerId': serializer.toJson<String?>(currentLedgerId),
      'defaultCurrency': serializer.toJson<String?>(defaultCurrency),
      'theme': serializer.toJson<String?>(theme),
      'lockEnabled': serializer.toJson<int?>(lockEnabled),
      'syncEnabled': serializer.toJson<int?>(syncEnabled),
      'multiCurrencyEnabled': serializer.toJson<int?>(multiCurrencyEnabled),
      'lastSyncAt': serializer.toJson<int?>(lastSyncAt),
      'lastFxRefreshAt': serializer.toJson<int?>(lastFxRefreshAt),
      'aiApiEndpoint': serializer.toJson<String?>(aiApiEndpoint),
      'aiApiKeyEncrypted': serializer.toJson<Uint8List?>(aiApiKeyEncrypted),
      'aiApiModel': serializer.toJson<String?>(aiApiModel),
      'aiApiPromptTemplate': serializer.toJson<String?>(aiApiPromptTemplate),
      'aiInputEnabled': serializer.toJson<int?>(aiInputEnabled),
      'fontSize': serializer.toJson<String?>(fontSize),
      'iconPack': serializer.toJson<String?>(iconPack),
      'reminderEnabled': serializer.toJson<int?>(reminderEnabled),
      'reminderTime': serializer.toJson<String?>(reminderTime),
    };
  }

  UserPrefEntry copyWith({
    int? id,
    String? deviceId,
    Value<String?> currentLedgerId = const Value.absent(),
    Value<String?> defaultCurrency = const Value.absent(),
    Value<String?> theme = const Value.absent(),
    Value<int?> lockEnabled = const Value.absent(),
    Value<int?> syncEnabled = const Value.absent(),
    Value<int?> multiCurrencyEnabled = const Value.absent(),
    Value<int?> lastSyncAt = const Value.absent(),
    Value<int?> lastFxRefreshAt = const Value.absent(),
    Value<String?> aiApiEndpoint = const Value.absent(),
    Value<Uint8List?> aiApiKeyEncrypted = const Value.absent(),
    Value<String?> aiApiModel = const Value.absent(),
    Value<String?> aiApiPromptTemplate = const Value.absent(),
    Value<int?> aiInputEnabled = const Value.absent(),
    Value<String?> fontSize = const Value.absent(),
    Value<String?> iconPack = const Value.absent(),
    Value<int?> reminderEnabled = const Value.absent(),
    Value<String?> reminderTime = const Value.absent(),
  }) => UserPrefEntry(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    currentLedgerId: currentLedgerId.present
        ? currentLedgerId.value
        : this.currentLedgerId,
    defaultCurrency: defaultCurrency.present
        ? defaultCurrency.value
        : this.defaultCurrency,
    theme: theme.present ? theme.value : this.theme,
    lockEnabled: lockEnabled.present ? lockEnabled.value : this.lockEnabled,
    syncEnabled: syncEnabled.present ? syncEnabled.value : this.syncEnabled,
    multiCurrencyEnabled: multiCurrencyEnabled.present
        ? multiCurrencyEnabled.value
        : this.multiCurrencyEnabled,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    lastFxRefreshAt: lastFxRefreshAt.present
        ? lastFxRefreshAt.value
        : this.lastFxRefreshAt,
    aiApiEndpoint: aiApiEndpoint.present
        ? aiApiEndpoint.value
        : this.aiApiEndpoint,
    aiApiKeyEncrypted: aiApiKeyEncrypted.present
        ? aiApiKeyEncrypted.value
        : this.aiApiKeyEncrypted,
    aiApiModel: aiApiModel.present ? aiApiModel.value : this.aiApiModel,
    aiApiPromptTemplate: aiApiPromptTemplate.present
        ? aiApiPromptTemplate.value
        : this.aiApiPromptTemplate,
    aiInputEnabled: aiInputEnabled.present
        ? aiInputEnabled.value
        : this.aiInputEnabled,
    fontSize: fontSize.present ? fontSize.value : this.fontSize,
    iconPack: iconPack.present ? iconPack.value : this.iconPack,
    reminderEnabled: reminderEnabled.present
        ? reminderEnabled.value
        : this.reminderEnabled,
    reminderTime: reminderTime.present ? reminderTime.value : this.reminderTime,
  );
  UserPrefEntry copyWithCompanion(UserPrefTableCompanion data) {
    return UserPrefEntry(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      currentLedgerId: data.currentLedgerId.present
          ? data.currentLedgerId.value
          : this.currentLedgerId,
      defaultCurrency: data.defaultCurrency.present
          ? data.defaultCurrency.value
          : this.defaultCurrency,
      theme: data.theme.present ? data.theme.value : this.theme,
      lockEnabled: data.lockEnabled.present
          ? data.lockEnabled.value
          : this.lockEnabled,
      syncEnabled: data.syncEnabled.present
          ? data.syncEnabled.value
          : this.syncEnabled,
      multiCurrencyEnabled: data.multiCurrencyEnabled.present
          ? data.multiCurrencyEnabled.value
          : this.multiCurrencyEnabled,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      lastFxRefreshAt: data.lastFxRefreshAt.present
          ? data.lastFxRefreshAt.value
          : this.lastFxRefreshAt,
      aiApiEndpoint: data.aiApiEndpoint.present
          ? data.aiApiEndpoint.value
          : this.aiApiEndpoint,
      aiApiKeyEncrypted: data.aiApiKeyEncrypted.present
          ? data.aiApiKeyEncrypted.value
          : this.aiApiKeyEncrypted,
      aiApiModel: data.aiApiModel.present
          ? data.aiApiModel.value
          : this.aiApiModel,
      aiApiPromptTemplate: data.aiApiPromptTemplate.present
          ? data.aiApiPromptTemplate.value
          : this.aiApiPromptTemplate,
      aiInputEnabled: data.aiInputEnabled.present
          ? data.aiInputEnabled.value
          : this.aiInputEnabled,
      fontSize: data.fontSize.present ? data.fontSize.value : this.fontSize,
      iconPack: data.iconPack.present ? data.iconPack.value : this.iconPack,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderTime: data.reminderTime.present
          ? data.reminderTime.value
          : this.reminderTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPrefEntry(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('currentLedgerId: $currentLedgerId, ')
          ..write('defaultCurrency: $defaultCurrency, ')
          ..write('theme: $theme, ')
          ..write('lockEnabled: $lockEnabled, ')
          ..write('syncEnabled: $syncEnabled, ')
          ..write('multiCurrencyEnabled: $multiCurrencyEnabled, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastFxRefreshAt: $lastFxRefreshAt, ')
          ..write('aiApiEndpoint: $aiApiEndpoint, ')
          ..write('aiApiKeyEncrypted: $aiApiKeyEncrypted, ')
          ..write('aiApiModel: $aiApiModel, ')
          ..write('aiApiPromptTemplate: $aiApiPromptTemplate, ')
          ..write('aiInputEnabled: $aiInputEnabled, ')
          ..write('fontSize: $fontSize, ')
          ..write('iconPack: $iconPack, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderTime: $reminderTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    currentLedgerId,
    defaultCurrency,
    theme,
    lockEnabled,
    syncEnabled,
    multiCurrencyEnabled,
    lastSyncAt,
    lastFxRefreshAt,
    aiApiEndpoint,
    $driftBlobEquality.hash(aiApiKeyEncrypted),
    aiApiModel,
    aiApiPromptTemplate,
    aiInputEnabled,
    fontSize,
    iconPack,
    reminderEnabled,
    reminderTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPrefEntry &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.currentLedgerId == this.currentLedgerId &&
          other.defaultCurrency == this.defaultCurrency &&
          other.theme == this.theme &&
          other.lockEnabled == this.lockEnabled &&
          other.syncEnabled == this.syncEnabled &&
          other.multiCurrencyEnabled == this.multiCurrencyEnabled &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastFxRefreshAt == this.lastFxRefreshAt &&
          other.aiApiEndpoint == this.aiApiEndpoint &&
          $driftBlobEquality.equals(
            other.aiApiKeyEncrypted,
            this.aiApiKeyEncrypted,
          ) &&
          other.aiApiModel == this.aiApiModel &&
          other.aiApiPromptTemplate == this.aiApiPromptTemplate &&
          other.aiInputEnabled == this.aiInputEnabled &&
          other.fontSize == this.fontSize &&
          other.iconPack == this.iconPack &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderTime == this.reminderTime);
}

class UserPrefTableCompanion extends UpdateCompanion<UserPrefEntry> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<String?> currentLedgerId;
  final Value<String?> defaultCurrency;
  final Value<String?> theme;
  final Value<int?> lockEnabled;
  final Value<int?> syncEnabled;
  final Value<int?> multiCurrencyEnabled;
  final Value<int?> lastSyncAt;
  final Value<int?> lastFxRefreshAt;
  final Value<String?> aiApiEndpoint;
  final Value<Uint8List?> aiApiKeyEncrypted;
  final Value<String?> aiApiModel;
  final Value<String?> aiApiPromptTemplate;
  final Value<int?> aiInputEnabled;
  final Value<String?> fontSize;
  final Value<String?> iconPack;
  final Value<int?> reminderEnabled;
  final Value<String?> reminderTime;
  const UserPrefTableCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.currentLedgerId = const Value.absent(),
    this.defaultCurrency = const Value.absent(),
    this.theme = const Value.absent(),
    this.lockEnabled = const Value.absent(),
    this.syncEnabled = const Value.absent(),
    this.multiCurrencyEnabled = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastFxRefreshAt = const Value.absent(),
    this.aiApiEndpoint = const Value.absent(),
    this.aiApiKeyEncrypted = const Value.absent(),
    this.aiApiModel = const Value.absent(),
    this.aiApiPromptTemplate = const Value.absent(),
    this.aiInputEnabled = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.iconPack = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderTime = const Value.absent(),
  });
  UserPrefTableCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    this.currentLedgerId = const Value.absent(),
    this.defaultCurrency = const Value.absent(),
    this.theme = const Value.absent(),
    this.lockEnabled = const Value.absent(),
    this.syncEnabled = const Value.absent(),
    this.multiCurrencyEnabled = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastFxRefreshAt = const Value.absent(),
    this.aiApiEndpoint = const Value.absent(),
    this.aiApiKeyEncrypted = const Value.absent(),
    this.aiApiModel = const Value.absent(),
    this.aiApiPromptTemplate = const Value.absent(),
    this.aiInputEnabled = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.iconPack = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderTime = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<UserPrefEntry> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<String>? currentLedgerId,
    Expression<String>? defaultCurrency,
    Expression<String>? theme,
    Expression<int>? lockEnabled,
    Expression<int>? syncEnabled,
    Expression<int>? multiCurrencyEnabled,
    Expression<int>? lastSyncAt,
    Expression<int>? lastFxRefreshAt,
    Expression<String>? aiApiEndpoint,
    Expression<Uint8List>? aiApiKeyEncrypted,
    Expression<String>? aiApiModel,
    Expression<String>? aiApiPromptTemplate,
    Expression<int>? aiInputEnabled,
    Expression<String>? fontSize,
    Expression<String>? iconPack,
    Expression<int>? reminderEnabled,
    Expression<String>? reminderTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (currentLedgerId != null) 'current_ledger_id': currentLedgerId,
      if (defaultCurrency != null) 'default_currency': defaultCurrency,
      if (theme != null) 'theme': theme,
      if (lockEnabled != null) 'lock_enabled': lockEnabled,
      if (syncEnabled != null) 'sync_enabled': syncEnabled,
      if (multiCurrencyEnabled != null)
        'multi_currency_enabled': multiCurrencyEnabled,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastFxRefreshAt != null) 'last_fx_refresh_at': lastFxRefreshAt,
      if (aiApiEndpoint != null) 'ai_api_endpoint': aiApiEndpoint,
      if (aiApiKeyEncrypted != null) 'ai_api_key_encrypted': aiApiKeyEncrypted,
      if (aiApiModel != null) 'ai_api_model': aiApiModel,
      if (aiApiPromptTemplate != null)
        'ai_api_prompt_template': aiApiPromptTemplate,
      if (aiInputEnabled != null) 'ai_input_enabled': aiInputEnabled,
      if (fontSize != null) 'font_size': fontSize,
      if (iconPack != null) 'icon_pack': iconPack,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderTime != null) 'reminder_time': reminderTime,
    });
  }

  UserPrefTableCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceId,
    Value<String?>? currentLedgerId,
    Value<String?>? defaultCurrency,
    Value<String?>? theme,
    Value<int?>? lockEnabled,
    Value<int?>? syncEnabled,
    Value<int?>? multiCurrencyEnabled,
    Value<int?>? lastSyncAt,
    Value<int?>? lastFxRefreshAt,
    Value<String?>? aiApiEndpoint,
    Value<Uint8List?>? aiApiKeyEncrypted,
    Value<String?>? aiApiModel,
    Value<String?>? aiApiPromptTemplate,
    Value<int?>? aiInputEnabled,
    Value<String?>? fontSize,
    Value<String?>? iconPack,
    Value<int?>? reminderEnabled,
    Value<String?>? reminderTime,
  }) {
    return UserPrefTableCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      currentLedgerId: currentLedgerId ?? this.currentLedgerId,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      theme: theme ?? this.theme,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      multiCurrencyEnabled: multiCurrencyEnabled ?? this.multiCurrencyEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastFxRefreshAt: lastFxRefreshAt ?? this.lastFxRefreshAt,
      aiApiEndpoint: aiApiEndpoint ?? this.aiApiEndpoint,
      aiApiKeyEncrypted: aiApiKeyEncrypted ?? this.aiApiKeyEncrypted,
      aiApiModel: aiApiModel ?? this.aiApiModel,
      aiApiPromptTemplate: aiApiPromptTemplate ?? this.aiApiPromptTemplate,
      aiInputEnabled: aiInputEnabled ?? this.aiInputEnabled,
      fontSize: fontSize ?? this.fontSize,
      iconPack: iconPack ?? this.iconPack,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (currentLedgerId.present) {
      map['current_ledger_id'] = Variable<String>(currentLedgerId.value);
    }
    if (defaultCurrency.present) {
      map['default_currency'] = Variable<String>(defaultCurrency.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (lockEnabled.present) {
      map['lock_enabled'] = Variable<int>(lockEnabled.value);
    }
    if (syncEnabled.present) {
      map['sync_enabled'] = Variable<int>(syncEnabled.value);
    }
    if (multiCurrencyEnabled.present) {
      map['multi_currency_enabled'] = Variable<int>(multiCurrencyEnabled.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<int>(lastSyncAt.value);
    }
    if (lastFxRefreshAt.present) {
      map['last_fx_refresh_at'] = Variable<int>(lastFxRefreshAt.value);
    }
    if (aiApiEndpoint.present) {
      map['ai_api_endpoint'] = Variable<String>(aiApiEndpoint.value);
    }
    if (aiApiKeyEncrypted.present) {
      map['ai_api_key_encrypted'] = Variable<Uint8List>(
        aiApiKeyEncrypted.value,
      );
    }
    if (aiApiModel.present) {
      map['ai_api_model'] = Variable<String>(aiApiModel.value);
    }
    if (aiApiPromptTemplate.present) {
      map['ai_api_prompt_template'] = Variable<String>(
        aiApiPromptTemplate.value,
      );
    }
    if (aiInputEnabled.present) {
      map['ai_input_enabled'] = Variable<int>(aiInputEnabled.value);
    }
    if (fontSize.present) {
      map['font_size'] = Variable<String>(fontSize.value);
    }
    if (iconPack.present) {
      map['icon_pack'] = Variable<String>(iconPack.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<int>(reminderEnabled.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPrefTableCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('currentLedgerId: $currentLedgerId, ')
          ..write('defaultCurrency: $defaultCurrency, ')
          ..write('theme: $theme, ')
          ..write('lockEnabled: $lockEnabled, ')
          ..write('syncEnabled: $syncEnabled, ')
          ..write('multiCurrencyEnabled: $multiCurrencyEnabled, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastFxRefreshAt: $lastFxRefreshAt, ')
          ..write('aiApiEndpoint: $aiApiEndpoint, ')
          ..write('aiApiKeyEncrypted: $aiApiKeyEncrypted, ')
          ..write('aiApiModel: $aiApiModel, ')
          ..write('aiApiPromptTemplate: $aiApiPromptTemplate, ')
          ..write('aiInputEnabled: $aiInputEnabled, ')
          ..write('fontSize: $fontSize, ')
          ..write('iconPack: $iconPack, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderTime: $reminderTime')
          ..write(')'))
        .toString();
  }
}

class $LedgerTableTable extends LedgerTable
    with TableInfo<$LedgerTableTable, LedgerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _coverEmojiMeta = const VerificationMeta(
    'coverEmoji',
  );
  @override
  late final GeneratedColumn<String> coverEmoji = GeneratedColumn<String>(
    'cover_emoji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultCurrencyMeta = const VerificationMeta(
    'defaultCurrency',
  );
  @override
  late final GeneratedColumn<String> defaultCurrency = GeneratedColumn<String>(
    'default_currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CNY'),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<int> archived = GeneratedColumn<int>(
    'archived',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    coverEmoji,
    defaultCurrency,
    archived,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerEntry> instance, {
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
    if (data.containsKey('cover_emoji')) {
      context.handle(
        _coverEmojiMeta,
        coverEmoji.isAcceptableOrUnknown(data['cover_emoji']!, _coverEmojiMeta),
      );
    }
    if (data.containsKey('default_currency')) {
      context.handle(
        _defaultCurrencyMeta,
        defaultCurrency.isAcceptableOrUnknown(
          data['default_currency']!,
          _defaultCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      coverEmoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_emoji'],
      ),
      defaultCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_currency'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $LedgerTableTable createAlias(String alias) {
    return $LedgerTableTable(attachedDatabase, alias);
  }
}

class LedgerEntry extends DataClass implements Insertable<LedgerEntry> {
  final String id;
  final String name;
  final String? coverEmoji;
  final String? defaultCurrency;
  final int? archived;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  const LedgerEntry({
    required this.id,
    required this.name,
    this.coverEmoji,
    this.defaultCurrency,
    this.archived,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || coverEmoji != null) {
      map['cover_emoji'] = Variable<String>(coverEmoji);
    }
    if (!nullToAbsent || defaultCurrency != null) {
      map['default_currency'] = Variable<String>(defaultCurrency);
    }
    if (!nullToAbsent || archived != null) {
      map['archived'] = Variable<int>(archived);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  LedgerTableCompanion toCompanion(bool nullToAbsent) {
    return LedgerTableCompanion(
      id: Value(id),
      name: Value(name),
      coverEmoji: coverEmoji == null && nullToAbsent
          ? const Value.absent()
          : Value(coverEmoji),
      defaultCurrency: defaultCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultCurrency),
      archived: archived == null && nullToAbsent
          ? const Value.absent()
          : Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory LedgerEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      coverEmoji: serializer.fromJson<String?>(json['coverEmoji']),
      defaultCurrency: serializer.fromJson<String?>(json['defaultCurrency']),
      archived: serializer.fromJson<int?>(json['archived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'coverEmoji': serializer.toJson<String?>(coverEmoji),
      'defaultCurrency': serializer.toJson<String?>(defaultCurrency),
      'archived': serializer.toJson<int?>(archived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  LedgerEntry copyWith({
    String? id,
    String? name,
    Value<String?> coverEmoji = const Value.absent(),
    Value<String?> defaultCurrency = const Value.absent(),
    Value<int?> archived = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => LedgerEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    coverEmoji: coverEmoji.present ? coverEmoji.value : this.coverEmoji,
    defaultCurrency: defaultCurrency.present
        ? defaultCurrency.value
        : this.defaultCurrency,
    archived: archived.present ? archived.value : this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  LedgerEntry copyWithCompanion(LedgerTableCompanion data) {
    return LedgerEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      coverEmoji: data.coverEmoji.present
          ? data.coverEmoji.value
          : this.coverEmoji,
      defaultCurrency: data.defaultCurrency.present
          ? data.defaultCurrency.value
          : this.defaultCurrency,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverEmoji: $coverEmoji, ')
          ..write('defaultCurrency: $defaultCurrency, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    coverEmoji,
    defaultCurrency,
    archived,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.coverEmoji == this.coverEmoji &&
          other.defaultCurrency == this.defaultCurrency &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class LedgerTableCompanion extends UpdateCompanion<LedgerEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> coverEmoji;
  final Value<String?> defaultCurrency;
  final Value<int?> archived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const LedgerTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.coverEmoji = const Value.absent(),
    this.defaultCurrency = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerTableCompanion.insert({
    required String id,
    required String name,
    this.coverEmoji = const Value.absent(),
    this.defaultCurrency = const Value.absent(),
    this.archived = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<LedgerEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? coverEmoji,
    Expression<String>? defaultCurrency,
    Expression<int>? archived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (coverEmoji != null) 'cover_emoji': coverEmoji,
      if (defaultCurrency != null) 'default_currency': defaultCurrency,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? coverEmoji,
    Value<String?>? defaultCurrency,
    Value<int?>? archived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return LedgerTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      coverEmoji: coverEmoji ?? this.coverEmoji,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
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
    if (coverEmoji.present) {
      map['cover_emoji'] = Variable<String>(coverEmoji.value);
    }
    if (defaultCurrency.present) {
      map['default_currency'] = Variable<String>(defaultCurrency.value);
    }
    if (archived.present) {
      map['archived'] = Variable<int>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverEmoji: $coverEmoji, ')
          ..write('defaultCurrency: $defaultCurrency, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryTableTable extends CategoryTable
    with TableInfo<$CategoryTableTable, CategoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentKeyMeta = const VerificationMeta(
    'parentKey',
  );
  @override
  late final GeneratedColumn<String> parentKey = GeneratedColumn<String>(
    'parent_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<int> isFavorite = GeneratedColumn<int>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    color,
    parentKey,
    sortOrder,
    isFavorite,
    updatedAt,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryEntry> instance, {
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
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('parent_key')) {
      context.handle(
        _parentKeyMeta,
        parentKey.isAcceptableOrUnknown(data['parent_key']!, _parentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_parentKeyMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      parentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_key'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_favorite'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $CategoryTableTable createAlias(String alias) {
    return $CategoryTableTable(attachedDatabase, alias);
  }
}

class CategoryEntry extends DataClass implements Insertable<CategoryEntry> {
  final String id;

  /// 二级分类名称。
  final String name;

  /// 图标（emoji 或资源 key）。
  final String? icon;

  /// 颜色（hex）。
  final String? color;

  /// 一级分类 key：
  /// income | food | shopping | transport | education | entertainment |
  /// social | housing | medical | investment | other
  final String parentKey;

  /// 同一级分类内排序值。
  final int sortOrder;

  /// 收藏（0/1）。
  final int isFavorite;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  const CategoryEntry({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.parentKey,
    required this.sortOrder,
    required this.isFavorite,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['parent_key'] = Variable<String>(parentKey);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_favorite'] = Variable<int>(isFavorite);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  CategoryTableCompanion toCompanion(bool nullToAbsent) {
    return CategoryTableCompanion(
      id: Value(id),
      name: Value(name),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      parentKey: Value(parentKey),
      sortOrder: Value(sortOrder),
      isFavorite: Value(isFavorite),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory CategoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      parentKey: serializer.fromJson<String>(json['parentKey']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isFavorite: serializer.fromJson<int>(json['isFavorite']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'parentKey': serializer.toJson<String>(parentKey),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isFavorite': serializer.toJson<int>(isFavorite),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  CategoryEntry copyWith({
    String? id,
    String? name,
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
    String? parentKey,
    int? sortOrder,
    int? isFavorite,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => CategoryEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    parentKey: parentKey ?? this.parentKey,
    sortOrder: sortOrder ?? this.sortOrder,
    isFavorite: isFavorite ?? this.isFavorite,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  CategoryEntry copyWithCompanion(CategoryTableCompanion data) {
    return CategoryEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      parentKey: data.parentKey.present ? data.parentKey.value : this.parentKey,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('parentKey: $parentKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    icon,
    color,
    parentKey,
    sortOrder,
    isFavorite,
    updatedAt,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.parentKey == this.parentKey &&
          other.sortOrder == this.sortOrder &&
          other.isFavorite == this.isFavorite &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class CategoryTableCompanion extends UpdateCompanion<CategoryEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<String> parentKey;
  final Value<int> sortOrder;
  final Value<int> isFavorite;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const CategoryTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.parentKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryTableCompanion.insert({
    required String id,
    required String name,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    required String parentKey,
    this.sortOrder = const Value.absent(),
    this.isFavorite = const Value.absent(),
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       parentKey = Value(parentKey),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<CategoryEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<String>? parentKey,
    Expression<int>? sortOrder,
    Expression<int>? isFavorite,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (parentKey != null) 'parent_key': parentKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? icon,
    Value<String?>? color,
    Value<String>? parentKey,
    Value<int>? sortOrder,
    Value<int>? isFavorite,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return CategoryTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      parentKey: parentKey ?? this.parentKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
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
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (parentKey.present) {
      map['parent_key'] = Variable<String>(parentKey.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<int>(isFavorite.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('parentKey: $parentKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountTableTable extends AccountTable
    with TableInfo<$AccountTableTable, AccountEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _initialBalanceMeta = const VerificationMeta(
    'initialBalance',
  );
  @override
  late final GeneratedColumn<double> initialBalance = GeneratedColumn<double>(
    'initial_balance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _includeInTotalMeta = const VerificationMeta(
    'includeInTotal',
  );
  @override
  late final GeneratedColumn<int> includeInTotal = GeneratedColumn<int>(
    'include_in_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CNY'),
  );
  static const VerificationMeta _billingDayMeta = const VerificationMeta(
    'billingDay',
  );
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
    'billing_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repaymentDayMeta = const VerificationMeta(
    'repaymentDay',
  );
  @override
  late final GeneratedColumn<int> repaymentDay = GeneratedColumn<int>(
    'repayment_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    icon,
    color,
    initialBalance,
    includeInTotal,
    currency,
    billingDay,
    repaymentDay,
    updatedAt,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountEntry> instance, {
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
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('initial_balance')) {
      context.handle(
        _initialBalanceMeta,
        initialBalance.isAcceptableOrUnknown(
          data['initial_balance']!,
          _initialBalanceMeta,
        ),
      );
    }
    if (data.containsKey('include_in_total')) {
      context.handle(
        _includeInTotalMeta,
        includeInTotal.isAcceptableOrUnknown(
          data['include_in_total']!,
          _includeInTotalMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('billing_day')) {
      context.handle(
        _billingDayMeta,
        billingDay.isAcceptableOrUnknown(data['billing_day']!, _billingDayMeta),
      );
    }
    if (data.containsKey('repayment_day')) {
      context.handle(
        _repaymentDayMeta,
        repaymentDay.isAcceptableOrUnknown(
          data['repayment_day']!,
          _repaymentDayMeta,
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      initialBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}initial_balance'],
      ),
      includeInTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}include_in_total'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      billingDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billing_day'],
      ),
      repaymentDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repayment_day'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $AccountTableTable createAlias(String alias) {
    return $AccountTableTable(attachedDatabase, alias);
  }
}

class AccountEntry extends DataClass implements Insertable<AccountEntry> {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final double? initialBalance;
  final int? includeInTotal;
  final String? currency;

  /// 账单日（信用卡专属，1-28），nullable。Step 7.3。
  final int? billingDay;

  /// 还款日（信用卡专属，1-28），nullable。Step 7.3。
  final int? repaymentDay;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  const AccountEntry({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.initialBalance,
    this.includeInTotal,
    this.currency,
    this.billingDay,
    this.repaymentDay,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || initialBalance != null) {
      map['initial_balance'] = Variable<double>(initialBalance);
    }
    if (!nullToAbsent || includeInTotal != null) {
      map['include_in_total'] = Variable<int>(includeInTotal);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || billingDay != null) {
      map['billing_day'] = Variable<int>(billingDay);
    }
    if (!nullToAbsent || repaymentDay != null) {
      map['repayment_day'] = Variable<int>(repaymentDay);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  AccountTableCompanion toCompanion(bool nullToAbsent) {
    return AccountTableCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      initialBalance: initialBalance == null && nullToAbsent
          ? const Value.absent()
          : Value(initialBalance),
      includeInTotal: includeInTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(includeInTotal),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      billingDay: billingDay == null && nullToAbsent
          ? const Value.absent()
          : Value(billingDay),
      repaymentDay: repaymentDay == null && nullToAbsent
          ? const Value.absent()
          : Value(repaymentDay),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory AccountEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      initialBalance: serializer.fromJson<double?>(json['initialBalance']),
      includeInTotal: serializer.fromJson<int?>(json['includeInTotal']),
      currency: serializer.fromJson<String?>(json['currency']),
      billingDay: serializer.fromJson<int?>(json['billingDay']),
      repaymentDay: serializer.fromJson<int?>(json['repaymentDay']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'initialBalance': serializer.toJson<double?>(initialBalance),
      'includeInTotal': serializer.toJson<int?>(includeInTotal),
      'currency': serializer.toJson<String?>(currency),
      'billingDay': serializer.toJson<int?>(billingDay),
      'repaymentDay': serializer.toJson<int?>(repaymentDay),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  AccountEntry copyWith({
    String? id,
    String? name,
    String? type,
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<double?> initialBalance = const Value.absent(),
    Value<int?> includeInTotal = const Value.absent(),
    Value<String?> currency = const Value.absent(),
    Value<int?> billingDay = const Value.absent(),
    Value<int?> repaymentDay = const Value.absent(),
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => AccountEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    initialBalance: initialBalance.present
        ? initialBalance.value
        : this.initialBalance,
    includeInTotal: includeInTotal.present
        ? includeInTotal.value
        : this.includeInTotal,
    currency: currency.present ? currency.value : this.currency,
    billingDay: billingDay.present ? billingDay.value : this.billingDay,
    repaymentDay: repaymentDay.present ? repaymentDay.value : this.repaymentDay,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  AccountEntry copyWithCompanion(AccountTableCompanion data) {
    return AccountEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      initialBalance: data.initialBalance.present
          ? data.initialBalance.value
          : this.initialBalance,
      includeInTotal: data.includeInTotal.present
          ? data.includeInTotal.value
          : this.includeInTotal,
      currency: data.currency.present ? data.currency.value : this.currency,
      billingDay: data.billingDay.present
          ? data.billingDay.value
          : this.billingDay,
      repaymentDay: data.repaymentDay.present
          ? data.repaymentDay.value
          : this.repaymentDay,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('includeInTotal: $includeInTotal, ')
          ..write('currency: $currency, ')
          ..write('billingDay: $billingDay, ')
          ..write('repaymentDay: $repaymentDay, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    icon,
    color,
    initialBalance,
    includeInTotal,
    currency,
    billingDay,
    repaymentDay,
    updatedAt,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.initialBalance == this.initialBalance &&
          other.includeInTotal == this.includeInTotal &&
          other.currency == this.currency &&
          other.billingDay == this.billingDay &&
          other.repaymentDay == this.repaymentDay &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class AccountTableCompanion extends UpdateCompanion<AccountEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<double?> initialBalance;
  final Value<int?> includeInTotal;
  final Value<String?> currency;
  final Value<int?> billingDay;
  final Value<int?> repaymentDay;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const AccountTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.includeInTotal = const Value.absent(),
    this.currency = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.repaymentDay = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountTableCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.includeInTotal = const Value.absent(),
    this.currency = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.repaymentDay = const Value.absent(),
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<AccountEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<double>? initialBalance,
    Expression<int>? includeInTotal,
    Expression<String>? currency,
    Expression<int>? billingDay,
    Expression<int>? repaymentDay,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (includeInTotal != null) 'include_in_total': includeInTotal,
      if (currency != null) 'currency': currency,
      if (billingDay != null) 'billing_day': billingDay,
      if (repaymentDay != null) 'repayment_day': repaymentDay,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? icon,
    Value<String?>? color,
    Value<double?>? initialBalance,
    Value<int?>? includeInTotal,
    Value<String?>? currency,
    Value<int?>? billingDay,
    Value<int?>? repaymentDay,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return AccountTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      initialBalance: initialBalance ?? this.initialBalance,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      currency: currency ?? this.currency,
      billingDay: billingDay ?? this.billingDay,
      repaymentDay: repaymentDay ?? this.repaymentDay,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
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
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (initialBalance.present) {
      map['initial_balance'] = Variable<double>(initialBalance.value);
    }
    if (includeInTotal.present) {
      map['include_in_total'] = Variable<int>(includeInTotal.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (repaymentDay.present) {
      map['repayment_day'] = Variable<int>(repaymentDay.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('includeInTotal: $includeInTotal, ')
          ..write('currency: $currency, ')
          ..write('billingDay: $billingDay, ')
          ..write('repaymentDay: $repaymentDay, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionEntryTableTable extends TransactionEntryTable
    with TableInfo<$TransactionEntryTableTable, TransactionEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionEntryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ledger (id)',
    ),
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
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fxRateMeta = const VerificationMeta('fxRate');
  @override
  late final GeneratedColumn<double> fxRate = GeneratedColumn<double>(
    'fx_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteEncryptedMeta = const VerificationMeta(
    'noteEncrypted',
  );
  @override
  late final GeneratedColumn<Uint8List> noteEncrypted =
      GeneratedColumn<Uint8List>(
        'note_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attachmentsEncryptedMeta =
      const VerificationMeta('attachmentsEncrypted');
  @override
  late final GeneratedColumn<Uint8List> attachmentsEncrypted =
      GeneratedColumn<Uint8List>(
        'attachments_encrypted',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ledgerId,
    type,
    amount,
    currency,
    fxRate,
    categoryId,
    accountId,
    toAccountId,
    occurredAt,
    noteEncrypted,
    attachmentsEncrypted,
    tags,
    contentHash,
    updatedAt,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_entry';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('fx_rate')) {
      context.handle(
        _fxRateMeta,
        fxRate.isAcceptableOrUnknown(data['fx_rate']!, _fxRateMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('note_encrypted')) {
      context.handle(
        _noteEncryptedMeta,
        noteEncrypted.isAcceptableOrUnknown(
          data['note_encrypted']!,
          _noteEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('attachments_encrypted')) {
      context.handle(
        _attachmentsEncryptedMeta,
        attachmentsEncrypted.isAcceptableOrUnknown(
          data['attachments_encrypted']!,
          _attachmentsEncryptedMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      fxRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fx_rate'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      noteEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}note_encrypted'],
      ),
      attachmentsEncrypted: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}attachments_encrypted'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $TransactionEntryTableTable createAlias(String alias) {
    return $TransactionEntryTableTable(attachedDatabase, alias);
  }
}

class TransactionEntryRow extends DataClass
    implements Insertable<TransactionEntryRow> {
  final String id;
  final String ledgerId;
  final String type;
  final double amount;
  final String currency;
  final double? fxRate;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId;
  final int occurredAt;
  final Uint8List? noteEncrypted;
  final Uint8List? attachmentsEncrypted;
  final String? tags;
  final String? contentHash;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  const TransactionEntryRow({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.amount,
    required this.currency,
    this.fxRate,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    required this.occurredAt,
    this.noteEncrypted,
    this.attachmentsEncrypted,
    this.tags,
    this.contentHash,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ledger_id'] = Variable<String>(ledgerId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || fxRate != null) {
      map['fx_rate'] = Variable<double>(fxRate);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    map['occurred_at'] = Variable<int>(occurredAt);
    if (!nullToAbsent || noteEncrypted != null) {
      map['note_encrypted'] = Variable<Uint8List>(noteEncrypted);
    }
    if (!nullToAbsent || attachmentsEncrypted != null) {
      map['attachments_encrypted'] = Variable<Uint8List>(attachmentsEncrypted);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  TransactionEntryTableCompanion toCompanion(bool nullToAbsent) {
    return TransactionEntryTableCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      type: Value(type),
      amount: Value(amount),
      currency: Value(currency),
      fxRate: fxRate == null && nullToAbsent
          ? const Value.absent()
          : Value(fxRate),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      occurredAt: Value(occurredAt),
      noteEncrypted: noteEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(noteEncrypted),
      attachmentsEncrypted: attachmentsEncrypted == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentsEncrypted),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory TransactionEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionEntryRow(
      id: serializer.fromJson<String>(json['id']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      fxRate: serializer.fromJson<double?>(json['fxRate']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      toAccountId: serializer.fromJson<String?>(json['toAccountId']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      noteEncrypted: serializer.fromJson<Uint8List?>(json['noteEncrypted']),
      attachmentsEncrypted: serializer.fromJson<Uint8List?>(
        json['attachmentsEncrypted'],
      ),
      tags: serializer.fromJson<String?>(json['tags']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'fxRate': serializer.toJson<double?>(fxRate),
      'categoryId': serializer.toJson<String?>(categoryId),
      'accountId': serializer.toJson<String?>(accountId),
      'toAccountId': serializer.toJson<String?>(toAccountId),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'noteEncrypted': serializer.toJson<Uint8List?>(noteEncrypted),
      'attachmentsEncrypted': serializer.toJson<Uint8List?>(
        attachmentsEncrypted,
      ),
      'tags': serializer.toJson<String?>(tags),
      'contentHash': serializer.toJson<String?>(contentHash),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  TransactionEntryRow copyWith({
    String? id,
    String? ledgerId,
    String? type,
    double? amount,
    String? currency,
    Value<double?> fxRate = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> accountId = const Value.absent(),
    Value<String?> toAccountId = const Value.absent(),
    int? occurredAt,
    Value<Uint8List?> noteEncrypted = const Value.absent(),
    Value<Uint8List?> attachmentsEncrypted = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => TransactionEntryRow(
    id: id ?? this.id,
    ledgerId: ledgerId ?? this.ledgerId,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    fxRate: fxRate.present ? fxRate.value : this.fxRate,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    accountId: accountId.present ? accountId.value : this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    occurredAt: occurredAt ?? this.occurredAt,
    noteEncrypted: noteEncrypted.present
        ? noteEncrypted.value
        : this.noteEncrypted,
    attachmentsEncrypted: attachmentsEncrypted.present
        ? attachmentsEncrypted.value
        : this.attachmentsEncrypted,
    tags: tags.present ? tags.value : this.tags,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  TransactionEntryRow copyWithCompanion(TransactionEntryTableCompanion data) {
    return TransactionEntryRow(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      fxRate: data.fxRate.present ? data.fxRate.value : this.fxRate,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      noteEncrypted: data.noteEncrypted.present
          ? data.noteEncrypted.value
          : this.noteEncrypted,
      attachmentsEncrypted: data.attachmentsEncrypted.present
          ? data.attachmentsEncrypted.value
          : this.attachmentsEncrypted,
      tags: data.tags.present ? data.tags.value : this.tags,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionEntryRow(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('fxRate: $fxRate, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('noteEncrypted: $noteEncrypted, ')
          ..write('attachmentsEncrypted: $attachmentsEncrypted, ')
          ..write('tags: $tags, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ledgerId,
    type,
    amount,
    currency,
    fxRate,
    categoryId,
    accountId,
    toAccountId,
    occurredAt,
    $driftBlobEquality.hash(noteEncrypted),
    $driftBlobEquality.hash(attachmentsEncrypted),
    tags,
    contentHash,
    updatedAt,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionEntryRow &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.fxRate == this.fxRate &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.occurredAt == this.occurredAt &&
          $driftBlobEquality.equals(other.noteEncrypted, this.noteEncrypted) &&
          $driftBlobEquality.equals(
            other.attachmentsEncrypted,
            this.attachmentsEncrypted,
          ) &&
          other.tags == this.tags &&
          other.contentHash == this.contentHash &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class TransactionEntryTableCompanion
    extends UpdateCompanion<TransactionEntryRow> {
  final Value<String> id;
  final Value<String> ledgerId;
  final Value<String> type;
  final Value<double> amount;
  final Value<String> currency;
  final Value<double?> fxRate;
  final Value<String?> categoryId;
  final Value<String?> accountId;
  final Value<String?> toAccountId;
  final Value<int> occurredAt;
  final Value<Uint8List?> noteEncrypted;
  final Value<Uint8List?> attachmentsEncrypted;
  final Value<String?> tags;
  final Value<String?> contentHash;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const TransactionEntryTableCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.fxRate = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.noteEncrypted = const Value.absent(),
    this.attachmentsEncrypted = const Value.absent(),
    this.tags = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionEntryTableCompanion.insert({
    required String id,
    required String ledgerId,
    required String type,
    required double amount,
    required String currency,
    this.fxRate = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    required int occurredAt,
    this.noteEncrypted = const Value.absent(),
    this.attachmentsEncrypted = const Value.absent(),
    this.tags = const Value.absent(),
    this.contentHash = const Value.absent(),
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ledgerId = Value(ledgerId),
       type = Value(type),
       amount = Value(amount),
       currency = Value(currency),
       occurredAt = Value(occurredAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<TransactionEntryRow> custom({
    Expression<String>? id,
    Expression<String>? ledgerId,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<double>? fxRate,
    Expression<String>? categoryId,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<int>? occurredAt,
    Expression<Uint8List>? noteEncrypted,
    Expression<Uint8List>? attachmentsEncrypted,
    Expression<String>? tags,
    Expression<String>? contentHash,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (fxRate != null) 'fx_rate': fxRate,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (noteEncrypted != null) 'note_encrypted': noteEncrypted,
      if (attachmentsEncrypted != null)
        'attachments_encrypted': attachmentsEncrypted,
      if (tags != null) 'tags': tags,
      if (contentHash != null) 'content_hash': contentHash,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionEntryTableCompanion copyWith({
    Value<String>? id,
    Value<String>? ledgerId,
    Value<String>? type,
    Value<double>? amount,
    Value<String>? currency,
    Value<double?>? fxRate,
    Value<String?>? categoryId,
    Value<String?>? accountId,
    Value<String?>? toAccountId,
    Value<int>? occurredAt,
    Value<Uint8List?>? noteEncrypted,
    Value<Uint8List?>? attachmentsEncrypted,
    Value<String?>? tags,
    Value<String?>? contentHash,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return TransactionEntryTableCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      fxRate: fxRate ?? this.fxRate,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      noteEncrypted: noteEncrypted ?? this.noteEncrypted,
      attachmentsEncrypted: attachmentsEncrypted ?? this.attachmentsEncrypted,
      tags: tags ?? this.tags,
      contentHash: contentHash ?? this.contentHash,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (fxRate.present) {
      map['fx_rate'] = Variable<double>(fxRate.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (noteEncrypted.present) {
      map['note_encrypted'] = Variable<Uint8List>(noteEncrypted.value);
    }
    if (attachmentsEncrypted.present) {
      map['attachments_encrypted'] = Variable<Uint8List>(
        attachmentsEncrypted.value,
      );
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionEntryTableCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('fxRate: $fxRate, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('noteEncrypted: $noteEncrypted, ')
          ..write('attachmentsEncrypted: $attachmentsEncrypted, ')
          ..write('tags: $tags, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetTableTable extends BudgetTable
    with TableInfo<$BudgetTableTable, BudgetEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
    'period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carryOverMeta = const VerificationMeta(
    'carryOver',
  );
  @override
  late final GeneratedColumn<int> carryOver = GeneratedColumn<int>(
    'carry_over',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _carryBalanceMeta = const VerificationMeta(
    'carryBalance',
  );
  @override
  late final GeneratedColumn<double> carryBalance = GeneratedColumn<double>(
    'carry_balance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSettledAtMeta = const VerificationMeta(
    'lastSettledAt',
  );
  @override
  late final GeneratedColumn<int> lastSettledAt = GeneratedColumn<int>(
    'last_settled_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<int> startDate = GeneratedColumn<int>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ledgerId,
    period,
    categoryId,
    amount,
    carryOver,
    carryBalance,
    lastSettledAt,
    startDate,
    updatedAt,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('period')) {
      context.handle(
        _periodMeta,
        period.isAcceptableOrUnknown(data['period']!, _periodMeta),
      );
    } else if (isInserting) {
      context.missing(_periodMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('carry_over')) {
      context.handle(
        _carryOverMeta,
        carryOver.isAcceptableOrUnknown(data['carry_over']!, _carryOverMeta),
      );
    }
    if (data.containsKey('carry_balance')) {
      context.handle(
        _carryBalanceMeta,
        carryBalance.isAcceptableOrUnknown(
          data['carry_balance']!,
          _carryBalanceMeta,
        ),
      );
    }
    if (data.containsKey('last_settled_at')) {
      context.handle(
        _lastSettledAtMeta,
        lastSettledAt.isAcceptableOrUnknown(
          data['last_settled_at']!,
          _lastSettledAtMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      period: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      carryOver: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carry_over'],
      ),
      carryBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carry_balance'],
      )!,
      lastSettledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_settled_at'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_date'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $BudgetTableTable createAlias(String alias) {
    return $BudgetTableTable(attachedDatabase, alias);
  }
}

class BudgetEntry extends DataClass implements Insertable<BudgetEntry> {
  final String id;
  final String ledgerId;
  final String period;
  final String? categoryId;
  final double amount;
  final int? carryOver;

  /// Step 6.4 引入的"已结转余额"。每次跨周期触发懒结算时，把上一周期未花完
  /// 的额度（`max(0, amount - spent)`）累加到这里；预算进度 UI 把它叠加到
  /// `amount` 上展示"本期可用"。
  final double carryBalance;

  /// Step 6.4 引入的"已结算到的周期 end（epoch ms）"。`null` 表示还从未结算过。
  /// 结算函数从这里向 `now` 推进，关闭→重新开启时由 `applyCarryOverToggle`
  /// 重置为当前周期开始，从而满足"重新打开不回溯历史"的约束。
  final int? lastSettledAt;
  final int startDate;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  const BudgetEntry({
    required this.id,
    required this.ledgerId,
    required this.period,
    this.categoryId,
    required this.amount,
    this.carryOver,
    required this.carryBalance,
    this.lastSettledAt,
    required this.startDate,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ledger_id'] = Variable<String>(ledgerId);
    map['period'] = Variable<String>(period);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || carryOver != null) {
      map['carry_over'] = Variable<int>(carryOver);
    }
    map['carry_balance'] = Variable<double>(carryBalance);
    if (!nullToAbsent || lastSettledAt != null) {
      map['last_settled_at'] = Variable<int>(lastSettledAt);
    }
    map['start_date'] = Variable<int>(startDate);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  BudgetTableCompanion toCompanion(bool nullToAbsent) {
    return BudgetTableCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      period: Value(period),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amount: Value(amount),
      carryOver: carryOver == null && nullToAbsent
          ? const Value.absent()
          : Value(carryOver),
      carryBalance: Value(carryBalance),
      lastSettledAt: lastSettledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSettledAt),
      startDate: Value(startDate),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory BudgetEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetEntry(
      id: serializer.fromJson<String>(json['id']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      period: serializer.fromJson<String>(json['period']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      carryOver: serializer.fromJson<int?>(json['carryOver']),
      carryBalance: serializer.fromJson<double>(json['carryBalance']),
      lastSettledAt: serializer.fromJson<int?>(json['lastSettledAt']),
      startDate: serializer.fromJson<int>(json['startDate']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'period': serializer.toJson<String>(period),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'carryOver': serializer.toJson<int?>(carryOver),
      'carryBalance': serializer.toJson<double>(carryBalance),
      'lastSettledAt': serializer.toJson<int?>(lastSettledAt),
      'startDate': serializer.toJson<int>(startDate),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  BudgetEntry copyWith({
    String? id,
    String? ledgerId,
    String? period,
    Value<String?> categoryId = const Value.absent(),
    double? amount,
    Value<int?> carryOver = const Value.absent(),
    double? carryBalance,
    Value<int?> lastSettledAt = const Value.absent(),
    int? startDate,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => BudgetEntry(
    id: id ?? this.id,
    ledgerId: ledgerId ?? this.ledgerId,
    period: period ?? this.period,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amount: amount ?? this.amount,
    carryOver: carryOver.present ? carryOver.value : this.carryOver,
    carryBalance: carryBalance ?? this.carryBalance,
    lastSettledAt: lastSettledAt.present
        ? lastSettledAt.value
        : this.lastSettledAt,
    startDate: startDate ?? this.startDate,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  BudgetEntry copyWithCompanion(BudgetTableCompanion data) {
    return BudgetEntry(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      period: data.period.present ? data.period.value : this.period,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      carryOver: data.carryOver.present ? data.carryOver.value : this.carryOver,
      carryBalance: data.carryBalance.present
          ? data.carryBalance.value
          : this.carryBalance,
      lastSettledAt: data.lastSettledAt.present
          ? data.lastSettledAt.value
          : this.lastSettledAt,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetEntry(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('period: $period, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('carryOver: $carryOver, ')
          ..write('carryBalance: $carryBalance, ')
          ..write('lastSettledAt: $lastSettledAt, ')
          ..write('startDate: $startDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ledgerId,
    period,
    categoryId,
    amount,
    carryOver,
    carryBalance,
    lastSettledAt,
    startDate,
    updatedAt,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetEntry &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.period == this.period &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.carryOver == this.carryOver &&
          other.carryBalance == this.carryBalance &&
          other.lastSettledAt == this.lastSettledAt &&
          other.startDate == this.startDate &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class BudgetTableCompanion extends UpdateCompanion<BudgetEntry> {
  final Value<String> id;
  final Value<String> ledgerId;
  final Value<String> period;
  final Value<String?> categoryId;
  final Value<double> amount;
  final Value<int?> carryOver;
  final Value<double> carryBalance;
  final Value<int?> lastSettledAt;
  final Value<int> startDate;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const BudgetTableCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.period = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.carryOver = const Value.absent(),
    this.carryBalance = const Value.absent(),
    this.lastSettledAt = const Value.absent(),
    this.startDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetTableCompanion.insert({
    required String id,
    required String ledgerId,
    required String period,
    this.categoryId = const Value.absent(),
    required double amount,
    this.carryOver = const Value.absent(),
    this.carryBalance = const Value.absent(),
    this.lastSettledAt = const Value.absent(),
    required int startDate,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ledgerId = Value(ledgerId),
       period = Value(period),
       amount = Value(amount),
       startDate = Value(startDate),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<BudgetEntry> custom({
    Expression<String>? id,
    Expression<String>? ledgerId,
    Expression<String>? period,
    Expression<String>? categoryId,
    Expression<double>? amount,
    Expression<int>? carryOver,
    Expression<double>? carryBalance,
    Expression<int>? lastSettledAt,
    Expression<int>? startDate,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (period != null) 'period': period,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (carryOver != null) 'carry_over': carryOver,
      if (carryBalance != null) 'carry_balance': carryBalance,
      if (lastSettledAt != null) 'last_settled_at': lastSettledAt,
      if (startDate != null) 'start_date': startDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetTableCompanion copyWith({
    Value<String>? id,
    Value<String>? ledgerId,
    Value<String>? period,
    Value<String?>? categoryId,
    Value<double>? amount,
    Value<int?>? carryOver,
    Value<double>? carryBalance,
    Value<int?>? lastSettledAt,
    Value<int>? startDate,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return BudgetTableCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      period: period ?? this.period,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      carryOver: carryOver ?? this.carryOver,
      carryBalance: carryBalance ?? this.carryBalance,
      lastSettledAt: lastSettledAt ?? this.lastSettledAt,
      startDate: startDate ?? this.startDate,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (carryOver.present) {
      map['carry_over'] = Variable<int>(carryOver.value);
    }
    if (carryBalance.present) {
      map['carry_balance'] = Variable<double>(carryBalance.value);
    }
    if (lastSettledAt.present) {
      map['last_settled_at'] = Variable<int>(lastSettledAt.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<int>(startDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetTableCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('period: $period, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('carryOver: $carryOver, ')
          ..write('carryBalance: $carryBalance, ')
          ..write('lastSettledAt: $lastSettledAt, ')
          ..write('startDate: $startDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOpTableTable extends SyncOpTable
    with TableInfo<$SyncOpTableTable, SyncOpEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOpTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enqueuedAtMeta = const VerificationMeta(
    'enqueuedAt',
  );
  @override
  late final GeneratedColumn<int> enqueuedAt = GeneratedColumn<int>(
    'enqueued_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triedMeta = const VerificationMeta('tried');
  @override
  late final GeneratedColumn<int> tried = GeneratedColumn<int>(
    'tried',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entity,
    entityId,
    op,
    payload,
    enqueuedAt,
    tried,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_op';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOpEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('enqueued_at')) {
      context.handle(
        _enqueuedAtMeta,
        enqueuedAt.isAcceptableOrUnknown(data['enqueued_at']!, _enqueuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enqueuedAtMeta);
    }
    if (data.containsKey('tried')) {
      context.handle(
        _triedMeta,
        tried.isAcceptableOrUnknown(data['tried']!, _triedMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOpEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOpEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      enqueuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enqueued_at'],
      )!,
      tried: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tried'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncOpTableTable createAlias(String alias) {
    return $SyncOpTableTable(attachedDatabase, alias);
  }
}

class SyncOpEntry extends DataClass implements Insertable<SyncOpEntry> {
  final int id;
  final String entity;
  final String entityId;
  final String op;
  final String payload;
  final int enqueuedAt;
  final int? tried;
  final String? lastError;
  const SyncOpEntry({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.enqueuedAt,
    this.tried,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['op'] = Variable<String>(op);
    map['payload'] = Variable<String>(payload);
    map['enqueued_at'] = Variable<int>(enqueuedAt);
    if (!nullToAbsent || tried != null) {
      map['tried'] = Variable<int>(tried);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncOpTableCompanion toCompanion(bool nullToAbsent) {
    return SyncOpTableCompanion(
      id: Value(id),
      entity: Value(entity),
      entityId: Value(entityId),
      op: Value(op),
      payload: Value(payload),
      enqueuedAt: Value(enqueuedAt),
      tried: tried == null && nullToAbsent
          ? const Value.absent()
          : Value(tried),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncOpEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOpEntry(
      id: serializer.fromJson<int>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      op: serializer.fromJson<String>(json['op']),
      payload: serializer.fromJson<String>(json['payload']),
      enqueuedAt: serializer.fromJson<int>(json['enqueuedAt']),
      tried: serializer.fromJson<int?>(json['tried']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'op': serializer.toJson<String>(op),
      'payload': serializer.toJson<String>(payload),
      'enqueuedAt': serializer.toJson<int>(enqueuedAt),
      'tried': serializer.toJson<int?>(tried),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncOpEntry copyWith({
    int? id,
    String? entity,
    String? entityId,
    String? op,
    String? payload,
    int? enqueuedAt,
    Value<int?> tried = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SyncOpEntry(
    id: id ?? this.id,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    op: op ?? this.op,
    payload: payload ?? this.payload,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    tried: tried.present ? tried.value : this.tried,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncOpEntry copyWithCompanion(SyncOpTableCompanion data) {
    return SyncOpEntry(
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      op: data.op.present ? data.op.value : this.op,
      payload: data.payload.present ? data.payload.value : this.payload,
      enqueuedAt: data.enqueuedAt.present
          ? data.enqueuedAt.value
          : this.enqueuedAt,
      tried: data.tried.present ? data.tried.value : this.tried,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOpEntry(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('tried: $tried, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    entityId,
    op,
    payload,
    enqueuedAt,
    tried,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOpEntry &&
          other.id == this.id &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.op == this.op &&
          other.payload == this.payload &&
          other.enqueuedAt == this.enqueuedAt &&
          other.tried == this.tried &&
          other.lastError == this.lastError);
}

class SyncOpTableCompanion extends UpdateCompanion<SyncOpEntry> {
  final Value<int> id;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> op;
  final Value<String> payload;
  final Value<int> enqueuedAt;
  final Value<int?> tried;
  final Value<String?> lastError;
  const SyncOpTableCompanion({
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.payload = const Value.absent(),
    this.enqueuedAt = const Value.absent(),
    this.tried = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  SyncOpTableCompanion.insert({
    this.id = const Value.absent(),
    required String entity,
    required String entityId,
    required String op,
    required String payload,
    required int enqueuedAt,
    this.tried = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : entity = Value(entity),
       entityId = Value(entityId),
       op = Value(op),
       payload = Value(payload),
       enqueuedAt = Value(enqueuedAt);
  static Insertable<SyncOpEntry> custom({
    Expression<int>? id,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? op,
    Expression<String>? payload,
    Expression<int>? enqueuedAt,
    Expression<int>? tried,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (op != null) 'op': op,
      if (payload != null) 'payload': payload,
      if (enqueuedAt != null) 'enqueued_at': enqueuedAt,
      if (tried != null) 'tried': tried,
      if (lastError != null) 'last_error': lastError,
    });
  }

  SyncOpTableCompanion copyWith({
    Value<int>? id,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? op,
    Value<String>? payload,
    Value<int>? enqueuedAt,
    Value<int?>? tried,
    Value<String?>? lastError,
  }) {
    return SyncOpTableCompanion(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      payload: payload ?? this.payload,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      tried: tried ?? this.tried,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (enqueuedAt.present) {
      map['enqueued_at'] = Variable<int>(enqueuedAt.value);
    }
    if (tried.present) {
      map['tried'] = Variable<int>(tried.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOpTableCompanion(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('tried: $tried, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $FxRateTableTable extends FxRateTable
    with TableInfo<$FxRateTableTable, FxRateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FxRateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateToCnyMeta = const VerificationMeta(
    'rateToCny',
  );
  @override
  late final GeneratedColumn<double> rateToCny = GeneratedColumn<double>(
    'rate_to_cny',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isManualMeta = const VerificationMeta(
    'isManual',
  );
  @override
  late final GeneratedColumn<int> isManual = GeneratedColumn<int>(
    'is_manual',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [code, rateToCny, updatedAt, isManual];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fx_rate';
  @override
  VerificationContext validateIntegrity(
    Insertable<FxRateEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('rate_to_cny')) {
      context.handle(
        _rateToCnyMeta,
        rateToCny.isAcceptableOrUnknown(data['rate_to_cny']!, _rateToCnyMeta),
      );
    } else if (isInserting) {
      context.missing(_rateToCnyMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_manual')) {
      context.handle(
        _isManualMeta,
        isManual.isAcceptableOrUnknown(data['is_manual']!, _isManualMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  FxRateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FxRateEntry(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      rateToCny: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rate_to_cny'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      isManual: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_manual'],
      )!,
    );
  }

  @override
  $FxRateTableTable createAlias(String alias) {
    return $FxRateTableTable(attachedDatabase, alias);
  }
}

class FxRateEntry extends DataClass implements Insertable<FxRateEntry> {
  final String code;
  final double rateToCny;
  final int updatedAt;
  final int isManual;
  const FxRateEntry({
    required this.code,
    required this.rateToCny,
    required this.updatedAt,
    required this.isManual,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['rate_to_cny'] = Variable<double>(rateToCny);
    map['updated_at'] = Variable<int>(updatedAt);
    map['is_manual'] = Variable<int>(isManual);
    return map;
  }

  FxRateTableCompanion toCompanion(bool nullToAbsent) {
    return FxRateTableCompanion(
      code: Value(code),
      rateToCny: Value(rateToCny),
      updatedAt: Value(updatedAt),
      isManual: Value(isManual),
    );
  }

  factory FxRateEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FxRateEntry(
      code: serializer.fromJson<String>(json['code']),
      rateToCny: serializer.fromJson<double>(json['rateToCny']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      isManual: serializer.fromJson<int>(json['isManual']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'rateToCny': serializer.toJson<double>(rateToCny),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'isManual': serializer.toJson<int>(isManual),
    };
  }

  FxRateEntry copyWith({
    String? code,
    double? rateToCny,
    int? updatedAt,
    int? isManual,
  }) => FxRateEntry(
    code: code ?? this.code,
    rateToCny: rateToCny ?? this.rateToCny,
    updatedAt: updatedAt ?? this.updatedAt,
    isManual: isManual ?? this.isManual,
  );
  FxRateEntry copyWithCompanion(FxRateTableCompanion data) {
    return FxRateEntry(
      code: data.code.present ? data.code.value : this.code,
      rateToCny: data.rateToCny.present ? data.rateToCny.value : this.rateToCny,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isManual: data.isManual.present ? data.isManual.value : this.isManual,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FxRateEntry(')
          ..write('code: $code, ')
          ..write('rateToCny: $rateToCny, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isManual: $isManual')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, rateToCny, updatedAt, isManual);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FxRateEntry &&
          other.code == this.code &&
          other.rateToCny == this.rateToCny &&
          other.updatedAt == this.updatedAt &&
          other.isManual == this.isManual);
}

class FxRateTableCompanion extends UpdateCompanion<FxRateEntry> {
  final Value<String> code;
  final Value<double> rateToCny;
  final Value<int> updatedAt;
  final Value<int> isManual;
  final Value<int> rowid;
  const FxRateTableCompanion({
    this.code = const Value.absent(),
    this.rateToCny = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isManual = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FxRateTableCompanion.insert({
    required String code,
    required double rateToCny,
    required int updatedAt,
    this.isManual = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       rateToCny = Value(rateToCny),
       updatedAt = Value(updatedAt);
  static Insertable<FxRateEntry> custom({
    Expression<String>? code,
    Expression<double>? rateToCny,
    Expression<int>? updatedAt,
    Expression<int>? isManual,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (rateToCny != null) 'rate_to_cny': rateToCny,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isManual != null) 'is_manual': isManual,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FxRateTableCompanion copyWith({
    Value<String>? code,
    Value<double>? rateToCny,
    Value<int>? updatedAt,
    Value<int>? isManual,
    Value<int>? rowid,
  }) {
    return FxRateTableCompanion(
      code: code ?? this.code,
      rateToCny: rateToCny ?? this.rateToCny,
      updatedAt: updatedAt ?? this.updatedAt,
      isManual: isManual ?? this.isManual,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (rateToCny.present) {
      map['rate_to_cny'] = Variable<double>(rateToCny.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (isManual.present) {
      map['is_manual'] = Variable<int>(isManual.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FxRateTableCompanion(')
          ..write('code: $code, ')
          ..write('rateToCny: $rateToCny, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isManual: $isManual, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserPrefTableTable userPrefTable = $UserPrefTableTable(this);
  late final $LedgerTableTable ledgerTable = $LedgerTableTable(this);
  late final $CategoryTableTable categoryTable = $CategoryTableTable(this);
  late final $AccountTableTable accountTable = $AccountTableTable(this);
  late final $TransactionEntryTableTable transactionEntryTable =
      $TransactionEntryTableTable(this);
  late final $BudgetTableTable budgetTable = $BudgetTableTable(this);
  late final $SyncOpTableTable syncOpTable = $SyncOpTableTable(this);
  late final $FxRateTableTable fxRateTable = $FxRateTableTable(this);
  late final LedgerDao ledgerDao = LedgerDao(this as AppDatabase);
  late final CategoryDao categoryDao = CategoryDao(this as AppDatabase);
  late final AccountDao accountDao = AccountDao(this as AppDatabase);
  late final TransactionEntryDao transactionEntryDao = TransactionEntryDao(
    this as AppDatabase,
  );
  late final BudgetDao budgetDao = BudgetDao(this as AppDatabase);
  late final SyncOpDao syncOpDao = SyncOpDao(this as AppDatabase);
  late final FxRateDao fxRateDao = FxRateDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userPrefTable,
    ledgerTable,
    categoryTable,
    accountTable,
    transactionEntryTable,
    budgetTable,
    syncOpTable,
    fxRateTable,
  ];
}

typedef $$UserPrefTableTableCreateCompanionBuilder =
    UserPrefTableCompanion Function({
      Value<int> id,
      required String deviceId,
      Value<String?> currentLedgerId,
      Value<String?> defaultCurrency,
      Value<String?> theme,
      Value<int?> lockEnabled,
      Value<int?> syncEnabled,
      Value<int?> multiCurrencyEnabled,
      Value<int?> lastSyncAt,
      Value<int?> lastFxRefreshAt,
      Value<String?> aiApiEndpoint,
      Value<Uint8List?> aiApiKeyEncrypted,
      Value<String?> aiApiModel,
      Value<String?> aiApiPromptTemplate,
      Value<int?> aiInputEnabled,
      Value<String?> fontSize,
      Value<String?> iconPack,
      Value<int?> reminderEnabled,
      Value<String?> reminderTime,
    });
typedef $$UserPrefTableTableUpdateCompanionBuilder =
    UserPrefTableCompanion Function({
      Value<int> id,
      Value<String> deviceId,
      Value<String?> currentLedgerId,
      Value<String?> defaultCurrency,
      Value<String?> theme,
      Value<int?> lockEnabled,
      Value<int?> syncEnabled,
      Value<int?> multiCurrencyEnabled,
      Value<int?> lastSyncAt,
      Value<int?> lastFxRefreshAt,
      Value<String?> aiApiEndpoint,
      Value<Uint8List?> aiApiKeyEncrypted,
      Value<String?> aiApiModel,
      Value<String?> aiApiPromptTemplate,
      Value<int?> aiInputEnabled,
      Value<String?> fontSize,
      Value<String?> iconPack,
      Value<int?> reminderEnabled,
      Value<String?> reminderTime,
    });

class $$UserPrefTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserPrefTableTable> {
  $$UserPrefTableTableFilterComposer({
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

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentLedgerId => $composableBuilder(
    column: $table.currentLedgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultCurrency => $composableBuilder(
    column: $table.defaultCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get multiCurrencyEnabled => $composableBuilder(
    column: $table.multiCurrencyEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFxRefreshAt => $composableBuilder(
    column: $table.lastFxRefreshAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiApiEndpoint => $composableBuilder(
    column: $table.aiApiEndpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get aiApiKeyEncrypted => $composableBuilder(
    column: $table.aiApiKeyEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiApiModel => $composableBuilder(
    column: $table.aiApiModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiApiPromptTemplate => $composableBuilder(
    column: $table.aiApiPromptTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aiInputEnabled => $composableBuilder(
    column: $table.aiInputEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fontSize => $composableBuilder(
    column: $table.fontSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconPack => $composableBuilder(
    column: $table.iconPack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPrefTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPrefTableTable> {
  $$UserPrefTableTableOrderingComposer({
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentLedgerId => $composableBuilder(
    column: $table.currentLedgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultCurrency => $composableBuilder(
    column: $table.defaultCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get multiCurrencyEnabled => $composableBuilder(
    column: $table.multiCurrencyEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFxRefreshAt => $composableBuilder(
    column: $table.lastFxRefreshAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiApiEndpoint => $composableBuilder(
    column: $table.aiApiEndpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get aiApiKeyEncrypted => $composableBuilder(
    column: $table.aiApiKeyEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiApiModel => $composableBuilder(
    column: $table.aiApiModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiApiPromptTemplate => $composableBuilder(
    column: $table.aiApiPromptTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aiInputEnabled => $composableBuilder(
    column: $table.aiInputEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fontSize => $composableBuilder(
    column: $table.fontSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconPack => $composableBuilder(
    column: $table.iconPack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPrefTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPrefTableTable> {
  $$UserPrefTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get currentLedgerId => $composableBuilder(
    column: $table.currentLedgerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultCurrency => $composableBuilder(
    column: $table.defaultCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<int> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncEnabled => $composableBuilder(
    column: $table.syncEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get multiCurrencyEnabled => $composableBuilder(
    column: $table.multiCurrencyEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastFxRefreshAt => $composableBuilder(
    column: $table.lastFxRefreshAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiApiEndpoint => $composableBuilder(
    column: $table.aiApiEndpoint,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get aiApiKeyEncrypted => $composableBuilder(
    column: $table.aiApiKeyEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiApiModel => $composableBuilder(
    column: $table.aiApiModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiApiPromptTemplate => $composableBuilder(
    column: $table.aiApiPromptTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get aiInputEnabled => $composableBuilder(
    column: $table.aiInputEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fontSize =>
      $composableBuilder(column: $table.fontSize, builder: (column) => column);

  GeneratedColumn<String> get iconPack =>
      $composableBuilder(column: $table.iconPack, builder: (column) => column);

  GeneratedColumn<int> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => column,
  );
}

class $$UserPrefTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPrefTableTable,
          UserPrefEntry,
          $$UserPrefTableTableFilterComposer,
          $$UserPrefTableTableOrderingComposer,
          $$UserPrefTableTableAnnotationComposer,
          $$UserPrefTableTableCreateCompanionBuilder,
          $$UserPrefTableTableUpdateCompanionBuilder,
          (
            UserPrefEntry,
            BaseReferences<_$AppDatabase, $UserPrefTableTable, UserPrefEntry>,
          ),
          UserPrefEntry,
          PrefetchHooks Function()
        > {
  $$UserPrefTableTableTableManager(_$AppDatabase db, $UserPrefTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPrefTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPrefTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPrefTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String?> currentLedgerId = const Value.absent(),
                Value<String?> defaultCurrency = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<int?> lockEnabled = const Value.absent(),
                Value<int?> syncEnabled = const Value.absent(),
                Value<int?> multiCurrencyEnabled = const Value.absent(),
                Value<int?> lastSyncAt = const Value.absent(),
                Value<int?> lastFxRefreshAt = const Value.absent(),
                Value<String?> aiApiEndpoint = const Value.absent(),
                Value<Uint8List?> aiApiKeyEncrypted = const Value.absent(),
                Value<String?> aiApiModel = const Value.absent(),
                Value<String?> aiApiPromptTemplate = const Value.absent(),
                Value<int?> aiInputEnabled = const Value.absent(),
                Value<String?> fontSize = const Value.absent(),
                Value<String?> iconPack = const Value.absent(),
                Value<int?> reminderEnabled = const Value.absent(),
                Value<String?> reminderTime = const Value.absent(),
              }) => UserPrefTableCompanion(
                id: id,
                deviceId: deviceId,
                currentLedgerId: currentLedgerId,
                defaultCurrency: defaultCurrency,
                theme: theme,
                lockEnabled: lockEnabled,
                syncEnabled: syncEnabled,
                multiCurrencyEnabled: multiCurrencyEnabled,
                lastSyncAt: lastSyncAt,
                lastFxRefreshAt: lastFxRefreshAt,
                aiApiEndpoint: aiApiEndpoint,
                aiApiKeyEncrypted: aiApiKeyEncrypted,
                aiApiModel: aiApiModel,
                aiApiPromptTemplate: aiApiPromptTemplate,
                aiInputEnabled: aiInputEnabled,
                fontSize: fontSize,
                iconPack: iconPack,
                reminderEnabled: reminderEnabled,
                reminderTime: reminderTime,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceId,
                Value<String?> currentLedgerId = const Value.absent(),
                Value<String?> defaultCurrency = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<int?> lockEnabled = const Value.absent(),
                Value<int?> syncEnabled = const Value.absent(),
                Value<int?> multiCurrencyEnabled = const Value.absent(),
                Value<int?> lastSyncAt = const Value.absent(),
                Value<int?> lastFxRefreshAt = const Value.absent(),
                Value<String?> aiApiEndpoint = const Value.absent(),
                Value<Uint8List?> aiApiKeyEncrypted = const Value.absent(),
                Value<String?> aiApiModel = const Value.absent(),
                Value<String?> aiApiPromptTemplate = const Value.absent(),
                Value<int?> aiInputEnabled = const Value.absent(),
                Value<String?> fontSize = const Value.absent(),
                Value<String?> iconPack = const Value.absent(),
                Value<int?> reminderEnabled = const Value.absent(),
                Value<String?> reminderTime = const Value.absent(),
              }) => UserPrefTableCompanion.insert(
                id: id,
                deviceId: deviceId,
                currentLedgerId: currentLedgerId,
                defaultCurrency: defaultCurrency,
                theme: theme,
                lockEnabled: lockEnabled,
                syncEnabled: syncEnabled,
                multiCurrencyEnabled: multiCurrencyEnabled,
                lastSyncAt: lastSyncAt,
                lastFxRefreshAt: lastFxRefreshAt,
                aiApiEndpoint: aiApiEndpoint,
                aiApiKeyEncrypted: aiApiKeyEncrypted,
                aiApiModel: aiApiModel,
                aiApiPromptTemplate: aiApiPromptTemplate,
                aiInputEnabled: aiInputEnabled,
                fontSize: fontSize,
                iconPack: iconPack,
                reminderEnabled: reminderEnabled,
                reminderTime: reminderTime,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPrefTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPrefTableTable,
      UserPrefEntry,
      $$UserPrefTableTableFilterComposer,
      $$UserPrefTableTableOrderingComposer,
      $$UserPrefTableTableAnnotationComposer,
      $$UserPrefTableTableCreateCompanionBuilder,
      $$UserPrefTableTableUpdateCompanionBuilder,
      (
        UserPrefEntry,
        BaseReferences<_$AppDatabase, $UserPrefTableTable, UserPrefEntry>,
      ),
      UserPrefEntry,
      PrefetchHooks Function()
    >;
typedef $$LedgerTableTableCreateCompanionBuilder =
    LedgerTableCompanion Function({
      required String id,
      required String name,
      Value<String?> coverEmoji,
      Value<String?> defaultCurrency,
      Value<int?> archived,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$LedgerTableTableUpdateCompanionBuilder =
    LedgerTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> coverEmoji,
      Value<String?> defaultCurrency,
      Value<int?> archived,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

final class $$LedgerTableTableReferences
    extends BaseReferences<_$AppDatabase, $LedgerTableTable, LedgerEntry> {
  $$LedgerTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $TransactionEntryTableTable,
    List<TransactionEntryRow>
  >
  _transactionEntryTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactionEntryTable,
        aliasName: $_aliasNameGenerator(
          db.ledgerTable.id,
          db.transactionEntryTable.ledgerId,
        ),
      );

  $$TransactionEntryTableTableProcessedTableManager
  get transactionEntryTableRefs {
    final manager = $$TransactionEntryTableTableTableManager(
      $_db,
      $_db.transactionEntryTable,
    ).filter((f) => f.ledgerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionEntryTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LedgerTableTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerTableTable> {
  $$LedgerTableTableFilterComposer({
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

  ColumnFilters<String> get coverEmoji => $composableBuilder(
    column: $table.coverEmoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultCurrency => $composableBuilder(
    column: $table.defaultCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionEntryTableRefs(
    Expression<bool> Function($$TransactionEntryTableTableFilterComposer f) f,
  ) {
    final $$TransactionEntryTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionEntryTable,
          getReferencedColumn: (t) => t.ledgerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntryTableTableFilterComposer(
                $db: $db,
                $table: $db.transactionEntryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LedgerTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerTableTable> {
  $$LedgerTableTableOrderingComposer({
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

  ColumnOrderings<String> get coverEmoji => $composableBuilder(
    column: $table.coverEmoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultCurrency => $composableBuilder(
    column: $table.defaultCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerTableTable> {
  $$LedgerTableTableAnnotationComposer({
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

  GeneratedColumn<String> get coverEmoji => $composableBuilder(
    column: $table.coverEmoji,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultCurrency => $composableBuilder(
    column: $table.defaultCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  Expression<T> transactionEntryTableRefs<T extends Object>(
    Expression<T> Function($$TransactionEntryTableTableAnnotationComposer a) f,
  ) {
    final $$TransactionEntryTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionEntryTable,
          getReferencedColumn: (t) => t.ledgerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntryTableTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LedgerTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerTableTable,
          LedgerEntry,
          $$LedgerTableTableFilterComposer,
          $$LedgerTableTableOrderingComposer,
          $$LedgerTableTableAnnotationComposer,
          $$LedgerTableTableCreateCompanionBuilder,
          $$LedgerTableTableUpdateCompanionBuilder,
          (LedgerEntry, $$LedgerTableTableReferences),
          LedgerEntry,
          PrefetchHooks Function({bool transactionEntryTableRefs})
        > {
  $$LedgerTableTableTableManager(_$AppDatabase db, $LedgerTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> coverEmoji = const Value.absent(),
                Value<String?> defaultCurrency = const Value.absent(),
                Value<int?> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerTableCompanion(
                id: id,
                name: name,
                coverEmoji: coverEmoji,
                defaultCurrency: defaultCurrency,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> coverEmoji = const Value.absent(),
                Value<String?> defaultCurrency = const Value.absent(),
                Value<int?> archived = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => LedgerTableCompanion.insert(
                id: id,
                name: name,
                coverEmoji: coverEmoji,
                defaultCurrency: defaultCurrency,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LedgerTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionEntryTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (transactionEntryTableRefs) db.transactionEntryTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionEntryTableRefs)
                    await $_getPrefetchedData<
                      LedgerEntry,
                      $LedgerTableTable,
                      TransactionEntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$LedgerTableTableReferences
                          ._transactionEntryTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LedgerTableTableReferences(
                            db,
                            table,
                            p0,
                          ).transactionEntryTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.ledgerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LedgerTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerTableTable,
      LedgerEntry,
      $$LedgerTableTableFilterComposer,
      $$LedgerTableTableOrderingComposer,
      $$LedgerTableTableAnnotationComposer,
      $$LedgerTableTableCreateCompanionBuilder,
      $$LedgerTableTableUpdateCompanionBuilder,
      (LedgerEntry, $$LedgerTableTableReferences),
      LedgerEntry,
      PrefetchHooks Function({bool transactionEntryTableRefs})
    >;
typedef $$CategoryTableTableCreateCompanionBuilder =
    CategoryTableCompanion Function({
      required String id,
      required String name,
      Value<String?> icon,
      Value<String?> color,
      required String parentKey,
      Value<int> sortOrder,
      Value<int> isFavorite,
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$CategoryTableTableUpdateCompanionBuilder =
    CategoryTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> icon,
      Value<String?> color,
      Value<String> parentKey,
      Value<int> sortOrder,
      Value<int> isFavorite,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$CategoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryTableTable> {
  $$CategoryTableTableFilterComposer({
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

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentKey => $composableBuilder(
    column: $table.parentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryTableTable> {
  $$CategoryTableTableOrderingComposer({
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

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentKey => $composableBuilder(
    column: $table.parentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryTableTable> {
  $$CategoryTableTableAnnotationComposer({
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

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get parentKey =>
      $composableBuilder(column: $table.parentKey, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$CategoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryTableTable,
          CategoryEntry,
          $$CategoryTableTableFilterComposer,
          $$CategoryTableTableOrderingComposer,
          $$CategoryTableTableAnnotationComposer,
          $$CategoryTableTableCreateCompanionBuilder,
          $$CategoryTableTableUpdateCompanionBuilder,
          (
            CategoryEntry,
            BaseReferences<_$AppDatabase, $CategoryTableTable, CategoryEntry>,
          ),
          CategoryEntry,
          PrefetchHooks Function()
        > {
  $$CategoryTableTableTableManager(_$AppDatabase db, $CategoryTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String> parentKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> isFavorite = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryTableCompanion(
                id: id,
                name: name,
                icon: icon,
                color: color,
                parentKey: parentKey,
                sortOrder: sortOrder,
                isFavorite: isFavorite,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                required String parentKey,
                Value<int> sortOrder = const Value.absent(),
                Value<int> isFavorite = const Value.absent(),
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => CategoryTableCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                color: color,
                parentKey: parentKey,
                sortOrder: sortOrder,
                isFavorite: isFavorite,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryTableTable,
      CategoryEntry,
      $$CategoryTableTableFilterComposer,
      $$CategoryTableTableOrderingComposer,
      $$CategoryTableTableAnnotationComposer,
      $$CategoryTableTableCreateCompanionBuilder,
      $$CategoryTableTableUpdateCompanionBuilder,
      (
        CategoryEntry,
        BaseReferences<_$AppDatabase, $CategoryTableTable, CategoryEntry>,
      ),
      CategoryEntry,
      PrefetchHooks Function()
    >;
typedef $$AccountTableTableCreateCompanionBuilder =
    AccountTableCompanion Function({
      required String id,
      required String name,
      required String type,
      Value<String?> icon,
      Value<String?> color,
      Value<double?> initialBalance,
      Value<int?> includeInTotal,
      Value<String?> currency,
      Value<int?> billingDay,
      Value<int?> repaymentDay,
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$AccountTableTableUpdateCompanionBuilder =
    AccountTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String?> icon,
      Value<String?> color,
      Value<double?> initialBalance,
      Value<int?> includeInTotal,
      Value<String?> currency,
      Value<int?> billingDay,
      Value<int?> repaymentDay,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$AccountTableTableFilterComposer
    extends Composer<_$AppDatabase, $AccountTableTable> {
  $$AccountTableTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get initialBalance => $composableBuilder(
    column: $table.initialBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get includeInTotal => $composableBuilder(
    column: $table.includeInTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountTableTable> {
  $$AccountTableTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get initialBalance => $composableBuilder(
    column: $table.initialBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get includeInTotal => $composableBuilder(
    column: $table.includeInTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountTableTable> {
  $$AccountTableTableAnnotationComposer({
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

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get initialBalance => $composableBuilder(
    column: $table.initialBalance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get includeInTotal => $composableBuilder(
    column: $table.includeInTotal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$AccountTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountTableTable,
          AccountEntry,
          $$AccountTableTableFilterComposer,
          $$AccountTableTableOrderingComposer,
          $$AccountTableTableAnnotationComposer,
          $$AccountTableTableCreateCompanionBuilder,
          $$AccountTableTableUpdateCompanionBuilder,
          (
            AccountEntry,
            BaseReferences<_$AppDatabase, $AccountTableTable, AccountEntry>,
          ),
          AccountEntry,
          PrefetchHooks Function()
        > {
  $$AccountTableTableTableManager(_$AppDatabase db, $AccountTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<double?> initialBalance = const Value.absent(),
                Value<int?> includeInTotal = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<int?> billingDay = const Value.absent(),
                Value<int?> repaymentDay = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountTableCompanion(
                id: id,
                name: name,
                type: type,
                icon: icon,
                color: color,
                initialBalance: initialBalance,
                includeInTotal: includeInTotal,
                currency: currency,
                billingDay: billingDay,
                repaymentDay: repaymentDay,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<double?> initialBalance = const Value.absent(),
                Value<int?> includeInTotal = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<int?> billingDay = const Value.absent(),
                Value<int?> repaymentDay = const Value.absent(),
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => AccountTableCompanion.insert(
                id: id,
                name: name,
                type: type,
                icon: icon,
                color: color,
                initialBalance: initialBalance,
                includeInTotal: includeInTotal,
                currency: currency,
                billingDay: billingDay,
                repaymentDay: repaymentDay,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountTableTable,
      AccountEntry,
      $$AccountTableTableFilterComposer,
      $$AccountTableTableOrderingComposer,
      $$AccountTableTableAnnotationComposer,
      $$AccountTableTableCreateCompanionBuilder,
      $$AccountTableTableUpdateCompanionBuilder,
      (
        AccountEntry,
        BaseReferences<_$AppDatabase, $AccountTableTable, AccountEntry>,
      ),
      AccountEntry,
      PrefetchHooks Function()
    >;
typedef $$TransactionEntryTableTableCreateCompanionBuilder =
    TransactionEntryTableCompanion Function({
      required String id,
      required String ledgerId,
      required String type,
      required double amount,
      required String currency,
      Value<double?> fxRate,
      Value<String?> categoryId,
      Value<String?> accountId,
      Value<String?> toAccountId,
      required int occurredAt,
      Value<Uint8List?> noteEncrypted,
      Value<Uint8List?> attachmentsEncrypted,
      Value<String?> tags,
      Value<String?> contentHash,
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$TransactionEntryTableTableUpdateCompanionBuilder =
    TransactionEntryTableCompanion Function({
      Value<String> id,
      Value<String> ledgerId,
      Value<String> type,
      Value<double> amount,
      Value<String> currency,
      Value<double?> fxRate,
      Value<String?> categoryId,
      Value<String?> accountId,
      Value<String?> toAccountId,
      Value<int> occurredAt,
      Value<Uint8List?> noteEncrypted,
      Value<Uint8List?> attachmentsEncrypted,
      Value<String?> tags,
      Value<String?> contentHash,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

final class $$TransactionEntryTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TransactionEntryTableTable,
          TransactionEntryRow
        > {
  $$TransactionEntryTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LedgerTableTable _ledgerIdTable(_$AppDatabase db) =>
      db.ledgerTable.createAlias(
        $_aliasNameGenerator(
          db.transactionEntryTable.ledgerId,
          db.ledgerTable.id,
        ),
      );

  $$LedgerTableTableProcessedTableManager get ledgerId {
    final $_column = $_itemColumn<String>('ledger_id')!;

    final manager = $$LedgerTableTableTableManager(
      $_db,
      $_db.ledgerTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ledgerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionEntryTableTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionEntryTableTable> {
  $$TransactionEntryTableTableFilterComposer({
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

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fxRate => $composableBuilder(
    column: $table.fxRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get noteEncrypted => $composableBuilder(
    column: $table.noteEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get attachmentsEncrypted => $composableBuilder(
    column: $table.attachmentsEncrypted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  $$LedgerTableTableFilterComposer get ledgerId {
    final $$LedgerTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgerTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerTableTableFilterComposer(
            $db: $db,
            $table: $db.ledgerTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionEntryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionEntryTableTable> {
  $$TransactionEntryTableTableOrderingComposer({
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

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fxRate => $composableBuilder(
    column: $table.fxRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get noteEncrypted => $composableBuilder(
    column: $table.noteEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get attachmentsEncrypted => $composableBuilder(
    column: $table.attachmentsEncrypted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $$LedgerTableTableOrderingComposer get ledgerId {
    final $$LedgerTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgerTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerTableTableOrderingComposer(
            $db: $db,
            $table: $db.ledgerTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionEntryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionEntryTableTable> {
  $$TransactionEntryTableTableAnnotationComposer({
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

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get fxRate =>
      $composableBuilder(column: $table.fxRate, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get noteEncrypted => $composableBuilder(
    column: $table.noteEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get attachmentsEncrypted => $composableBuilder(
    column: $table.attachmentsEncrypted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  $$LedgerTableTableAnnotationComposer get ledgerId {
    final $$LedgerTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgerTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerTableTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgerTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionEntryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionEntryTableTable,
          TransactionEntryRow,
          $$TransactionEntryTableTableFilterComposer,
          $$TransactionEntryTableTableOrderingComposer,
          $$TransactionEntryTableTableAnnotationComposer,
          $$TransactionEntryTableTableCreateCompanionBuilder,
          $$TransactionEntryTableTableUpdateCompanionBuilder,
          (TransactionEntryRow, $$TransactionEntryTableTableReferences),
          TransactionEntryRow,
          PrefetchHooks Function({bool ledgerId})
        > {
  $$TransactionEntryTableTableTableManager(
    _$AppDatabase db,
    $TransactionEntryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionEntryTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TransactionEntryTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TransactionEntryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double?> fxRate = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<Uint8List?> noteEncrypted = const Value.absent(),
                Value<Uint8List?> attachmentsEncrypted = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionEntryTableCompanion(
                id: id,
                ledgerId: ledgerId,
                type: type,
                amount: amount,
                currency: currency,
                fxRate: fxRate,
                categoryId: categoryId,
                accountId: accountId,
                toAccountId: toAccountId,
                occurredAt: occurredAt,
                noteEncrypted: noteEncrypted,
                attachmentsEncrypted: attachmentsEncrypted,
                tags: tags,
                contentHash: contentHash,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ledgerId,
                required String type,
                required double amount,
                required String currency,
                Value<double?> fxRate = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                required int occurredAt,
                Value<Uint8List?> noteEncrypted = const Value.absent(),
                Value<Uint8List?> attachmentsEncrypted = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => TransactionEntryTableCompanion.insert(
                id: id,
                ledgerId: ledgerId,
                type: type,
                amount: amount,
                currency: currency,
                fxRate: fxRate,
                categoryId: categoryId,
                accountId: accountId,
                toAccountId: toAccountId,
                occurredAt: occurredAt,
                noteEncrypted: noteEncrypted,
                attachmentsEncrypted: attachmentsEncrypted,
                tags: tags,
                contentHash: contentHash,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionEntryTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ledgerId = false}) {
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
                    if (ledgerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ledgerId,
                                referencedTable:
                                    $$TransactionEntryTableTableReferences
                                        ._ledgerIdTable(db),
                                referencedColumn:
                                    $$TransactionEntryTableTableReferences
                                        ._ledgerIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$TransactionEntryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionEntryTableTable,
      TransactionEntryRow,
      $$TransactionEntryTableTableFilterComposer,
      $$TransactionEntryTableTableOrderingComposer,
      $$TransactionEntryTableTableAnnotationComposer,
      $$TransactionEntryTableTableCreateCompanionBuilder,
      $$TransactionEntryTableTableUpdateCompanionBuilder,
      (TransactionEntryRow, $$TransactionEntryTableTableReferences),
      TransactionEntryRow,
      PrefetchHooks Function({bool ledgerId})
    >;
typedef $$BudgetTableTableCreateCompanionBuilder =
    BudgetTableCompanion Function({
      required String id,
      required String ledgerId,
      required String period,
      Value<String?> categoryId,
      required double amount,
      Value<int?> carryOver,
      Value<double> carryBalance,
      Value<int?> lastSettledAt,
      required int startDate,
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$BudgetTableTableUpdateCompanionBuilder =
    BudgetTableCompanion Function({
      Value<String> id,
      Value<String> ledgerId,
      Value<String> period,
      Value<String?> categoryId,
      Value<double> amount,
      Value<int?> carryOver,
      Value<double> carryBalance,
      Value<int?> lastSettledAt,
      Value<int> startDate,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$BudgetTableTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetTableTable> {
  $$BudgetTableTableFilterComposer({
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

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carryOver => $composableBuilder(
    column: $table.carryOver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carryBalance => $composableBuilder(
    column: $table.carryBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSettledAt => $composableBuilder(
    column: $table.lastSettledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetTableTable> {
  $$BudgetTableTableOrderingComposer({
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

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carryOver => $composableBuilder(
    column: $table.carryOver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carryBalance => $composableBuilder(
    column: $table.carryBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSettledAt => $composableBuilder(
    column: $table.lastSettledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetTableTable> {
  $$BudgetTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get carryOver =>
      $composableBuilder(column: $table.carryOver, builder: (column) => column);

  GeneratedColumn<double> get carryBalance => $composableBuilder(
    column: $table.carryBalance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSettledAt => $composableBuilder(
    column: $table.lastSettledAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$BudgetTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetTableTable,
          BudgetEntry,
          $$BudgetTableTableFilterComposer,
          $$BudgetTableTableOrderingComposer,
          $$BudgetTableTableAnnotationComposer,
          $$BudgetTableTableCreateCompanionBuilder,
          $$BudgetTableTableUpdateCompanionBuilder,
          (
            BudgetEntry,
            BaseReferences<_$AppDatabase, $BudgetTableTable, BudgetEntry>,
          ),
          BudgetEntry,
          PrefetchHooks Function()
        > {
  $$BudgetTableTableTableManager(_$AppDatabase db, $BudgetTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String> period = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<int?> carryOver = const Value.absent(),
                Value<double> carryBalance = const Value.absent(),
                Value<int?> lastSettledAt = const Value.absent(),
                Value<int> startDate = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetTableCompanion(
                id: id,
                ledgerId: ledgerId,
                period: period,
                categoryId: categoryId,
                amount: amount,
                carryOver: carryOver,
                carryBalance: carryBalance,
                lastSettledAt: lastSettledAt,
                startDate: startDate,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ledgerId,
                required String period,
                Value<String?> categoryId = const Value.absent(),
                required double amount,
                Value<int?> carryOver = const Value.absent(),
                Value<double> carryBalance = const Value.absent(),
                Value<int?> lastSettledAt = const Value.absent(),
                required int startDate,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => BudgetTableCompanion.insert(
                id: id,
                ledgerId: ledgerId,
                period: period,
                categoryId: categoryId,
                amount: amount,
                carryOver: carryOver,
                carryBalance: carryBalance,
                lastSettledAt: lastSettledAt,
                startDate: startDate,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetTableTable,
      BudgetEntry,
      $$BudgetTableTableFilterComposer,
      $$BudgetTableTableOrderingComposer,
      $$BudgetTableTableAnnotationComposer,
      $$BudgetTableTableCreateCompanionBuilder,
      $$BudgetTableTableUpdateCompanionBuilder,
      (
        BudgetEntry,
        BaseReferences<_$AppDatabase, $BudgetTableTable, BudgetEntry>,
      ),
      BudgetEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncOpTableTableCreateCompanionBuilder =
    SyncOpTableCompanion Function({
      Value<int> id,
      required String entity,
      required String entityId,
      required String op,
      required String payload,
      required int enqueuedAt,
      Value<int?> tried,
      Value<String?> lastError,
    });
typedef $$SyncOpTableTableUpdateCompanionBuilder =
    SyncOpTableCompanion Function({
      Value<int> id,
      Value<String> entity,
      Value<String> entityId,
      Value<String> op,
      Value<String> payload,
      Value<int> enqueuedAt,
      Value<int?> tried,
      Value<String?> lastError,
    });

class $$SyncOpTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOpTableTable> {
  $$SyncOpTableTableFilterComposer({
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

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tried => $composableBuilder(
    column: $table.tried,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOpTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOpTableTable> {
  $$SyncOpTableTableOrderingComposer({
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

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tried => $composableBuilder(
    column: $table.tried,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOpTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOpTableTable> {
  $$SyncOpTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tried =>
      $composableBuilder(column: $table.tried, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncOpTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOpTableTable,
          SyncOpEntry,
          $$SyncOpTableTableFilterComposer,
          $$SyncOpTableTableOrderingComposer,
          $$SyncOpTableTableAnnotationComposer,
          $$SyncOpTableTableCreateCompanionBuilder,
          $$SyncOpTableTableUpdateCompanionBuilder,
          (
            SyncOpEntry,
            BaseReferences<_$AppDatabase, $SyncOpTableTable, SyncOpEntry>,
          ),
          SyncOpEntry,
          PrefetchHooks Function()
        > {
  $$SyncOpTableTableTableManager(_$AppDatabase db, $SyncOpTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOpTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOpTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOpTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> enqueuedAt = const Value.absent(),
                Value<int?> tried = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncOpTableCompanion(
                id: id,
                entity: entity,
                entityId: entityId,
                op: op,
                payload: payload,
                enqueuedAt: enqueuedAt,
                tried: tried,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entity,
                required String entityId,
                required String op,
                required String payload,
                required int enqueuedAt,
                Value<int?> tried = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SyncOpTableCompanion.insert(
                id: id,
                entity: entity,
                entityId: entityId,
                op: op,
                payload: payload,
                enqueuedAt: enqueuedAt,
                tried: tried,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOpTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOpTableTable,
      SyncOpEntry,
      $$SyncOpTableTableFilterComposer,
      $$SyncOpTableTableOrderingComposer,
      $$SyncOpTableTableAnnotationComposer,
      $$SyncOpTableTableCreateCompanionBuilder,
      $$SyncOpTableTableUpdateCompanionBuilder,
      (
        SyncOpEntry,
        BaseReferences<_$AppDatabase, $SyncOpTableTable, SyncOpEntry>,
      ),
      SyncOpEntry,
      PrefetchHooks Function()
    >;
typedef $$FxRateTableTableCreateCompanionBuilder =
    FxRateTableCompanion Function({
      required String code,
      required double rateToCny,
      required int updatedAt,
      Value<int> isManual,
      Value<int> rowid,
    });
typedef $$FxRateTableTableUpdateCompanionBuilder =
    FxRateTableCompanion Function({
      Value<String> code,
      Value<double> rateToCny,
      Value<int> updatedAt,
      Value<int> isManual,
      Value<int> rowid,
    });

class $$FxRateTableTableFilterComposer
    extends Composer<_$AppDatabase, $FxRateTableTable> {
  $$FxRateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rateToCny => $composableBuilder(
    column: $table.rateToCny,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FxRateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FxRateTableTable> {
  $$FxRateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rateToCny => $composableBuilder(
    column: $table.rateToCny,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FxRateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FxRateTableTable> {
  $$FxRateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<double> get rateToCny =>
      $composableBuilder(column: $table.rateToCny, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get isManual =>
      $composableBuilder(column: $table.isManual, builder: (column) => column);
}

class $$FxRateTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FxRateTableTable,
          FxRateEntry,
          $$FxRateTableTableFilterComposer,
          $$FxRateTableTableOrderingComposer,
          $$FxRateTableTableAnnotationComposer,
          $$FxRateTableTableCreateCompanionBuilder,
          $$FxRateTableTableUpdateCompanionBuilder,
          (
            FxRateEntry,
            BaseReferences<_$AppDatabase, $FxRateTableTable, FxRateEntry>,
          ),
          FxRateEntry,
          PrefetchHooks Function()
        > {
  $$FxRateTableTableTableManager(_$AppDatabase db, $FxRateTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FxRateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FxRateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FxRateTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<double> rateToCny = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> isManual = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FxRateTableCompanion(
                code: code,
                rateToCny: rateToCny,
                updatedAt: updatedAt,
                isManual: isManual,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                required double rateToCny,
                required int updatedAt,
                Value<int> isManual = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FxRateTableCompanion.insert(
                code: code,
                rateToCny: rateToCny,
                updatedAt: updatedAt,
                isManual: isManual,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FxRateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FxRateTableTable,
      FxRateEntry,
      $$FxRateTableTableFilterComposer,
      $$FxRateTableTableOrderingComposer,
      $$FxRateTableTableAnnotationComposer,
      $$FxRateTableTableCreateCompanionBuilder,
      $$FxRateTableTableUpdateCompanionBuilder,
      (
        FxRateEntry,
        BaseReferences<_$AppDatabase, $FxRateTableTable, FxRateEntry>,
      ),
      FxRateEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserPrefTableTableTableManager get userPrefTable =>
      $$UserPrefTableTableTableManager(_db, _db.userPrefTable);
  $$LedgerTableTableTableManager get ledgerTable =>
      $$LedgerTableTableTableManager(_db, _db.ledgerTable);
  $$CategoryTableTableTableManager get categoryTable =>
      $$CategoryTableTableTableManager(_db, _db.categoryTable);
  $$AccountTableTableTableManager get accountTable =>
      $$AccountTableTableTableManager(_db, _db.accountTable);
  $$TransactionEntryTableTableTableManager get transactionEntryTable =>
      $$TransactionEntryTableTableTableManager(_db, _db.transactionEntryTable);
  $$BudgetTableTableTableManager get budgetTable =>
      $$BudgetTableTableTableManager(_db, _db.budgetTable);
  $$SyncOpTableTableTableManager get syncOpTable =>
      $$SyncOpTableTableTableManager(_db, _db.syncOpTable);
  $$FxRateTableTableTableManager get fxRateTable =>
      $$FxRateTableTableTableManager(_db, _db.fxRateTable);
}
