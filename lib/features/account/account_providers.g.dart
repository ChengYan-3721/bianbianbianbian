// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$accountOrderHash() => r'ccaa57ebdd09339c0b91a1bd02ffffc8ce29725b';

/// 用户在 `user_pref.account_order` 中保存的账户排序（JSON 数组字符串）。
///
/// - null：使用默认排序（余额倒序）
/// - 非空：用户手动拖动后的 ID 顺序
///
/// Copied from [accountOrder].
@ProviderFor(accountOrder)
final accountOrderProvider = AutoDisposeFutureProvider<List<String>?>.internal(
  accountOrder,
  name: r'accountOrderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountOrderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountOrderRef = AutoDisposeFutureProviderRef<List<String>?>;
String _$accountsListHash() => r'bcfbdb6745975e21fabf04e789bbc2ef3892d857';

/// 当前账本视角下的账户清单，按用户自定义排序（`user_pref.account_order`）
/// 或默认余额倒序排列。Step 7.1 列表页直接消费。
///
/// 当 `account_order` 为 null（默认）时，独立计算余额用于排序，
/// 不依赖 [accountBalancesProvider] 以避免循环依赖。
///
/// Copied from [accountsList].
@ProviderFor(accountsList)
final accountsListProvider = AutoDisposeFutureProvider<List<Account>>.internal(
  accountsList,
  name: r'accountsListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountsListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountsListRef = AutoDisposeFutureProviderRef<List<Account>>;
String _$accountBalancesHash() => r'0c745ebbfbbca090333e62e038075edda8e26778';

/// 当前账本视角下的所有账户余额（含未发生流水的账户）。
///
/// design-document §5.1.4 明确"统计页、预算、资产均在'当前账本'维度内聚合"
/// ——故仅取当前账本流水参与净额。账户本身是全局资源（跨账本共享），但本期
/// 余额展示走"账本维度"。
///
/// Copied from [accountBalances].
@ProviderFor(accountBalances)
final accountBalancesProvider =
    AutoDisposeFutureProvider<List<AccountBalance>>.internal(
      accountBalances,
      name: r'accountBalancesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$accountBalancesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountBalancesRef = AutoDisposeFutureProviderRef<List<AccountBalance>>;
String _$totalAssetsHash() => r'68e4ed54da57ca006afd8121436237a64dc4af89';

/// 当前账本视角下的总资产——所有 [Account.includeInTotal] = true 的账户当前
/// 余额求和。Step 7.1 资产页顶部卡片消费。
///
/// Copied from [totalAssets].
@ProviderFor(totalAssets)
final totalAssetsProvider = AutoDisposeFutureProvider<double>.internal(
  totalAssets,
  name: r'totalAssetsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalAssetsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalAssetsRef = AutoDisposeFutureProviderRef<double>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
