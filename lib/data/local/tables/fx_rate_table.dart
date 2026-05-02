import 'package:drift/drift.dart';

/// Step 8.1：汇率快照表。
///
/// 工具表，不是同步实体——没有 `updated_at` 之外的同步三件套
/// （`deleted_at` / `device_id` / `sync_op` 入队）。汇率属于"机器观察值"，
/// 开发者写死一次后由 Step 8.3 联网刷新覆盖；用户手动覆盖则**只对本机生效**。
///
/// 字段含义：
/// - [code]：ISO 4217 三字符代码（PK）。
/// - [rateToCny]：`1 单位该币种 == 多少 CNY`，即 design-document §5.7 的
///   "相对账本默认币种"以 CNY 为基准时的换算因子。
/// - [updatedAt]：最近更新时间（epoch ms）；UI 用来显示"汇率更新于 XX"。
/// - [isManual]：Step 8.3 引入。`1` = 用户在"我的 → 多币种 → 汇率管理"
///   手动覆盖；自动刷新会跳过此行。`0` = 由 Step 8.1 写死快照或 Step 8.3
///   联网刷新写入，可以被覆盖。`CNY` 永远保持 `rate=1.0` / `isManual=0`。
@DataClassName('FxRateEntry')
class FxRateTable extends Table {
  @override
  String get tableName => 'fx_rate';

  TextColumn get code => text()();

  RealColumn get rateToCny => real().named('rate_to_cny')();

  IntColumn get updatedAt => integer().named('updated_at')();

  IntColumn get isManual => integer()
      .named('is_manual')
      .withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {code};
}
