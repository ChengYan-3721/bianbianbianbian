// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
