import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/budget.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/budget/budget_progress.dart';

void main() {
  group('computeBudgetProgress', () {
    test('< 70% → green', () {
      final p = computeBudgetProgress(spent: 690, limit: 1000);
      expect(p.ratio, closeTo(0.69, 1e-9));
      expect(p.level, BudgetProgressLevel.green);
    });

    test('exactly 70% → orange', () {
      final p = computeBudgetProgress(spent: 700, limit: 1000);
      expect(p.ratio, closeTo(0.7, 1e-9));
      expect(p.level, BudgetProgressLevel.orange);
    });

    test('between 70% and 100% → orange', () {
      final p = computeBudgetProgress(spent: 850, limit: 1000);
      expect(p.level, BudgetProgressLevel.orange);
    });

    test('exactly 100% → orange', () {
      final p = computeBudgetProgress(spent: 1000, limit: 1000);
      expect(p.ratio, closeTo(1.0, 1e-9));
      expect(p.level, BudgetProgressLevel.orange);
    });

    test('100.01% → red', () {
      final p = computeBudgetProgress(spent: 1000.10, limit: 1000);
      expect(p.ratio, greaterThan(1.0));
      expect(p.level, BudgetProgressLevel.red);
    });

    test('limit <= 0 → green with ratio 0', () {
      final p = computeBudgetProgress(spent: 100, limit: 0);
      expect(p.ratio, 0);
      expect(p.level, BudgetProgressLevel.green);
    });

    test('spent = 0 → green', () {
      final p = computeBudgetProgress(spent: 0, limit: 1000);
      expect(p.ratio, 0);
      expect(p.level, BudgetProgressLevel.green);
    });
  });

  group('budgetPeriodRange', () {
    test('monthly: now in 2026-04 → [2026-04-01, 2026-05-01)', () {
      final (start, end) = budgetPeriodRange(
        'monthly',
        DateTime(2026, 4, 15, 8, 30),
      );
      expect(start, DateTime(2026, 4, 1));
      expect(end, DateTime(2026, 5, 1));
    });

    test('monthly: December rolls over to next year', () {
      final (start, end) = budgetPeriodRange('monthly', DateTime(2026, 12, 9));
      expect(start, DateTime(2026, 12, 1));
      expect(end, DateTime(2027, 1, 1));
    });

    test('yearly: now in 2026-04 → [2026-01-01, 2027-01-01)', () {
      final (start, end) = budgetPeriodRange('yearly', DateTime(2026, 4, 15));
      expect(start, DateTime(2026, 1, 1));
      expect(end, DateTime(2027, 1, 1));
    });
  });

  group('computePeriodSpent', () {
    final now = DateTime(2026, 4, 15, 12);

    Budget makeBudget({String? categoryId, String period = 'monthly'}) {
      return Budget(
        id: 'b-1',
        ledgerId: 'led-1',
        period: period,
        categoryId: categoryId,
        amount: 1000,
        startDate: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
        deviceId: 'dev',
      );
    }

    TransactionEntry makeTx({
      String id = 'tx',
      String type = 'expense',
      double amount = 100,
      String? categoryId = 'cat-1',
      DateTime? occurredAt,
      DateTime? deletedAt,
      String ledgerId = 'led-1',
    }) {
      return TransactionEntry(
        id: id,
        ledgerId: ledgerId,
        type: type,
        amount: amount,
        currency: 'CNY',
        categoryId: categoryId,
        occurredAt: occurredAt ?? DateTime(2026, 4, 10),
        updatedAt: DateTime(2026, 4, 10),
        deletedAt: deletedAt,
        deviceId: 'dev',
      );
    }

    test('总预算累加当前月所有 expense', () {
      final spent = computePeriodSpent(
        budget: makeBudget(),
        transactions: [
          makeTx(id: 'a', amount: 100),
          makeTx(id: 'b', amount: 200, categoryId: 'cat-2'),
          makeTx(
            id: 'c',
            amount: 50,
            occurredAt: DateTime(2026, 3, 20), // 上月
          ),
          makeTx(id: 'd', amount: 80, type: 'income'),
          makeTx(id: 'e', amount: 30, type: 'transfer'),
          makeTx(id: 'f', amount: 70, deletedAt: DateTime(2026, 4, 11)),
        ],
        now: now,
      );
      expect(spent, 300);
    });

    test('分类预算只累加该 categoryId 的 expense', () {
      final spent = computePeriodSpent(
        budget: makeBudget(categoryId: 'cat-1'),
        transactions: [
          makeTx(id: 'a', amount: 100, categoryId: 'cat-1'),
          makeTx(id: 'b', amount: 200, categoryId: 'cat-2'),
          makeTx(id: 'c', amount: 30, categoryId: null),
        ],
        now: now,
      );
      expect(spent, 100);
    });

    test('yearly 预算累加全年 expense', () {
      final spent = computePeriodSpent(
        budget: makeBudget(period: 'yearly'),
        transactions: [
          makeTx(id: 'a', amount: 100, occurredAt: DateTime(2026, 1, 5)),
          makeTx(id: 'b', amount: 200, occurredAt: DateTime(2026, 12, 31, 23)),
          makeTx(id: 'c', amount: 50, occurredAt: DateTime(2025, 12, 31, 23)),
          makeTx(id: 'd', amount: 80, occurredAt: DateTime(2027, 1, 1)),
        ],
        now: now,
      );
      expect(spent, 300);
    });
  });

  group('shouldTriggerBudgetVibration', () {
    test('green / orange 不触发震动', () {
      expect(
        shouldTriggerBudgetVibration(
          level: BudgetProgressLevel.green,
          alreadyVibrated: false,
        ),
        isFalse,
      );
      expect(
        shouldTriggerBudgetVibration(
          level: BudgetProgressLevel.orange,
          alreadyVibrated: false,
        ),
        isFalse,
      );
    });

    test('red 且本会话尚未震动 → 触发', () {
      expect(
        shouldTriggerBudgetVibration(
          level: BudgetProgressLevel.red,
          alreadyVibrated: false,
        ),
        isTrue,
      );
    });

    test('red 但本会话已震动过 → 不再触发（仅首次震动一次）', () {
      expect(
        shouldTriggerBudgetVibration(
          level: BudgetProgressLevel.red,
          alreadyVibrated: true,
        ),
        isFalse,
      );
    });
  });
}
