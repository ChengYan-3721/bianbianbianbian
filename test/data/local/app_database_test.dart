import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase · user_pref', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('inserts user_pref(id=1) and reads it back with declared defaults',
        () async {
      // Step 1.1 验证点：新鲜库插入一行并完整读出；依赖 schema 的默认值。
      await db.into(db.userPrefTable).insert(
            UserPrefTableCompanion.insert(deviceId: 'test-device-uuid'),
          );

      final row = await db.select(db.userPrefTable).getSingle();

      expect(row.id, 1);
      expect(row.deviceId, 'test-device-uuid');
      expect(row.defaultCurrency, 'CNY');
      expect(row.theme, 'cream_bunny');
      expect(row.lockEnabled, 0);
      expect(row.syncEnabled, 0);
      expect(row.currentLedgerId, isNull);
      expect(row.lastSyncAt, isNull);
      expect(row.aiApiEndpoint, isNull);
      expect(row.aiApiKeyEncrypted, isNull);
    });

    test('CHECK (id = 1) 约束阻止第二行写入', () async {
      await db.into(db.userPrefTable).insert(
            UserPrefTableCompanion.insert(deviceId: 'device-a'),
          );

      // 显式指定 id=2 时，CHECK 约束必须拒绝。
      expect(
        () => db.into(db.userPrefTable).insert(
              UserPrefTableCompanion.insert(
                id: const Value(2),
                deviceId: 'device-b',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
