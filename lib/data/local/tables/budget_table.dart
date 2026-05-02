import 'package:drift/drift.dart';

/// 对应 design-document §7.1 的 `budget` 表——预算。
///
/// `period` 取值 `monthly` | `yearly`；`category_id` 为 `null` 表示"总预算"
/// （该账本该周期的总盘子，而非任一分类）。`carry_over = 1` 时月末结算把本月未
/// 花完的额度累加到下月（Phase 6 的 Step 6.4 落地）。
@DataClassName('BudgetEntry')
class BudgetTable extends Table {
  @override
  String get tableName => 'budget';

  TextColumn get id => text()();

  TextColumn get ledgerId => text().named('ledger_id')();

  TextColumn get period => text()();

  TextColumn get categoryId => text().nullable().named('category_id')();

  RealColumn get amount => real()();

  IntColumn get carryOver => integer()
      .named('carry_over')
      .nullable()
      .withDefault(const Constant(0))();

  /// Step 6.4 引入的"已结转余额"。每次跨周期触发懒结算时，把上一周期未花完
  /// 的额度（`max(0, amount - spent)`）累加到这里；预算进度 UI 把它叠加到
  /// `amount` 上展示"本期可用"。
  RealColumn get carryBalance => real()
      .named('carry_balance')
      .withDefault(const Constant(0))();

  /// Step 6.4 引入的"已结算到的周期 end（epoch ms）"。`null` 表示还从未结算过。
  /// 结算函数从这里向 `now` 推进，关闭→重新开启时由 `applyCarryOverToggle`
  /// 重置为当前周期开始，从而满足"重新打开不回溯历史"的约束。
  IntColumn get lastSettledAt => integer().nullable().named('last_settled_at')();

  IntColumn get startDate => integer().named('start_date')();

  IntColumn get updatedAt => integer().named('updated_at')();

  IntColumn get deletedAt => integer().nullable().named('deleted_at')();

  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}
