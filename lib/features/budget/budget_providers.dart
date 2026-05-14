import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/budget.dart';
import '../../domain/entity/category.dart';
import 'budget_progress.dart';

part 'budget_providers.g.dart';

/// 预算进度计算所用的"当前时间"注入点。生产默认 `DateTime.now`；测试覆盖以
/// 锁定参考时间，避免周期边界 flaky。
typedef BudgetClock = DateTime Function();

@Riverpod(keepAlive: true)
BudgetClock budgetClock(Ref ref) => DateTime.now;

/// 一级分类的本地化标签——用于预算列表/编辑页展示。
/// 键集来自 `seeder.dart` 的 `categoriesByParent.keys`。
Map<String, String> parentKeyLabels(BuildContext context) {
  final l10n = context.l10n;
  return {
    'income': l10n.parentKeyIncome,
    'food': l10n.parentKeyFood,
    'shopping': l10n.parentKeyShopping,
    'transport': l10n.parentKeyTransport,
    'education': l10n.parentKeyEducation,
    'entertainment': l10n.parentKeyEntertainment,
    'social': l10n.parentKeySocial,
    'housing': l10n.parentKeyHousing,
    'medical': l10n.parentKeyMedical,
    'investment': l10n.parentKeyInvestment,
    'other': l10n.parentKeyOther,
  };
}

/// 当前账本的活跃预算列表（按周期升序、`categoryId == null` 排前）。
@riverpod
Future<List<Budget>> activeBudgets(Ref ref) async {
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final repo = await ref.watch(budgetRepositoryProvider.future);
  final list = await repo.listActiveByLedger(ledgerId);
  list.sort((a, b) {
    if (a.period != b.period) {
      return a.period == 'monthly' ? -1 : 1;
    }
    if ((a.categoryId == null) != (b.categoryId == null)) {
      return a.categoryId == null ? -1 : 1;
    }
    return 0;
  });
  return list;
}

/// 可用于预算的分类列表（排除 `income` 一级分类的二级分类）。
@riverpod
Future<List<Category>> budgetableCategories(Ref ref) async {
  final repo = await ref.watch(categoryRepositoryProvider.future);
  final all = await repo.listActiveAll();
  return all.where((c) => c.parentKey != 'income').toList(growable: false);
}

/// 当前账本的"总预算"——`categoryId == null` 的活跃预算，月度优先于年度。
///
/// Step 6.3 用：统计页饼图卡顶部展示总预算进度环；本 provider 返回 null 时
/// 进度环整体隐藏。复用 [activeBudgetsProvider]，保证与预算设置页的"已花 /
/// 上限"完全同源。
@riverpod
Future<Budget?> totalBudget(Ref ref) async {
  final budgets = await ref.watch(activeBudgetsProvider.future);
  Budget? monthly;
  Budget? yearly;
  for (final b in budgets) {
    if (b.categoryId != null) continue;
    if (b.period == 'monthly') {
      monthly ??= b;
    } else if (b.period == 'yearly') {
      yearly ??= b;
    }
  }
  return monthly ?? yearly;
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
@riverpod
Future<BudgetProgress> budgetProgressFor(Ref ref, Budget budget) async {
  final repo = await ref.watch(transactionRepositoryProvider.future);
  final budgetRepo = await ref.watch(budgetRepositoryProvider.future);
  final clock = ref.watch(budgetClockProvider);
  final txs = await repo.listActiveByLedger(budget.ledgerId);
  final now = clock();

  final settled = settleBudgetIfNeeded(
    budget: budget,
    transactions: txs,
    now: now,
  );
  if (!identical(settled, budget) &&
      (settled.carryBalance != budget.carryBalance ||
          settled.lastSettledAt != budget.lastSettledAt)) {
    await budgetRepo.updateCarrySettlement(
      id: settled.id,
      carryBalance: settled.carryBalance,
      lastSettledAt: settled.lastSettledAt,
    );
  }

  final spent = computePeriodSpent(
    budget: settled,
    transactions: txs,
    now: now,
  );
  final limit =
      settled.amount + (settled.carryOver ? settled.carryBalance : 0);
  return computeBudgetProgress(
    spent: spent,
    limit: limit,
    carryBalance: settled.carryOver ? settled.carryBalance : 0,
  );
}

/// 已经在本次会话中震动过的预算 id 集合。
///
/// 仅当预算进度 ***首次*** 进入红档（>100%）时震动一次：UI 在渲染红档时
/// 检查该 set，若不存在则触发 [HapticFeedback.heavyImpact] 并 [markVibrated]
/// 标记，避免每次重建 / provider 刷新都重复震动。冷启动后自然清空——这是
/// "会话级"的预期语义，符合 implementation-plan 的"session 标记"约束。
@Riverpod(keepAlive: true)
class BudgetVibrationSession extends _$BudgetVibrationSession {
  @override
  Set<String> build() => <String>{};

  /// 当前预算 id 是否已经在本会话中震动过。
  bool hasVibrated(String budgetId) => state.contains(budgetId);

  /// 标记该预算已在本会话震动过。
  void markVibrated(String budgetId) {
    if (state.contains(budgetId)) return;
    state = {...state, budgetId};
  }

  /// 当预算从红档回到绿/橙时调用，让其下次再次进入红档时还能震动一次。
  /// 当前 Step 6.2 的 UI 不会主动调用——但保留接口给后续测试 / 手动重置。
  void clear(String budgetId) {
    if (!state.contains(budgetId)) return;
    state = {...state}..remove(budgetId);
  }
}
