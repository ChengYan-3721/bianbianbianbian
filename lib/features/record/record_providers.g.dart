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
String _$daysSinceLastTransactionHash() =>
    r'8182835651a7a7bb49b5596dfb71de34b0b4f257';

/// 当前账本距最近一笔未软删流水的天数；无流水时返回 null。
///
/// UI 消费本 provider 判断是否展示"未记账天数"轻提示卡片。
///
/// Copied from [daysSinceLastTransaction].
@ProviderFor(daysSinceLastTransaction)
final daysSinceLastTransactionProvider = FutureProvider<int?>.internal(
  daysSinceLastTransaction,
  name: r'daysSinceLastTransactionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$daysSinceLastTransactionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DaysSinceLastTransactionRef = FutureProviderRef<int?>;
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
String _$idleReminderShownDateHash() =>
    r'1d329d08f8dae30739a8963df168019ac2f44965';

/// 当天是否已展示过未记账天数轻提示。
///
/// 持久化到 SharedPreferences（key: `idle_reminder_last_date`），
/// 值为 'yyyy-MM-dd' 格式。跨重启后同一天不会重复提醒。
///
/// Copied from [IdleReminderShownDate].
@ProviderFor(IdleReminderShownDate)
final idleReminderShownDateProvider =
    AsyncNotifierProvider<IdleReminderShownDate, String?>.internal(
      IdleReminderShownDate.new,
      name: r'idleReminderShownDateProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$idleReminderShownDateHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IdleReminderShownDate = AsyncNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
