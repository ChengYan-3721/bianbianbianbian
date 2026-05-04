import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/features/settings/fx_rate_refresh_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 8.3：FxRateRefreshService 单元测试。
///
/// 覆盖：
/// 1. 节流：距上次刷新不足 24h 不再发起请求；force=true 绕过节流。
/// 2. 失败静默：fetcher 抛异常返回 false，不修改 fx_rate 表。
/// 3. 手动覆盖：is_manual=1 的行不被自动刷新覆盖；resetToAuto 后可被覆盖。
/// 4. CNY：服务层过滤掉 CNY，永远保持基准 1.0。
/// 5. setManualRate：参数校验 + 写入 + is_manual=1。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 初始化 user_pref 单行（CHECK(id=1) 限制）+ 11 种内置币种快照
    await db.into(db.userPrefTable).insert(
          UserPrefTableCompanion.insert(deviceId: 'device-test'),
        );
    for (final entry in {
      'CNY': 1.0,
      'USD': 7.20,
      'EUR': 7.85,
      'JPY': 0.048,
    }.entries) {
      await db.fxRateDao.upsert(
        FxRateTableCompanion.insert(
          code: entry.key,
          rateToCny: entry.value,
          updatedAt: 1700000000000,
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('refreshIfDue 节流', () {
    test('从未刷新时立即触发 fetcher', () async {
      var calls = 0;
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async {
          calls++;
          return {'USD': 7.30};
        },
      );

      final ok = await svc.refreshIfDue();
      expect(ok, true);
      expect(calls, 1);

      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 7.30);
      expect(usd.updatedAt, 1714000000000);

      final pref = await (db.select(db.userPrefTable)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(pref.lastFxRefreshAt, 1714000000000);
    });

    test('距上次刷新 < 24h 时跳过 fetcher', () async {
      var calls = 0;
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async {
          calls++;
          return {'USD': 7.30};
        },
      );
      // 第一次：建立 last_fx_refresh_at = 1714000000000
      await svc.refreshIfDue();
      expect(calls, 1);

      // 23h59m 后再次调用 → 节流跳过
      final svc2 = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(
          1714000000000 + const Duration(hours: 23, minutes: 59).inMilliseconds,
        ),
        fetcher: () async {
          calls++;
          return {'USD': 9.99};
        },
      );
      final ok = await svc2.refreshIfDue();
      expect(ok, false);
      expect(calls, 1, reason: 'fetcher 应被节流跳过');

      // USD 仍是第一次写入的值
      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 7.30);
    });

    test('距上次刷新 >= 24h 时再次触发', () async {
      var calls = 0;
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async {
          calls++;
          return {'USD': 7.30};
        },
      );
      await svc.refreshIfDue();

      final svc2 = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(
          1714000000000 + const Duration(hours: 24).inMilliseconds,
        ),
        fetcher: () async {
          calls++;
          return {'USD': 7.40};
        },
      );
      final ok = await svc2.refreshIfDue();
      expect(ok, true);
      expect(calls, 2);

      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 7.40);
    });

    test('force=true 绕过节流', () async {
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async => {'USD': 7.30},
      );
      await svc.refreshIfDue();

      var calls = 0;
      final svc2 = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async {
          calls++;
          return {'USD': 7.99};
        },
      );
      await svc2.refreshIfDue(force: true);
      expect(calls, 1);

      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 7.99);
    });
  });

  group('失败静默降级', () {
    test('fetcher 抛异常 → 返回 false，fx_rate 与 last_fx_refresh_at 都不变', () async {
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async => throw Exception('断网'),
      );

      final ok = await svc.refreshIfDue();
      expect(ok, false);

      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 7.20, reason: '原快照保持不变');
      expect(usd.updatedAt, 1700000000000);

      final pref = await (db.select(db.userPrefTable)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(pref.lastFxRefreshAt, isNull,
          reason: '失败不应推进 last_fx_refresh_at');
    });

    test('fetcher 返回空 Map → 返回 false', () async {
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async => {},
      );
      final ok = await svc.refreshIfDue();
      expect(ok, false);
    });

    test('fetcher 返回非有限/非正数 → 跳过该币种但不抛错', () async {
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async => {
          'USD': 7.30,
          'EUR': double.nan,
          'JPY': -0.05,
          'KRW': 0.0,
        },
      );
      final ok = await svc.refreshIfDue();
      expect(ok, true);

      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 7.30);

      final eur = await db.fxRateDao.getByCode('EUR');
      expect(eur!.rateToCny, 7.85, reason: 'EUR 保留旧快照');

      final jpy = await db.fxRateDao.getByCode('JPY');
      expect(jpy!.rateToCny, 0.048, reason: 'JPY 保留旧快照');
    });
  });

  group('手动覆盖与重置', () {
    test('is_manual=1 的行不被自动刷新覆盖', () async {
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async => {'USD': 7.30, 'EUR': 8.00},
      );

      // 用户手动设 USD = 6.50
      await svc.setManualRate('USD', 6.50);

      // 立即触发刷新（force 绕过节流）
      await svc.refreshIfDue(force: true);

      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 6.50, reason: 'USD 是手动值，不被覆盖');
      expect(usd.isManual, 1);

      final eur = await db.fxRateDao.getByCode('EUR');
      expect(eur!.rateToCny, 8.00, reason: 'EUR 自动行被刷新');
      expect(eur.isManual, 0);
    });

    test('resetToAuto 后下次自动刷新可以覆盖', () async {
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async => {'USD': 7.30},
      );

      await svc.setManualRate('USD', 6.50);
      await svc.refreshIfDue(force: true);
      expect(
        (await db.fxRateDao.getByCode('USD'))!.rateToCny,
        6.50,
      );

      // 用户重置为自动
      await svc.resetToAuto('USD');
      final cleared = await db.fxRateDao.getByCode('USD');
      expect(cleared!.isManual, 0);
      expect(cleared.rateToCny, 6.50, reason: '重置不抹掉值，等下次刷新覆盖');

      // 下一次 force 刷新 → 应被覆盖
      await svc.refreshIfDue(force: true);
      final after = await db.fxRateDao.getByCode('USD');
      expect(after!.rateToCny, 7.30);
      expect(after.isManual, 0);
    });

    test('CNY 在 fetcher 返回时被服务层过滤掉，保持 1.0', () async {
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
        fetcher: () async => {'CNY': 0.42, 'USD': 7.30},
      );
      await svc.refreshIfDue();

      final cny = await db.fxRateDao.getByCode('CNY');
      expect(cny!.rateToCny, 1.0);

      final usd = await db.fxRateDao.getByCode('USD');
      expect(usd!.rateToCny, 7.30);
    });

    test('setManualRate 拒绝 CNY', () async {
      final svc = FxRateRefreshService(db: db);
      expect(
        () => svc.setManualRate('CNY', 1.5),
        throwsArgumentError,
      );
    });

    test('setManualRate 拒绝非正数', () async {
      final svc = FxRateRefreshService(db: db);
      expect(
        () => svc.setManualRate('USD', 0),
        throwsArgumentError,
      );
      expect(
        () => svc.setManualRate('USD', -1.5),
        throwsArgumentError,
      );
      expect(
        () => svc.setManualRate('USD', double.nan),
        throwsArgumentError,
      );
    });

    test('setManualRate 写入新行（fx_rate 表中原本不存在 GBP）', () async {
      final svc = FxRateRefreshService(
        db: db,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1714000000000),
      );
      expect(await db.fxRateDao.getByCode('GBP'), isNull);

      await svc.setManualRate('GBP', 9.10);

      final gbp = await db.fxRateDao.getByCode('GBP');
      expect(gbp, isNotNull);
      expect(gbp!.rateToCny, 9.10);
      expect(gbp.isManual, 1);
      expect(gbp.updatedAt, 1714000000000);
    });
  });
}
