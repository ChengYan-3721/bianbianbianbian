// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ledgerRepositoryHash() => r'ce49dd105b62a7faff72d2b4513d2bb581dedcce';

/// See also [ledgerRepository].
@ProviderFor(ledgerRepository)
final ledgerRepositoryProvider = FutureProvider<LedgerRepository>.internal(
  ledgerRepository,
  name: r'ledgerRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ledgerRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LedgerRepositoryRef = FutureProviderRef<LedgerRepository>;
String _$categoryRepositoryHash() =>
    r'2bec91636c8c8a8616832431f098d7e4ffbf1735';

/// See also [categoryRepository].
@ProviderFor(categoryRepository)
final categoryRepositoryProvider = FutureProvider<CategoryRepository>.internal(
  categoryRepository,
  name: r'categoryRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$categoryRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CategoryRepositoryRef = FutureProviderRef<CategoryRepository>;
String _$accountRepositoryHash() => r'dc7e2bd92011fd7010fbe6a76eff26f85384547e';

/// See also [accountRepository].
@ProviderFor(accountRepository)
final accountRepositoryProvider = FutureProvider<AccountRepository>.internal(
  accountRepository,
  name: r'accountRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountRepositoryRef = FutureProviderRef<AccountRepository>;
String _$transactionRepositoryHash() =>
    r'805f8d15f888220e0ceeb82ccfa7fe78affb46be';

/// See also [transactionRepository].
@ProviderFor(transactionRepository)
final transactionRepositoryProvider =
    FutureProvider<TransactionRepository>.internal(
      transactionRepository,
      name: r'transactionRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transactionRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TransactionRepositoryRef = FutureProviderRef<TransactionRepository>;
String _$budgetRepositoryHash() => r'528457b81b79a3aa35146867f65ad8a439d2c4e2';

/// See also [budgetRepository].
@ProviderFor(budgetRepository)
final budgetRepositoryProvider = FutureProvider<BudgetRepository>.internal(
  budgetRepository,
  name: r'budgetRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$budgetRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BudgetRepositoryRef = FutureProviderRef<BudgetRepository>;
String _$currentLedgerIdHash() => r'e1432126d0600ac5e743db88c2462505fc4fd832';

/// 当前选中账本的 id。
///
/// Phase 4 Step 4.1 升级为 [AsyncNotifier]：支持 [switchTo] 切换并持久化到
/// [user_pref.current_ledger_id]。build 先查 user_pref → 存在且 ledger 仍活跃
/// 则返回；否则回退到第一个活跃账本（覆盖写入 user_pref 供下次 build 命中）。
///
/// Copied from [CurrentLedgerId].
@ProviderFor(CurrentLedgerId)
final currentLedgerIdProvider =
    AsyncNotifierProvider<CurrentLedgerId, String>.internal(
      CurrentLedgerId.new,
      name: r'currentLedgerIdProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentLedgerIdHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentLedgerId = AsyncNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
