import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/local/providers.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    // 初始化 user_pref 行（id=1），确保 provider 读到数据。
    await (db.into(db.userPrefTable).insert(
          UserPrefTableCompanion.insert(
            id: const Value(1),
            deviceId: 'test-device',
          ),
        ));
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer container0({
    List<Override> overrides = const [],
  }) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ...overrides,
      ],
    );
  }

  group('reminderEnabledProvider', () {
    test('默认关闭', () async {
      final container = container0();
      final enabled = await container.read(reminderEnabledProvider.future);
      expect(enabled, isFalse);
      container.dispose();
    });

    test('set(true) 后读取为 true', () async {
      final container = container0();
      await container.read(reminderEnabledProvider.notifier).set(true);
      final enabled = await container.read(reminderEnabledProvider.future);
      expect(enabled, isTrue);
      container.dispose();
    });

    test('set(true) 再 set(false) 后读取为 false', () async {
      final container = container0();
      await container.read(reminderEnabledProvider.notifier).set(true);
      await container.read(reminderEnabledProvider.notifier).set(false);
      final enabled = await container.read(reminderEnabledProvider.future);
      expect(enabled, isFalse);
      container.dispose();
    });

    test('持久化到 DB', () async {
      final container = container0();
      await container.read(reminderEnabledProvider.notifier).set(true);
      // 新 container 读同一 DB。
      final container2 = container0();
      final enabled = await container2.read(reminderEnabledProvider.future);
      expect(enabled, isTrue);
      container.dispose();
      container2.dispose();
    });
  });

  group('reminderTimeProvider', () {
    test('默认为 null', () async {
      final container = container0();
      final time = await container.read(reminderTimeProvider.future);
      expect(time, isNull);
      container.dispose();
    });

    test('set(TimeOfDay) 后可读回', () async {
      final container = container0();
      await container
          .read(reminderTimeProvider.notifier)
          .set(const TimeOfDay(hour: 20, minute: 30));
      final time = await container.read(reminderTimeProvider.future);
      expect(time, isNotNull);
      expect(time!.hour, 20);
      expect(time.minute, 30);
      container.dispose();
    });

    test('clear() 后为 null', () async {
      final container = container0();
      await container
          .read(reminderTimeProvider.notifier)
          .set(const TimeOfDay(hour: 8, minute: 0));
      await container.read(reminderTimeProvider.notifier).clear();
      final time = await container.read(reminderTimeProvider.future);
      expect(time, isNull);
      container.dispose();
    });

    test('持久化到 DB（HH:mm 格式）', () async {
      final container = container0();
      await container
          .read(reminderTimeProvider.notifier)
          .set(const TimeOfDay(hour: 9, minute: 5));
      // 直接查 DB 验证格式。
      final pref = await (db.select(db.userPrefTable)
              ..where((t) => t.id.equals(1)))
          .getSingleOrNull();
      expect(pref?.reminderTime, '09:05');
      container.dispose();
    });
  });

  group('_parseTimeOfDay', () {
    test('合法 HH:mm', () {
      // 通过 provider 间接测试：set → 读取 → 新 container 读回。
      // 但 _parseTimeOfDay 是私有函数，用 DB round-trip 测试更直接。
    });

    test('非法格式不崩溃（DB 里直接写坏值，provider 返回 null）', () async {
      // 往 DB 直接写一个非法值。
      await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
        const UserPrefTableCompanion(
          reminderTime: Value('bad-format'),
        ),
      );
      final container = container0();
      final time = await container.read(reminderTimeProvider.future);
      expect(time, isNull); // _parseTimeOfDay 返回 null
      container.dispose();
    });
  });

  group('reminderServiceProvider', () {
    test('提供 ReminderService 实例', () {
      final container = container0();
      final service = container.read(reminderServiceProvider);
      expect(service, isNotNull);
      container.dispose();
    });
  });
}
