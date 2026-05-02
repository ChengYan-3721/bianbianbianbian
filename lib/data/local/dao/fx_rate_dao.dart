import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/fx_rate_table.dart';

part 'fx_rate_dao.g.dart';

/// `fx_rate` 表 DAO——工具表，不走 Step 1.4 的"业务表 4 方法"模式。
///
/// 公开方法：
/// - [listAll]：取全量快照（按 code 字典序），UI 用来渲染"我的 → 多币种"列表。
/// - [getByCode]：按 code 取单条，记账页/统计页换算时用。
/// - [upsert]：覆写或插入一条；Step 8.1 种子化都走它。
/// - [setAutoRate]：Step 8.3 自动刷新写入——只更新 `is_manual = 0` 的行
///   （手动覆盖的行被跳过）；返回受影响行数。CNY 自身永远 `is_manual = 0`，
///   服务层调用前应过滤掉 CNY 以避免覆写基准。
/// - [setManualRate]：Step 8.3 用户手动覆盖——upsert 一行并把 `is_manual`
///   置 1，自动刷新不会再覆盖此行，直到 [clearManualFlag] 清除标记。
/// - [clearManualFlag]：Step 8.3 重置——把 `is_manual` 置回 0，下次自动
///   刷新即可重新写入服务端值。汇率本身保持不变，避免短暂出现"无值"状态。
@DriftAccessor(tables: [FxRateTable])
class FxRateDao extends DatabaseAccessor<AppDatabase> with _$FxRateDaoMixin {
  FxRateDao(super.db);

  Future<List<FxRateEntry>> listAll() {
    return (select(fxRateTable)..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
  }

  Future<FxRateEntry?> getByCode(String code) {
    return (select(fxRateTable)..where((t) => t.code.equals(code)))
        .getSingleOrNull();
  }

  Future<void> upsert(FxRateTableCompanion entry) {
    return into(fxRateTable).insertOnConflictUpdate(entry);
  }

  /// Step 8.3：自动刷新单行汇率。仅当现存行 `is_manual = 0` 时更新；
  /// 不存在则插入（默认 `is_manual = 0`）。返回 1 表示已写入，0 表示
  /// 因手动覆盖而被跳过。
  Future<int> setAutoRate({
    required String code,
    required double rateToCny,
    required int updatedAt,
  }) async {
    final existing = await getByCode(code);
    if (existing == null) {
      await into(fxRateTable).insert(
        FxRateTableCompanion.insert(
          code: code,
          rateToCny: rateToCny,
          updatedAt: updatedAt,
        ),
      );
      return 1;
    }
    if (existing.isManual == 1) return 0;
    return (update(fxRateTable)..where((t) => t.code.equals(code))).write(
      FxRateTableCompanion(
        rateToCny: Value(rateToCny),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Step 8.3：用户手动覆盖。强制写入并把 `is_manual` 置 1。
  Future<void> setManualRate({
    required String code,
    required double rateToCny,
    required int updatedAt,
  }) {
    return into(fxRateTable).insertOnConflictUpdate(
      FxRateTableCompanion.insert(
        code: code,
        rateToCny: rateToCny,
        updatedAt: updatedAt,
        isManual: const Value(1),
      ),
    );
  }

  /// Step 8.3：把某行的 `is_manual` 置回 0；汇率保持原值，等待下次自动
  /// 刷新覆盖。若该行不存在则静默跳过。
  Future<int> clearManualFlag(String code) {
    return (update(fxRateTable)..where((t) => t.code.equals(code))).write(
      const FxRateTableCompanion(isManual: Value(0)),
    );
  }
}
