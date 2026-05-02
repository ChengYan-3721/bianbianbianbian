// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recordMonthSummaryHash() =>
    r'3c13f8d2a5f0808d5cd0f0e93b6c3c643bf9bd60';

/// 当前账本当月的汇总数据。
///
/// 依赖 [recordMonthProvider] → 自动响应月份切换；依赖
/// [currentLedgerIdProvider] + [transactionRepositoryProvider] 取流水。
///
/// Copied from [recordMonthSummary].
@ProviderFor(recordMonthSummary)
final recordMonthSummaryProvider =
    AutoDisposeFutureProvider<RecordMonthSummary>.internal(
      recordMonthSummary,
      name: r'recordMonthSummaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recordMonthSummaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecordMonthSummaryRef =
    AutoDisposeFutureProviderRef<RecordMonthSummary>;
String _$recordMonthHash() => r'e26f6076990688c07a5a999e744129b4be0ac779';

/// 记账首页当前选择的月份（年月，day 固定为 1）。
///
/// Phase 3 Step 3.1 以月为单位导航；后续可拆分为自定义区间。
///
/// Copied from [RecordMonth].
@ProviderFor(RecordMonth)
final recordMonthProvider =
    AutoDisposeNotifierProvider<RecordMonth, DateTime>.internal(
      RecordMonth.new,
      name: r'recordMonthProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recordMonthHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RecordMonth = AutoDisposeNotifier<DateTime>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
