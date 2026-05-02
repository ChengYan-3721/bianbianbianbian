import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/local/app_database.dart';
import '../../data/local/providers.dart';
import '../../data/repository/providers.dart';
import 'fx_rate_refresh_service.dart';

part 'settings_providers.g.dart';

/// Step 8.1：多币种全局开关。
///
/// 数据源是 `user_pref.multi_currency_enabled`（v6 schema 新增）。
/// `0` / `null` 视为关闭，`1` 视为开启——与 [UserPrefTable] 的默认值一致。
///
/// 写路径走 [MultiCurrencyEnabled.set] 持久化后 `invalidateSelf()`，
/// UI 通过 `ref.watch(multiCurrencyEnabledProvider)` 自动响应。
@Riverpod(keepAlive: true)
class MultiCurrencyEnabled extends _$MultiCurrencyEnabled {
  @override
  Future<bool> build() async {
    final db = ref.watch(appDatabaseProvider);
    final pref = await (db.select(db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return pref?.multiCurrencyEnabled == 1;
  }

  /// 写入 user_pref 并触发重建。
  Future<void> set(bool enabled) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(
        multiCurrencyEnabled: Value(enabled ? 1 : 0),
      ),
    );
    ref.invalidateSelf();
  }
}

/// Step 8.2：当前账本的默认币种 code（如 `'CNY'` / `'USD'`）。
///
/// 依赖 [currentLedgerIdProvider] + [ledgerRepositoryProvider]：账本切换或
/// 账本本身被编辑时（Step 4.x ledger_edit_page 后会 invalidate ledgerRepositoryProvider），
/// 本 provider 会自动重新计算。读取失败兜底 `'CNY'`，与 design-document §7.1
/// `ledger.default_currency DEFAULT 'CNY'` 一致。
@Riverpod(keepAlive: true)
Future<String> currentLedgerDefaultCurrency(Ref ref) async {
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final ledgerRepo = await ref.watch(ledgerRepositoryProvider.future);
  final ledger = await ledgerRepo.getById(ledgerId);
  return ledger?.defaultCurrency ?? 'CNY';
}

/// Step 8.2：内置币种快照——`code → rate_to_cny`。
///
/// 直接 dump `fx_rate` 表（Step 8.1 种子化保证至少 11 行）。读路径走 [appDatabaseProvider]
/// 的 [FxRateDao.listAll]；UI 与保存时的换算函数都从这里取。Step 8.3 联网刷新或
/// 用户手动覆写后会 invalidate 本 provider。
@Riverpod(keepAlive: true)
Future<Map<String, double>> fxRates(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await db.fxRateDao.listAll();
  return {for (final row in rows) row.code: row.rateToCny};
}

/// Step 8.3：fx_rate 全量行（含 is_manual / updated_at），供"汇率管理"页渲染。
///
/// 与 [fxRates] 不同：[fxRates] 只暴露 code→rate（供换算），本 provider 暴露
/// 全字段（供 UI 渲染手动/自动徽章 + 更新时间）。
@Riverpod(keepAlive: true)
Future<List<FxRateEntry>> fxRateRows(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.fxRateDao.listAll();
}

/// Step 8.3：汇率刷新服务 provider。生产 fetcher 走 [defaultFxRateFetcher]
/// （open.er-api.com）；测试可 override 注入伪造 fetcher。
@Riverpod(keepAlive: true)
FxRateRefreshService fxRateRefreshService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return FxRateRefreshService(db: db);
}

/// Step 8.2：纯函数——根据 fx_rate 快照计算"源币种 → 账本默认币种"的换算因子。
///
/// 所有汇率以 CNY 为基准（[kFxRateSnapshot] 与 fx_rate.rate_to_cny 同语义）。
/// 因此 `from → to = ratesToCny[from] / ratesToCny[to]`：
/// - `from == to` → 1.0；
/// - 任一码缺失（理论不会，因 picker 只暴露 11 种内置码）→ 兜底 1.0，避免崩溃。
///
/// 例：USD → CNY 时 `7.20 / 1.0 = 7.20`；CNY → USD 时 `1.0 / 7.20 ≈ 0.1389`。
double computeFxRate(
  String from,
  String to,
  Map<String, double> ratesToCny,
) {
  if (from == to) return 1.0;
  final fromRate = ratesToCny[from];
  final toRate = ratesToCny[to];
  if (fromRate == null || toRate == null || toRate == 0) return 1.0;
  return fromRate / toRate;
}
