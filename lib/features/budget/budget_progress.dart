import '../../domain/entity/budget.dart';
import '../../domain/entity/transaction_entry.dart';

/// 预算进度的三档颜色枚举（design-document §5.4）。
enum BudgetProgressLevel { green, orange, red }

/// 预算进度的纯数据视图。
///
/// `ratio` = `spent / limit`，可超过 1.0；`limit <= 0` 时 ratio 固定为 0。
/// `carryBalance` 是结算后的累计结转余额（Step 6.4），用于卡片副标题/可用
/// 金额展示——这里携带是为了让 UI 单一数据源跟随 progress 异步刷新，避免
/// 出现"已花/上限正确但右上结转未显示"的不一致。
class BudgetProgress {
  const BudgetProgress({
    required this.spent,
    required this.limit,
    required this.ratio,
    required this.level,
    this.carryBalance = 0,
  });

  final double spent;
  final double limit;
  final double ratio;
  final BudgetProgressLevel level;
  final double carryBalance;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BudgetProgress &&
        other.spent == spent &&
        other.limit == limit &&
        other.ratio == ratio &&
        other.level == level &&
        other.carryBalance == carryBalance;
  }

  @override
  int get hashCode => Object.hash(spent, limit, ratio, level, carryBalance);

  @override
  String toString() =>
      'BudgetProgress(spent: $spent, limit: $limit, ratio: $ratio, '
      'level: $level, carryBalance: $carryBalance)';
}

/// 按 design-document §5.4 的色档规则计算预算进度。
///
/// 边界（implementation-plan Step 6.2）：
/// - `< 70%` → 绿；
/// - `70%` 与 `100%` 都归橙；
/// - `> 100%` → 红。
///
/// `limit <= 0` 视为"未设置上限"，返回 ratio=0 / level=green，避免触发震动。
BudgetProgress computeBudgetProgress({
  required double spent,
  required double limit,
  double carryBalance = 0,
}) {
  if (limit <= 0) {
    return BudgetProgress(
      spent: spent,
      limit: limit,
      ratio: 0,
      level: BudgetProgressLevel.green,
      carryBalance: carryBalance,
    );
  }
  final ratio = spent / limit;
  final BudgetProgressLevel level;
  if (ratio < 0.7) {
    level = BudgetProgressLevel.green;
  } else if (ratio <= 1.0) {
    level = BudgetProgressLevel.orange;
  } else {
    level = BudgetProgressLevel.red;
  }
  return BudgetProgress(
    spent: spent,
    limit: limit,
    ratio: ratio,
    level: level,
    carryBalance: carryBalance,
  );
}

/// 计算预算"当前周期"的起止边界（半开区间 `[start, end)`）。
///
/// `monthly` 取 `now` 所在自然月；`yearly` 取 `now` 所在自然年。
///
/// **Step 6.4 起依赖此函数推进结转 anchor**——若周期定义需要改为"以
/// `Budget.startDate` 为锚的滚动周期"，必须同步改 [settleBudgetIfNeeded]
/// 的 anchor 步进逻辑，否则会与 UI 计算的"已花"区间不一致。
(DateTime, DateTime) budgetPeriodRange(String period, DateTime now) {
  if (period == 'yearly') {
    return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
  }
  return (
    DateTime(now.year, now.month, 1),
    DateTime(now.year, now.month + 1, 1),
  );
}

/// 给定周期 end，返回下一个周期的 end。
DateTime _nextPeriodEnd(String period, DateTime periodEnd) {
  if (period == 'yearly') {
    return DateTime(periodEnd.year + 1, 1, 1);
  }
  return DateTime(periodEnd.year, periodEnd.month + 1, 1);
}

/// 计算单个预算"当前周期"内已花金额。
///
/// 仅累加 `type == 'expense'`、`occurredAt ∈ [start, end)`、未软删
/// 且 `categoryId` 与预算匹配（总预算 `categoryId == null` 时不限分类）的流水。
double computePeriodSpent({
  required Budget budget,
  required List<TransactionEntry> transactions,
  required DateTime now,
}) {
  final (start, end) = budgetPeriodRange(budget.period, now);
  var total = 0.0;
  for (final tx in transactions) {
    if (tx.deletedAt != null) continue;
    if (tx.type != 'expense') continue;
    if (budget.categoryId != null && tx.categoryId != budget.categoryId) {
      continue;
    }
    final t = tx.occurredAt;
    if (t.isBefore(start)) continue;
    if (!t.isBefore(end)) continue;
    // Step 8.2：跨币种流水按 fxRate 折算到账本默认币种再累加；预算金额本身
    // 是账本默认币种，因此两侧单位一致。
    total += tx.amount * tx.fxRate;
  }
  return total;
}

