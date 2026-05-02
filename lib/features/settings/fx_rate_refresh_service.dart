import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/util/currencies.dart';
import '../../data/local/app_database.dart';

/// Step 8.3：汇率自动刷新与手动覆盖服务。
///
/// 设计要点（与 implementation-plan §8.3 对齐）：
/// 1. **每日最多刷新一次**：以 `user_pref.last_fx_refresh_at` 为节流锚点；
///    距上次成功刷新不足 [throttle]（默认 24h）时直接 return false，
///    不发起网络请求。`force=true` 绕过节流（"立即刷新"按钮场景）。
/// 2. **失败静默降级**：网络异常 / 解析异常 / 部分币种缺失全部 catch；
///    返回 false，不抛错，不修改 fx_rate 表。断网时记账不崩溃，使用现有
///    快照——这是验证 §8.3 的关键。
/// 3. **手动覆盖不被覆盖**：[setManualRate] 写入的行 `is_manual=1`；
///    [refreshIfDue] 拿到新汇率后用 [FxRateDao.setAutoRate]，DAO 内部
///    跳过 `is_manual=1` 的行。直到用户调 [resetToAuto] 清标记后，
///    下次刷新才能重写。
/// 4. **CNY 固定为 1.0**：服务层在写入前过滤掉 CNY；DAO 层不强制此约束，
///    但 seeder 已写 1.0、用户也无法在 UI 端手动修改 CNY（UI 禁用 CNY 行）。
class FxRateRefreshService {
  FxRateRefreshService({
    required AppDatabase db,
    FxRateFetcher? fetcher,
    DateTime Function()? clock,
    Duration throttle = const Duration(hours: 24),
  })  : _db = db,
        _fetcher = fetcher ?? defaultFxRateFetcher,
        _clock = clock ?? DateTime.now,
        _throttle = throttle;

  final AppDatabase _db;
  final FxRateFetcher _fetcher;
  final DateTime Function() _clock;
  final Duration _throttle;

  /// 受节流约束的刷新入口。返回是否真的发起了刷新并写入了至少一行。
  ///
  /// `force=true` 跳过节流检查（"立即刷新"按钮）。
  Future<bool> refreshIfDue({bool force = false}) async {
    final nowMs = _clock().millisecondsSinceEpoch;

    if (!force) {
      final last = await _readLastRefreshAt();
      if (last != null && nowMs - last < _throttle.inMilliseconds) {
        return false;
      }
    }

    final Map<String, double> fetched;
    try {
      fetched = await _fetcher();
    } catch (_) {
      return false;
    }

    if (fetched.isEmpty) return false;

    var anyWritten = false;
    for (final entry in fetched.entries) {
      final code = entry.key;
      final rate = entry.value;
      if (code == 'CNY') continue;
      if (!rate.isFinite || rate <= 0) continue;
      final affected = await _db.fxRateDao.setAutoRate(
        code: code,
        rateToCny: rate,
        updatedAt: nowMs,
      );
      if (affected > 0) anyWritten = true;
    }

    await _writeLastRefreshAt(nowMs);
    return anyWritten;
  }

  Future<void> setManualRate(String code, double rateToCny) async {
    if (code == 'CNY') {
      throw ArgumentError.value(code, 'code', 'CNY 是基准币种，不可手动覆盖');
    }
    if (!rateToCny.isFinite || rateToCny <= 0) {
      throw ArgumentError.value(rateToCny, 'rateToCny', '汇率必须为正数');
    }
    await _db.fxRateDao.setManualRate(
      code: code,
      rateToCny: rateToCny,
      updatedAt: _clock().millisecondsSinceEpoch,
    );
  }

  Future<void> resetToAuto(String code) async {
    await _db.fxRateDao.clearManualFlag(code);
  }

  Future<int?> _readLastRefreshAt() async {
    final pref = await (_db.select(_db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return pref?.lastFxRefreshAt;
  }

  Future<void> _writeLastRefreshAt(int epochMs) async {
    await (_db.update(_db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(lastFxRefreshAt: Value(epochMs)),
    );
  }
}

/// `Future<Map<code, rate_to_cny>>` 的工厂签名。返回空 Map / 抛异常都视为失败，
/// 由服务层 catch 并静默降级到现有快照。
typedef FxRateFetcher = Future<Map<String, double>> Function();

/// 默认 fetcher——使用 open.er-api.com 免费汇率 API（无 API key）。
///
/// 该 API 返回 `1 base = X target`，base=CNY 时 `rates['USD']` 表示
/// `1 CNY = X USD`，需要倒数得到 `rate_to_cny[USD] = 1 / X`。
///
/// 仅返回 [kBuiltInCurrencies] 中的币种，CNY 自身排除（基准固定 1.0）。
Future<Map<String, double>> defaultFxRateFetcher() async {
  final uri = Uri.parse('https://open.er-api.com/v6/latest/CNY');
  final resp = await http.get(uri).timeout(const Duration(seconds: 10));
  if (resp.statusCode != 200) {
    throw http.ClientException(
      'fx api status ${resp.statusCode}',
      uri,
    );
  }
  final data = jsonDecode(resp.body) as Map<String, dynamic>;
  if (data['result'] != 'success') {
    throw FormatException('fx api result != success: ${data['result']}');
  }
  final rates = data['rates'];
  if (rates is! Map) throw const FormatException('fx api missing rates');

  final out = <String, double>{};
  for (final c in kBuiltInCurrencies) {
    if (c.code == 'CNY') continue;
    final raw = rates[c.code];
    if (raw is! num) continue;
    final perCny = raw.toDouble();
    if (perCny <= 0 || !perCny.isFinite) continue;
    out[c.code] = 1.0 / perCny;
  }
  return out;
}
