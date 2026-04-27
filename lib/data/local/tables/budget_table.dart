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

  IntColumn get startDate => integer().named('start_date')();

  IntColumn get updatedAt => integer().named('updated_at')();

  IntColumn get deletedAt => integer().nullable().named('deleted_at')();

  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}