/// 判定本次渲染是否需要触发"超预算"震动。
///
/// 真值条件：`level == red` 且当前会话尚未震动过该预算。把"决策"做成纯函数，
/// "执行"（HapticFeedback）留给调用方，便于单元测试覆盖"仅首次触发一次"。
bool shouldTriggerBudgetVibration({
  required BudgetProgressLevel level,
  required bool alreadyVibrated,
}) {
  return level == BudgetProgressLevel.red && !alreadyVibrated;
}

/// Step 6.4：懒结算函数。
///
/// 若 `budget.carryOver=false` → 直接返回原 budget（不改任何字段）。
/// 否则从 `budget.lastSettledAt`（或当前周期 start，若 null）向前推进周期，
/// 把每个**已完整结束**的周期的 `max(0, amount - spent)` 累加到 `carryBalance`，
/// 并把 `lastSettledAt` 推进到当前周期 start。
///
/// 关键约束：
/// - **不改 `updatedAt`**：结算只是派生数据维护，不应触发同步层 `updated_at`
///   的语义化变更。仓库层若需要落库，应另外把"业务 updated_at"传进来。
/// - **保守不补**：函数从 `lastSettledAt` 推进到当前周期 start 之间所有
///   完整结束的周期都累加，这与 [applyCarryOverToggle] 的"开启时把
///   anchor 重置为当前周期 start"配合，确保关闭期间的周期不会在重新开启
///   后被回溯——重新开启时 anchor 已重置，懒结算从那时刻起算。
Budget settleBudgetIfNeeded({
  required Budget budget,
  required List<TransactionEntry> transactions,
  required DateTime now,
}) {
  if (!budget.carryOver) return budget;

  final currentPeriodStart = budgetPeriodRange(budget.period, now).$1;
  // anchor 表示"已经结算到这个周期 end（含）"。null = 未结算，从当前周期 start
  // 起算，不回溯——这与 applyCarryOverToggle 给新建/重新开启写入的 anchor 等价。
  var anchor = budget.lastSettledAt ?? currentPeriodStart;
  if (!anchor.isBefore(currentPeriodStart)) {
    return budget;
  }

  var carryBalance = budget.carryBalance;
  // 找到 anchor 所在周期的 end，然后逐个推进。
  // 例：anchor = 2026-04-01（即 4 月 1 日 0:00），所在周期 end = 5/1。
  // 若 anchor 是上次结算后的 5/1，所在周期 = 5 月，end = 6/1，依此类推。
  var periodEnd = _nextPeriodEnd(budget.period, anchor);
  while (!periodEnd.isAfter(currentPeriodStart)) {
    // 累加 (anchor, periodEnd) 这个完整周期的剩余。
    final spent = _spentBetween(
      transactions: transactions,
      categoryId: budget.categoryId,
      start: anchor,
      end: periodEnd,
    );
    final remaining = budget.amount - spent;
    if (remaining > 0) {
      carryBalance += remaining;
    }
    anchor = periodEnd;
    periodEnd = _nextPeriodEnd(budget.period, anchor);
  }

  return budget.copyWith(
    carryBalance: carryBalance,
    lastSettledAt: anchor,
  );
}

double _spentBetween({
  required List<TransactionEntry> transactions,
  required String? categoryId,
  required DateTime start,
  required DateTime end,
}) {
  var total = 0.0;
  for (final tx in transactions) {
    if (tx.deletedAt != null) continue;
    if (tx.type != 'expense') continue;
    if (categoryId != null && tx.categoryId != categoryId) continue;
    final t = tx.occurredAt;
    if (t.isBefore(start)) continue;
    if (!t.isBefore(end)) continue;
    // Step 8.2：跨币种流水按 fxRate 折算到账本默认币种再累加。
    total += tx.amount * tx.fxRate;
  }
  return total;
}
