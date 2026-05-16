import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/features/trash/trash_providers.dart';

void main() {
  group('trashDaysLeft', () {
    final now = DateTime.utc(2026, 5, 4, 12);

    test('刚删的项剩余 30 天', () {
      expect(
        trashDaysLeft(deletedAt: now, now: now),
        30,
      );
    });

    test('删了 1 天剩余 29 天', () {
      expect(
        trashDaysLeft(
          deletedAt: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        29,
      );
    });

    test('删了 29 天 23 小时仍显示 1 天（向上取整）', () {
      expect(
        trashDaysLeft(
          deletedAt: now.subtract(const Duration(days: 29, hours: 23)),
          now: now,
        ),
        1,
      );
    });

    test('刚好满 30 天：剩余 = 0（即将到期）', () {
      expect(
        trashDaysLeft(
          deletedAt: now.subtract(const Duration(days: 30)),
          now: now,
        ),
        0,
      );
    });

    test('超过 30 天：剩余 = 0（已过期，UI 不再显示）', () {
      expect(
        trashDaysLeft(
          deletedAt: now.subtract(const Duration(days: 45)),
          now: now,
        ),
        0,
      );
    });

    test('自定义保留窗口 7 天', () {
      expect(
        trashDaysLeft(
          deletedAt: now.subtract(const Duration(days: 3)),
          now: now,
          retention: const Duration(days: 7),
        ),
        4,
      );
    });

    test('未来 deletedAt（异常输入）：返回保留窗口上限', () {
      // 实际不会发生（deletedAt 总是 <= now），但函数对未来时间不崩溃。
      expect(
        trashDaysLeft(
          deletedAt: now.add(const Duration(days: 5)),
          now: now,
        ),
        35,
      );
    });
  });
}
