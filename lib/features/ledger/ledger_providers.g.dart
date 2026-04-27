// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ledgerTxCountsHash() => r'c5f31b22850c724178416d7820bcdd19c21c37cc';

/// 各账本的活跃流水条数——供账本列表展示"流水总数"。
///
/// Copied from [LedgerTxCounts].
@ProviderFor(LedgerTxCounts)
final ledgerTxCountsProvider =
    AsyncNotifierProvider<LedgerTxCounts, Map<String, int>>.internal(
      LedgerTxCounts.new,
      name: r'ledgerTxCountsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$ledgerTxCountsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LedgerTxCounts = AsyncNotifier<Map<String, int>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
