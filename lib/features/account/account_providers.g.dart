// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$accountsListHash() => r'44737203c4368e3f1f21abda668f0090df7c69ed';

/// 当前账本视角下的账户清单（按 [accountRepository.listActive] 顺序，
/// 即 `updated_at` 倒序）。Step 7.1 列表页直接消费。
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
