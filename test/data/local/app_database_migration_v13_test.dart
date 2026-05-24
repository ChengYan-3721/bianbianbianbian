import 'dart:convert';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase schema v15 · account_order', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion == 15', () {
      // 防回归：bump 后没人改 schemaVersion 就会卡这条。
      expect(db.schemaVersion, 15);
    });

    test('新装库 user_pref.last_pulled_at_json 默认 null', () async {
      // onCreate 路径：createAll 必须把新列也建好，且默认 null（无 cursor =
      // 首次 pull 全量）。
      await db
          .into(db.userPrefTable)
          .insert(UserPrefTableCompanion.insert(deviceId: 'test-device-uuid'));

      final row = await db.select(db.userPrefTable).getSingle();
      expect(row.lastPulledAtJson, isNull);
    });

    test('写入 JSON 字符串后能完整 roundtrip', () async {
      // 业务侧 jsonEncode / jsonDecode 的最小契约：drift 把它当普通 TEXT
      // 存储，不解析内容。
      final cursors = <String, int>{
        'ledger': 1700000000000,
        'category': 1700000001234,
        'account': 1700000002345,
        'transaction_entry': 1700000003456,
        'budget': 1700000004567,
      };
      final encoded = jsonEncode(cursors);

      await db
          .into(db.userPrefTable)
          .insert(
            UserPrefTableCompanion.insert(
              deviceId: 'test-device-uuid',
              lastPulledAtJson: Value(encoded),
            ),
          );

      final row = await db.select(db.userPrefTable).getSingle();
      expect(row.lastPulledAtJson, encoded);
      final decoded = jsonDecode(row.lastPulledAtJson!) as Map<String, dynamic>;
      expect(decoded['ledger'], 1700000000000);
      expect(decoded['transaction_entry'], 1700000003456);
    });

    test('UPDATE 路径能把 null 改成有值再改回 null', () async {
      // 增量同步的运行时心跳——第一次 pull 后写入游标，重置同步状态时清空。
      await db
          .into(db.userPrefTable)
          .insert(UserPrefTableCompanion.insert(deviceId: 'test-device-uuid'));

      await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
        UserPrefTableCompanion(lastPulledAtJson: Value('{"ledger":100}')),
      );
      expect(
        (await db.select(db.userPrefTable).getSingle()).lastPulledAtJson,
        '{"ledger":100}',
      );

      await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
        const UserPrefTableCompanion(lastPulledAtJson: Value(null)),
      );
      expect(
        (await db.select(db.userPrefTable).getSingle()).lastPulledAtJson,
        isNull,
      );
    });

    test('新列不破坏既有 user_pref 行为（其他列默认值仍生效）', () async {
      // 防止迁移误覆盖其它列默认值。
      await db
          .into(db.userPrefTable)
          .insert(UserPrefTableCompanion.insert(deviceId: 'test-device-uuid'));
      final row = await db.select(db.userPrefTable).getSingle();
      expect(row.defaultCurrency, 'CNY');
      expect(row.theme, 'cream_bunny');
      expect(row.fontSize, 'standard');
      expect(row.iconPack, 'sticker');
      expect(row.reminderEnabled, 0);
      expect(row.reminderTime, isNull);
    });

    test('新装库 user_pref.account_order 默认 null', () async {
      // onCreate 路径：默认 null 表示余额倒序。
      await db
          .into(db.userPrefTable)
          .insert(UserPrefTableCompanion.insert(deviceId: 'test-device-uuid'));
      final row = await db.select(db.userPrefTable).getSingle();
      expect(row.accountOrder, isNull);
    });

    test('写入 account_order JSON 数组后能完整 roundtrip', () async {
      final order = ['acc-1', 'acc-2', 'acc-3'];
      final encoded = jsonEncode(order);

      await db
          .into(db.userPrefTable)
          .insert(
            UserPrefTableCompanion.insert(
              deviceId: 'test-device-uuid',
              accountOrder: Value(encoded),
            ),
          );

      final row = await db.select(db.userPrefTable).getSingle();
      expect(row.accountOrder, encoded);
      final decoded = (jsonDecode(row.accountOrder!) as List).cast<String>();
      expect(decoded, order);
    });

    test('UPDATE 路径能把 account_order null → 有值 → null', () async {
      await db
          .into(db.userPrefTable)
          .insert(UserPrefTableCompanion.insert(deviceId: 'test-device-uuid'));

      await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
        UserPrefTableCompanion(accountOrder: Value('["a","b"]')),
      );
      expect(
        (await db.select(db.userPrefTable).getSingle()).accountOrder,
        '["a","b"]',
      );

      await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
        const UserPrefTableCompanion(accountOrder: Value(null)),
      );
      expect(
        (await db.select(db.userPrefTable).getSingle()).accountOrder,
        isNull,
      );
    });
  });
}
