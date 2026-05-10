// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentThemeHash() => r'90d0cee26237474366010936ebf3609be2241278';

/// Step 15.1：当前主题的 [ThemeData] provider。
///
/// 消费 [currentThemeKeyProvider] 后经 [BianBianTheme.fromKey] 枚举转换，
/// 再由 [buildAppTheme] 构建完整 [ThemeData]。[BianBianApp] 的
/// `MaterialApp.router.theme` 直接 watch 本 provider。
///
/// Copied from [currentTheme].
@ProviderFor(currentTheme)
final currentThemeProvider = Provider<ThemeData>.internal(
  currentTheme,
  name: r'currentThemeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentThemeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentThemeRef = ProviderRef<ThemeData>;
String _$fontSizeScaleFactorHash() =>
    r'f4bb99ef0057a2efc42d4e0ffd638e27c52df85b';

/// Step 15.2：字号缩放因子 provider。
///
/// 消费 [currentFontSizeKeyProvider] 后经 [BianBianFontSize.fromKey] 枚举转换，
/// 返回 [BianBianFontSize.scaleFactor]（0.85 / 1.0 / 1.15）。
/// [BianBianApp] 在 `MaterialApp.router.builder` 里乘以系统 TextScaler
/// 生成最终 [TextScaler]。
///
/// Copied from [fontSizeScaleFactor].
@ProviderFor(fontSizeScaleFactor)
final fontSizeScaleFactorProvider = Provider<double>.internal(
  fontSizeScaleFactor,
  name: r'fontSizeScaleFactorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fontSizeScaleFactorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FontSizeScaleFactorRef = ProviderRef<double>;
String _$currentIconPackHash() => r'fe6fe57a79bb5c5809f69cf1eab8cf16f8f9cb63';

/// Step 15.3：当前图标包枚举 provider。
///
/// 消费 [currentIconPackKeyProvider] 后经 [BianBianIconPack.fromKey] 枚举转换。
/// UI 与图标解析函数通过本 provider 获取激活的 [BianBianIconPack]。
///
/// Copied from [currentIconPack].
@ProviderFor(currentIconPack)
final currentIconPackProvider = Provider<BianBianIconPack>.internal(
  currentIconPack,
  name: r'currentIconPackProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentIconPackHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentIconPackRef = ProviderRef<BianBianIconPack>;
String _$currentLedgerDefaultCurrencyHash() =>
    r'a32f0f9a09f6d90532ed14d173a02d803ed2fb32';

/// Step 8.2：当前账本的默认币种 code（如 `'CNY'` / `'USD'`）。
///
/// 依赖 [currentLedgerIdProvider] + [ledgerRepositoryProvider]：账本切换或
/// 账本本身被编辑时（Step 4.x ledger_edit_page 后会 invalidate ledgerRepositoryProvider），
/// 本 provider 会自动重新计算。读取失败兜底 `'CNY'`，与 design-document §7.1
/// `ledger.default_currency DEFAULT 'CNY'` 一致。
///
/// Copied from [currentLedgerDefaultCurrency].
@ProviderFor(currentLedgerDefaultCurrency)
final currentLedgerDefaultCurrencyProvider = FutureProvider<String>.internal(
  currentLedgerDefaultCurrency,
  name: r'currentLedgerDefaultCurrencyProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentLedgerDefaultCurrencyHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentLedgerDefaultCurrencyRef = FutureProviderRef<String>;
String _$fxRatesHash() => r'3c0b4b944114b1c84d1f4ae6e6524973fceaed3a';

/// Step 8.2：内置币种快照——`code → rate_to_cny`。
///
/// 直接 dump `fx_rate` 表（Step 8.1 种子化保证至少 11 行）。读路径走 [appDatabaseProvider]
/// 的 [FxRateDao.listAll]；UI 与保存时的换算函数都从这里取。Step 8.3 联网刷新或
/// 用户手动覆写后会 invalidate 本 provider。
///
/// Copied from [fxRates].
@ProviderFor(fxRates)
final fxRatesProvider = FutureProvider<Map<String, double>>.internal(
  fxRates,
  name: r'fxRatesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fxRatesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FxRatesRef = FutureProviderRef<Map<String, double>>;
String _$fxRateRowsHash() => r'447a0967afe2dc2f06ef289f93815b7d8c19fbbf';

/// Step 8.3：fx_rate 全量行（含 is_manual / updated_at），供"汇率管理"页渲染。
///
/// 与 [fxRates] 不同：[fxRates] 只暴露 code→rate（供换算），本 provider 暴露
/// 全字段（供 UI 渲染手动/自动徽章 + 更新时间）。
///
/// Copied from [fxRateRows].
@ProviderFor(fxRateRows)
final fxRateRowsProvider = FutureProvider<List<FxRateEntry>>.internal(
  fxRateRows,
  name: r'fxRateRowsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fxRateRowsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FxRateRowsRef = FutureProviderRef<List<FxRateEntry>>;
String _$fxRateRefreshServiceHash() =>
    r'befeff1d076a11163b48258e6fab6ba47dd05e30';

/// Step 8.3：汇率刷新服务 provider。生产 fetcher 走 [defaultFxRateFetcher]
/// （open.er-api.com）；测试可 override 注入伪造 fetcher。
///
/// Copied from [fxRateRefreshService].
@ProviderFor(fxRateRefreshService)
final fxRateRefreshServiceProvider = Provider<FxRateRefreshService>.internal(
  fxRateRefreshService,
  name: r'fxRateRefreshServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fxRateRefreshServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FxRateRefreshServiceRef = ProviderRef<FxRateRefreshService>;
String _$currentThemeKeyHash() => r'e14eb3149091066465f17282be8d528e0df9ad5d';

/// Step 15.1：当前主题标识 provider。
///
/// 数据源是 `user_pref.theme`（TEXT，默认 `'cream_bunny'`）。
/// UI 通过 `ref.watch(currentThemeKeyProvider)` 拿字符串 key 供
/// [currentThemeProvider] 消费。
///
/// Copied from [CurrentThemeKey].
@ProviderFor(CurrentThemeKey)
final currentThemeKeyProvider =
    AsyncNotifierProvider<CurrentThemeKey, String>.internal(
      CurrentThemeKey.new,
      name: r'currentThemeKeyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentThemeKeyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentThemeKey = AsyncNotifier<String>;
String _$currentFontSizeKeyHash() =>
    r'1054ffcaf6d213184bd0bdecc8e558a305b5a3d5';

/// Step 15.2：当前字号档位 provider。
///
/// 数据源是 `user_pref.font_size`（TEXT，默认 `'standard'`）。
/// UI 通过 `ref.watch(currentFontSizeKeyProvider)` 拿字符串 key 供
/// [fontSizeScaleFactorProvider] 消费。
///
/// Copied from [CurrentFontSizeKey].
@ProviderFor(CurrentFontSizeKey)
final currentFontSizeKeyProvider =
    AsyncNotifierProvider<CurrentFontSizeKey, String>.internal(
      CurrentFontSizeKey.new,
      name: r'currentFontSizeKeyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentFontSizeKeyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentFontSizeKey = AsyncNotifier<String>;
String _$currentIconPackKeyHash() =>
    r'5ba3dbffc1e1bc49d25b58f8911f9adc902ab747';

/// Step 15.3：当前图标包标识 provider。
///
/// 数据源是 `user_pref.icon_pack`（TEXT，默认 `'sticker'`）。
///
/// Copied from [CurrentIconPackKey].
@ProviderFor(CurrentIconPackKey)
final currentIconPackKeyProvider =
    AsyncNotifierProvider<CurrentIconPackKey, String>.internal(
      CurrentIconPackKey.new,
      name: r'currentIconPackKeyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentIconPackKeyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentIconPackKey = AsyncNotifier<String>;
String _$multiCurrencyEnabledHash() =>
    r'19098f58ad0972a1159f65a8aaa0da8223d14fdc';

/// Step 8.1：多币种全局开关。
///
/// 数据源是 `user_pref.multi_currency_enabled`（v6 schema 新增）。
/// `0` / `null` 视为关闭，`1` 视为开启——与 [UserPrefTable] 的默认值一致。
///
/// 写路径走 [MultiCurrencyEnabled.set] 持久化后 `invalidateSelf()`，
/// UI 通过 `ref.watch(multiCurrencyEnabledProvider)` 自动响应。
///
/// Copied from [MultiCurrencyEnabled].
@ProviderFor(MultiCurrencyEnabled)
final multiCurrencyEnabledProvider =
    AsyncNotifierProvider<MultiCurrencyEnabled, bool>.internal(
      MultiCurrencyEnabled.new,
      name: r'multiCurrencyEnabledProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$multiCurrencyEnabledHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MultiCurrencyEnabled = AsyncNotifier<bool>;
String _$reminderEnabledHash() => r'b32cf614017e4ae2a23ad90e605b5ee2cbc75fd7';

/// Step 16.1：每日记账提醒开关 provider。
///
/// 数据源是 `user_pref.reminder_enabled`（INTEGER，0/null = 关闭，1 = 开启）。
/// UI 通过 `ref.watch(reminderEnabledProvider)` 自动响应。
///
/// Copied from [ReminderEnabled].
@ProviderFor(ReminderEnabled)
final reminderEnabledProvider =
    AsyncNotifierProvider<ReminderEnabled, bool>.internal(
      ReminderEnabled.new,
      name: r'reminderEnabledProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reminderEnabledHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReminderEnabled = AsyncNotifier<bool>;
String _$reminderTimeHash() => r'0015507866b1d79162a117ed18267b32272d1494';

/// Step 16.1：每日记账提醒时间 provider。
///
/// 数据源是 `user_pref.reminder_time`（TEXT，'HH:mm' 格式，null = 从未设置）。
/// UI 通过 `ref.watch(reminderTimeProvider)` 拿 `TimeOfDay?` 自动响应。
///
/// Copied from [ReminderTime].
@ProviderFor(ReminderTime)
final reminderTimeProvider =
    AsyncNotifierProvider<ReminderTime, TimeOfDay?>.internal(
      ReminderTime.new,
      name: r'reminderTimeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reminderTimeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReminderTime = AsyncNotifier<TimeOfDay?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
