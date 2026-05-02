// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$budgetClockHash() => r'e6ab6c3a0eb3e7b79ffe571aa447db2880fc174d';

/// See also [budgetClock].
@ProviderFor(budgetClock)
final budgetClockProvider = Provider<BudgetClock>.internal(
  budgetClock,
  name: r'budgetClockProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$budgetClockHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BudgetClockRef = ProviderRef<BudgetClock>;
String _$activeBudgetsHash() => r'0309147acfb29115c4143d13bfbe14dc7460410f';

/// 当前账本的活跃预算列表（按周期升序、`categoryId == null` 排前）。
///
/// Copied from [activeBudgets].
@ProviderFor(activeBudgets)
final activeBudgetsProvider = AutoDisposeFutureProvider<List<Budget>>.internal(
  activeBudgets,
  name: r'activeBudgetsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeBudgetsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveBudgetsRef = AutoDisposeFutureProviderRef<List<Budget>>;
String _$budgetableCategoriesHash() =>
    r'f90a2c12df0e75ec4bf72818b03b7f956423762b';

/// 可用于预算的分类列表（排除 `income` 一级分类的二级分类）。
///
/// Copied from [budgetableCategories].
@ProviderFor(budgetableCategories)
final budgetableCategoriesProvider =
    AutoDisposeFutureProvider<List<Category>>.internal(
      budgetableCategories,
      name: r'budgetableCategoriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$budgetableCategoriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BudgetableCategoriesRef = AutoDisposeFutureProviderRef<List<Category>>;
String _$totalBudgetHash() => r'8a1489cd5e71b1de430f14b0a3a4a193bb2dd032';

/// 当前账本的"总预算"——`categoryId == null` 的活跃预算，月度优先于年度。
///
/// Step 6.3 用：统计页饼图卡顶部展示总预算进度环；本 provider 返回 null 时
/// 进度环整体隐藏。复用 [activeBudgetsProvider]，保证与预算设置页的"已花 /
/// 上限"完全同源。
///
/// Copied from [totalBudget].
@ProviderFor(totalBudget)
final totalBudgetProvider = AutoDisposeFutureProvider<Budget?>.internal(
  totalBudget,
  name: r'totalBudgetProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalBudgetHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalBudgetRef = AutoDisposeFutureProviderRef<Budget?>;
String _$budgetProgressForHash() => r'66aa7d97f71e6361bdceedc10c330c7960cec984';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 单个预算的"已花 / 本期可用"进度（含色档）。
///
/// 周期边界由 [budgetClockProvider] 决定：`monthly` 取 now 所在自然月，
/// `yearly` 取 now 所在自然年。
///
/// Step 6.4：在计算进度前先调 [settleBudgetIfNeeded] 把跨周期累加补齐，
/// 若 budget 因结算被改写则**就地持久化** `carry_balance` / `last_settled_at`
/// 两列（不动 `updated_at`、不入队 `sync_op`——结算是派生数据维护，对端
/// 从流水重算即可）。`limit` 等于 `amount + (carryOver ? carryBalance : 0)`，
/// 即设计文档所称"本期可用"。
///
/// Copied from [budgetProgressFor].
@ProviderFor(budgetProgressFor)
const budgetProgressForProvider = BudgetProgressForFamily();

/// 单个预算的"已花 / 本期可用"进度（含色档）。
///
/// 周期边界由 [budgetClockProvider] 决定：`monthly` 取 now 所在自然月，
/// `yearly` 取 now 所在自然年。
///
/// Step 6.4：在计算进度前先调 [settleBudgetIfNeeded] 把跨周期累加补齐，
/// 若 budget 因结算被改写则**就地持久化** `carry_balance` / `last_settled_at`
/// 两列（不动 `updated_at`、不入队 `sync_op`——结算是派生数据维护，对端
/// 从流水重算即可）。`limit` 等于 `amount + (carryOver ? carryBalance : 0)`，
/// 即设计文档所称"本期可用"。
///
/// Copied from [budgetProgressFor].
class BudgetProgressForFamily extends Family<AsyncValue<BudgetProgress>> {
  /// 单个预算的"已花 / 本期可用"进度（含色档）。
  ///
  /// 周期边界由 [budgetClockProvider] 决定：`monthly` 取 now 所在自然月，
  /// `yearly` 取 now 所在自然年。
  ///
  /// Step 6.4：在计算进度前先调 [settleBudgetIfNeeded] 把跨周期累加补齐，
  /// 若 budget 因结算被改写则**就地持久化** `carry_balance` / `last_settled_at`
  /// 两列（不动 `updated_at`、不入队 `sync_op`——结算是派生数据维护，对端
  /// 从流水重算即可）。`limit` 等于 `amount + (carryOver ? carryBalance : 0)`，
  /// 即设计文档所称"本期可用"。
  ///
  /// Copied from [budgetProgressFor].
  const BudgetProgressForFamily();

  /// 单个预算的"已花 / 本期可用"进度（含色档）。
  ///
  /// 周期边界由 [budgetClockProvider] 决定：`monthly` 取 now 所在自然月，
  /// `yearly` 取 now 所在自然年。
  ///
  /// Step 6.4：在计算进度前先调 [settleBudgetIfNeeded] 把跨周期累加补齐，
  /// 若 budget 因结算被改写则**就地持久化** `carry_balance` / `last_settled_at`
  /// 两列（不动 `updated_at`、不入队 `sync_op`——结算是派生数据维护，对端
  /// 从流水重算即可）。`limit` 等于 `amount + (carryOver ? carryBalance : 0)`，
  /// 即设计文档所称"本期可用"。
  ///
  /// Copied from [budgetProgressFor].
  BudgetProgressForProvider call(Budget budget) {
    return BudgetProgressForProvider(budget);
  }

  @override
  BudgetProgressForProvider getProviderOverride(
    covariant BudgetProgressForProvider provider,
  ) {
    return call(provider.budget);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'budgetProgressForProvider';
}

/// 单个预算的"已花 / 本期可用"进度（含色档）。
///
/// 周期边界由 [budgetClockProvider] 决定：`monthly` 取 now 所在自然月，
/// `yearly` 取 now 所在自然年。
///
/// Step 6.4：在计算进度前先调 [settleBudgetIfNeeded] 把跨周期累加补齐，
/// 若 budget 因结算被改写则**就地持久化** `carry_balance` / `last_settled_at`
/// 两列（不动 `updated_at`、不入队 `sync_op`——结算是派生数据维护，对端
/// 从流水重算即可）。`limit` 等于 `amount + (carryOver ? carryBalance : 0)`，
/// 即设计文档所称"本期可用"。
///
/// Copied from [budgetProgressFor].
class BudgetProgressForProvider
    extends AutoDisposeFutureProvider<BudgetProgress> {
  /// 单个预算的"已花 / 本期可用"进度（含色档）。
  ///
  /// 周期边界由 [budgetClockProvider] 决定：`monthly` 取 now 所在自然月，
  /// `yearly` 取 now 所在自然年。
  ///
  /// Step 6.4：在计算进度前先调 [settleBudgetIfNeeded] 把跨周期累加补齐，
  /// 若 budget 因结算被改写则**就地持久化** `carry_balance` / `last_settled_at`
  /// 两列（不动 `updated_at`、不入队 `sync_op`——结算是派生数据维护，对端
  /// 从流水重算即可）。`limit` 等于 `amount + (carryOver ? carryBalance : 0)`，
  /// 即设计文档所称"本期可用"。
  ///
  /// Copied from [budgetProgressFor].
  BudgetProgressForProvider(Budget budget)
    : this._internal(
        (ref) => budgetProgressFor(ref as BudgetProgressForRef, budget),
        from: budgetProgressForProvider,
        name: r'budgetProgressForProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$budgetProgressForHash,
        dependencies: BudgetProgressForFamily._dependencies,
        allTransitiveDependencies:
            BudgetProgressForFamily._allTransitiveDependencies,
        budget: budget,
      );

  BudgetProgressForProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.budget,
  }) : super.internal();

  final Budget budget;

  @override
  Override overrideWith(
    FutureOr<BudgetProgress> Function(BudgetProgressForRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BudgetProgressForProvider._internal(
        (ref) => create(ref as BudgetProgressForRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        budget: budget,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<BudgetProgress> createElement() {
    return _BudgetProgressForProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BudgetProgressForProvider && other.budget == budget;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, budget.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BudgetProgressForRef on AutoDisposeFutureProviderRef<BudgetProgress> {
  /// The parameter `budget` of this provider.
  Budget get budget;
}

class _BudgetProgressForProviderElement
    extends AutoDisposeFutureProviderElement<BudgetProgress>
    with BudgetProgressForRef {
  _BudgetProgressForProviderElement(super.provider);

  @override
  Budget get budget => (origin as BudgetProgressForProvider).budget;
}

String _$budgetVibrationSessionHash() =>
    r'bafe725fdb487ed4cbb9798a52167285ae9cd9f1';

/// 已经在本次会话中震动过的预算 id 集合。
///
/// 仅当预算进度 ***首次*** 进入红档（>100%）时震动一次：UI 在渲染红档时
/// 检查该 set，若不存在则触发 [HapticFeedback.heavyImpact] 并 [markVibrated]
/// 标记，避免每次重建 / provider 刷新都重复震动。冷启动后自然清空——这是
/// "会话级"的预期语义，符合 implementation-plan 的"session 标记"约束。
///
/// Copied from [BudgetVibrationSession].
@ProviderFor(BudgetVibrationSession)
final budgetVibrationSessionProvider =
    NotifierProvider<BudgetVibrationSession, Set<String>>.internal(
      BudgetVibrationSession.new,
      name: r'budgetVibrationSessionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$budgetVibrationSessionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BudgetVibrationSession = Notifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
