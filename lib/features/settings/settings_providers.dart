import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/app_theme.dart';
import '../../core/util/category_icon_packs.dart';
import '../../data/local/app_database.dart';
import '../../data/local/providers.dart';
import '../../data/repository/providers.dart';
import 'fx_rate_refresh_service.dart';

part 'settings_providers.g.dart';

/// Step 15.1：当前主题标识 provider。
///
/// 数据源是 `user_pref.theme`（TEXT，默认 `'cream_bunny'`）。
/// UI 通过 `ref.watch(currentThemeKeyProvider)` 拿字符串 key 供
/// [currentThemeProvider] 消费。
@Riverpod(keepAlive: true)
class CurrentThemeKey extends _$CurrentThemeKey {
  @override
  Future<String> build() async {
    final db = ref.watch(appDatabaseProvider);
    final pref = await (db.select(db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return pref?.theme ?? 'cream_bunny';
  }

  /// 写入 user_pref.theme 并触发重建。
  Future<void> set(String themeKey) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(
        theme: Value(themeKey),
      ),
    );
    ref.invalidateSelf();
  }
}

/// Step 15.1：当前主题的 [ThemeData] provider。
///
/// 消费 [currentThemeKeyProvider] 后经 [BianBianTheme.fromKey] 枚举转换，
/// 再由 [buildAppTheme] 构建完整 [ThemeData]。[BianBianApp] 的
/// `MaterialApp.router.theme` 直接 watch 本 provider。
@Riverpod(keepAlive: true)
ThemeData currentTheme(Ref ref) {
  final themeKeyAsync = ref.watch(currentThemeKeyProvider);
  final key = themeKeyAsync.valueOrNull ?? 'cream_bunny';
  return buildAppTheme(BianBianTheme.fromKey(key));
}

/// Step 15.2：当前字号档位 provider。
///
/// 数据源是 `user_pref.font_size`（TEXT，默认 `'standard'`）。
/// UI 通过 `ref.watch(currentFontSizeKeyProvider)` 拿字符串 key 供
/// [fontSizeScaleFactorProvider] 消费。
@Riverpod(keepAlive: true)
class CurrentFontSizeKey extends _$CurrentFontSizeKey {
  @override
  Future<String> build() async {
    final db = ref.watch(appDatabaseProvider);
    final pref = await (db.select(db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return pref?.fontSize ?? 'standard';
  }

  /// 写入 user_pref.font_size 并触发重建。
  Future<void> set(String fontSizeKey) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(
        fontSize: Value(fontSizeKey),
      ),
    );
    ref.invalidateSelf();
  }
}

/// Step 15.2：字号缩放因子 provider。
///
/// 消费 [currentFontSizeKeyProvider] 后经 [BianBianFontSize.fromKey] 枚举转换，
/// 返回 [BianBianFontSize.scaleFactor]（0.85 / 1.0 / 1.15）。
/// [BianBianApp] 在 `MaterialApp.router.builder` 里乘以系统 TextScaler
/// 生成最终 [TextScaler]。
@Riverpod(keepAlive: true)
double fontSizeScaleFactor(Ref ref) {
  final keyAsync = ref.watch(currentFontSizeKeyProvider);
  final key = keyAsync.valueOrNull ?? 'standard';
  return BianBianFontSize.fromKey(key).scaleFactor;
}

/// Step 15.3：当前图标包标识 provider。
///
/// 数据源是 `user_pref.icon_pack`（TEXT，默认 `'sticker'`）。
@Riverpod(keepAlive: true)
class CurrentIconPackKey extends _$CurrentIconPackKey {
  @override
  Future<String> build() async {
    final db = ref.watch(appDatabaseProvider);
    final pref = await (db.select(db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return pref?.iconPack ?? 'sticker';
  }

  /// 写入 user_pref.icon_pack 并触发重建。
  Future<void> set(String iconPackKey) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(
        iconPack: Value(iconPackKey),
      ),
    );
    ref.invalidateSelf();
  }
}

/// Step 15.3：当前图标包枚举 provider。
///
/// 消费 [currentIconPackKeyProvider] 后经 [BianBianIconPack.fromKey] 枚举转换。
/// UI 与图标解析函数通过本 provider 获取激活的 [BianBianIconPack]。
@Riverpod(keepAlive: true)
BianBianIconPack currentIconPack(Ref ref) {
  final keyAsync = ref.watch(currentIconPackKeyProvider);
  final key = keyAsync.valueOrNull ?? 'sticker';
  return BianBianIconPack.fromKey(key);
}

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
