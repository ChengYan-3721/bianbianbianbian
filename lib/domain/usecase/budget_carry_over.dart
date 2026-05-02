import '../entity/budget.dart';

/// 计算预算"当前周期"的 start（半开区间起点）。
///
/// 与 `lib/features/budget/budget_progress.dart::budgetPeriodRange` 同语义，
/// 但本文件刻意不 import `features/`——这是 `data/` 层在 [save] 路径上要用
/// 的纯函数，按依赖方向 `data/` → `domain/` 必须独立可用。
DateTime _currentPeriodStart(String period, DateTime now) {
  if (period == 'yearly') {
    return DateTime(now.year, 1, 1);
  }
  return DateTime(now.year, now.month, 1);
}

/// Step 6.4：在 [BudgetRepository.save] 路径上根据 `carryOver` 切换决定如何
/// 写 `carry_balance` / `last_settled_at`。
///
/// 规则：
/// - **新建**（`prev == null`）：`carryOver=true` 时 `lastSettledAt` 置为
///   **`next.startDate` 所在周期 start**——这让用户在创建预算时通过把
///   `startDate` 选到过去某个月，可以"补记"该月之后的剩余结转（场景：5/1
///   新建账本，把 4 月单据补录后想让 4 月剩余结转到 5 月，只需新建预算时
///   `startDate` 选 4/1）。`carryOver=false` 时 `lastSettledAt = null`。
///   `carryBalance` 一律 0。
/// - **编辑**（`prev != null`）：
///   - `prev.carryOver=false → next.carryOver=true`（"重新打开"）：把
///     `lastSettledAt` 重置为 **`now` 所在周期 start**——这是 implementation-
///     plan Step 6.4 验收"关闭结转重新打开，不回溯历史（只影响开启后的
///     月份）"的关键约束；`carryBalance` 沿用 `prev.carryBalance`（历史
///     累积不在重新打开时清零）。
///   - 其它情况：`carryBalance` / `lastSettledAt` 一律继承 `prev` 的值，
///     避免编辑金额/分类等字段时误改结转状态。
///
/// 函数纯粹——`now` 走参数注入，便于测试与时区无关。
Budget applyCarryOverToggle({
  required Budget? prev,
  required Budget next,
  required DateTime now,
}) {
  if (prev == null) {
    final startAnchor = _currentPeriodStart(next.period, next.startDate);
    return next.copyWith(
      carryBalance: 0,
      lastSettledAt: next.carryOver ? startAnchor : null,
    );
  }
  if (!prev.carryOver && next.carryOver) {
    final reopenAnchor = _currentPeriodStart(next.period, now);
    return next.copyWith(
      carryBalance: prev.carryBalance,
      lastSettledAt: reopenAnchor,
    );
  }
  return next.copyWith(
    carryBalance: prev.carryBalance,
    lastSettledAt: prev.lastSettledAt,
  );
}
