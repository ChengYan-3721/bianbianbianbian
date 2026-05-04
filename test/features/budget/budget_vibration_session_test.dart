import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/features/budget/budget_providers.dart';

void main() {
  group('BudgetVibrationSession', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(budgetVibrationSessionProvider);
      expect(state, isEmpty);
    });

    test('markVibrated adds id and hasVibrated returns true', () {
      final notifier = container.read(
        budgetVibrationSessionProvider.notifier,
      );
      expect(notifier.hasVibrated('b-1'), isFalse);
      notifier.markVibrated('b-1');
      expect(notifier.hasVibrated('b-1'), isTrue);
      expect(container.read(budgetVibrationSessionProvider), {'b-1'});
    });

    test('markVibrated 同一 id 多次调用是幂等的（state 引用不变）', () {
      final notifier = container.read(
        budgetVibrationSessionProvider.notifier,
      );
      notifier.markVibrated('b-1');
      final firstSnapshot = container.read(budgetVibrationSessionProvider);
      notifier.markVibrated('b-1');
      final secondSnapshot = container.read(budgetVibrationSessionProvider);
      expect(secondSnapshot.length, 1);
      expect(identical(firstSnapshot, secondSnapshot), isTrue,
          reason: '重复 markVibrated 不应重建 state，避免不必要的 rebuild');
    });

    test('多个 budgetId 各自独立标记', () {
      final notifier = container.read(
        budgetVibrationSessionProvider.notifier,
      );
      notifier.markVibrated('b-1');
      notifier.markVibrated('b-2');
      expect(notifier.hasVibrated('b-1'), isTrue);
      expect(notifier.hasVibrated('b-2'), isTrue);
      expect(notifier.hasVibrated('b-3'), isFalse);
      expect(container.read(budgetVibrationSessionProvider).length, 2);
    });

    test('clear 移除指定 id', () {
      final notifier = container.read(
        budgetVibrationSessionProvider.notifier,
      );
      notifier.markVibrated('b-1');
      notifier.markVibrated('b-2');
      notifier.clear('b-1');
      expect(notifier.hasVibrated('b-1'), isFalse);
      expect(notifier.hasVibrated('b-2'), isTrue);
    });
  });
}
