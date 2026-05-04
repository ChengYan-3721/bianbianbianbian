import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/budget.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/domain/usecase/budget_carry_over.dart';
import 'package:bianbianbianbian/features/budget/budget_progress.dart';

Budget _makeBudget({
  required String id,
  String period = 'monthly',
  double amount = 1000,
  bool carryOver = false,
  double carryBalance = 0,
  DateTime? lastSettledAt,
  DateTime? startDate,
  String? categoryId,
}) {
  final start = startDate ?? DateTime(2026, 4, 1);
  return Budget(
    id: id,
    ledgerId: 'ledger-1',
    period: period,
    categoryId: categoryId,
    amount: amount,
    carryOver: carryOver,
    carryBalance: carryBalance,
    lastSettledAt: lastSettledAt,
    startDate: start,
    updatedAt: start,
    deviceId: 'test-device',
  );
}

TransactionEntry _expense({
  required String id,
  required DateTime occurredAt,
  required double amount,
  String? categoryId,
}) {
  return TransactionEntry(
    id: id,
    ledgerId: 'ledger-1',
    type: 'expense',
    amount: amount,
    currency: 'CNY',
    categoryId: categoryId,
    occurredAt: occurredAt,
    updatedAt: occurredAt,
    deviceId: 'test-device',
  );
}

void main() {
  group('applyCarryOverToggle - 新建', () {
    test('carryOver=true：lastSettledAt = startDate 所在周期 start（默认本月）',
        () {
      final next = _makeBudget(
        id: 'b',
        carryOver: true,
        startDate: DateTime(2026, 5, 1),
      );
      final result = applyCarryOverToggle(
        prev: null,
        next: next,
        now: DateTime(2026, 5, 15, 14),
      );
      expect(result.lastSettledAt, DateTime(2026, 5, 1));
      expect(result.carryBalance, 0);
    });

    test('carryOver=true + startDate=上月 → 允许"补记"上月剩余的回溯', () {
      // 5/15 创建预算，但 startDate 选 4/1 → anchor=4/1，
      // 让 settle 在 5/15 调用时能结算 4 月已完结的周期。
      final next = _makeBudget(
        id: 'b',
        carryOver: true,
        startDate: DateTime(2026, 4, 1),
      );
      final result = applyCarryOverToggle(
        prev: null,
        next: next,
        now: DateTime(2026, 5, 15),
      );
      expect(result.lastSettledAt, DateTime(2026, 4, 1));
      expect(result.carryBalance, 0);
    });

    test('carryOver=false → lastSettledAt=null, carryBalance=0', () {
      final next = _makeBudget(id: 'b', carryOver: false);
      final result = applyCarryOverToggle(
        prev: null,
        next: next,
        now: DateTime(2026, 5, 15),
      );
      expect(result.lastSettledAt, isNull);
      expect(result.carryBalance, 0);
    });

    test('yearly + carryOver=true → lastSettledAt=startDate 所在年 1/1', () {
      final next = _makeBudget(
        id: 'b',
        period: 'yearly',
        carryOver: true,
        startDate: DateTime(2026, 4, 1),
      );
      final result = applyCarryOverToggle(
        prev: null,
        next: next,
        now: DateTime(2026, 8, 20),
      );
      expect(result.lastSettledAt, DateTime(2026, 1, 1));
    });
  });

  group('applyCarryOverToggle - 编辑', () {
    test('false → true：anchor 重置为当前周期 start，carryBalance 沿用 prev', () {
      final prev = _makeBudget(
        id: 'b',
        carryOver: false,
        carryBalance: 350,
        lastSettledAt: null,
      );
      final next = _makeBudget(
        id: 'b',
        carryOver: true,
        carryBalance: 0, // UI 没传，会被 toggle 覆盖
        lastSettledAt: null,
      );
      final result = applyCarryOverToggle(
        prev: prev,
        next: next,
        now: DateTime(2026, 5, 15),
      );
      expect(result.lastSettledAt, DateTime(2026, 5, 1));
      expect(result.carryBalance, 350);
    });

    test('true → false：carryBalance/lastSettledAt 一律继承 prev（不清零）', () {
      final prev = _makeBudget(
        id: 'b',
        carryOver: true,
        carryBalance: 200,
        lastSettledAt: DateTime(2026, 4, 1),
      );
      final next = _makeBudget(
        id: 'b',
        carryOver: false,
        carryBalance: 0,
        lastSettledAt: null,
      );
      final result = applyCarryOverToggle(
        prev: prev,
        next: next,
        now: DateTime(2026, 5, 15),
      );
      expect(result.carryBalance, 200);
      expect(result.lastSettledAt, DateTime(2026, 4, 1));
    });

    test('true → true（仅改金额）：carryBalance/lastSettledAt 都继承 prev', () {
      final prev = _makeBudget(
        id: 'b',
        carryOver: true,
        carryBalance: 100,
        lastSettledAt: DateTime(2026, 5, 1),
      );
      final next = _makeBudget(
        id: 'b',
        carryOver: true,
        amount: 1500,
        carryBalance: 0,
        lastSettledAt: null,
      );
      final result = applyCarryOverToggle(
        prev: prev,
        next: next,
        now: DateTime(2026, 5, 20),
      );
      expect(result.carryBalance, 100);
      expect(result.lastSettledAt, DateTime(2026, 5, 1));
      expect(result.amount, 1500);
    });
  });

  group('settleBudgetIfNeeded - 不结算路径', () {
    test('carryOver=false → 原 budget 直接返回', () {
      final budget = _makeBudget(
        id: 'b',
        carryOver: false,
        carryBalance: 999,
        lastSettledAt: DateTime(2026, 1, 1),
      );
      final result = settleBudgetIfNeeded(
        budget: budget,
        transactions: const [],
        now: DateTime(2026, 12, 1),
      );
      expect(result, same(budget));
    });

    test('lastSettledAt 已经是当前周期 start → 不结算', () {
      final budget = _makeBudget(
        id: 'b',
        carryOver: true,
        lastSettledAt: DateTime(2026, 5, 1),
      );
      final result = settleBudgetIfNeeded(
        budget: budget,
        transactions: const [],
        now: DateTime(2026, 5, 20),
      );
      expect(result, same(budget));
    });
  });

  group('settleBudgetIfNeeded - 周期结算', () {
    test('上月预算 1000 花 800，本月触发结算 → carryBalance=200', () {
      final budget = _makeBudget(
        id: 'b',
        carryOver: true,
        amount: 1000,
        lastSettledAt: DateTime(2026, 4, 1),
      );
      final txs = [
        _expense(id: 't1', occurredAt: DateTime(2026, 4, 10), amount: 500),
        _expense(id: 't2', occurredAt: DateTime(2026, 4, 25), amount: 300),
      ];
      final result = settleBudgetIfNeeded(
        budget: budget,
        transactions: txs,
        now: DateTime(2026, 5, 15),
      );
      expect(result.carryBalance, 200);
      expect(result.lastSettledAt, DateTime(2026, 5, 1));
    });

    test('上月超预算（花 1500）→ carryBalance 不变（不允许负结转）', () {
      final budget = _makeBudget(
        id: 'b',
        carryOver: true,
        amount: 1000,
        lastSettledAt: DateTime(2026, 4, 1),
      );
      final txs = [
        _expense(id: 't1', occurredAt: DateTime(2026, 4, 10), amount: 1500),
      ];
      final result = settleBudgetIfNeeded(
        budget: budget,
        transactions: txs,
        now: DateTime(2026, 5, 15),
      );
      expect(result.carryBalance, 0);
      expect(result.lastSettledAt, DateTime(2026, 5, 1));
    });

    test('跨两个完整周期：carryBalance 累加各周期剩余', () {
      // anchor=3/1, current period start=5/1 → 结算 3 月 + 4 月
      final budget = _makeBudget(
        id: 'b',
        carryOver: true,
        amount: 1000,
        lastSettledAt: DateTime(2026, 3, 1),
      );
      final txs = [
        _expense(id: 't1', occurredAt: DateTime(2026, 3, 10), amount: 800),
        _expense(id: 't2', occurredAt: DateTime(2026, 4, 10), amount: 700),
      ];
      final result = settleBudgetIfNeeded(
        budget: budget,
        transactions: txs,
        now: DateTime(2026, 5, 15),
      );
      // 3 月剩 200 + 4 月剩 300 = 500
      expect(result.carryBalance, 500);
      expect(result.lastSettledAt, DateTime(2026, 5, 1));
    });

    test('已有 carryBalance 时累加，而非覆盖', () {
      final budget = _makeBudget(
        id: 'b',
        carryOver: true,
        amount: 1000,
        carryBalance: 50, // 之前累积的
        lastSettledAt: DateTime(2026, 4, 1),
      );
      final txs = [
        _expense(id: 't1', occurredAt: DateTime(2026, 4, 10), amount: 800),
      ];
      final result = settleBudgetIfNeeded(
        budget: budget,
        transactions: txs,
        now: DateTime(2026, 5, 15),
      );
      expect(result.carryBalance, 250); // 50 + 200
    });

    test('分类预算只统计该分类的支出', () {
      final budget = _makeBudget(
        id: 'b',
        carryOver: true,
        amount: 1000,
        categoryId: 'cat-food',
        lastSettledAt: DateTime(2026, 4, 1),
      );
      final txs = [
        _expense(
          id: 't1',
          occurredAt: DateTime(2026, 4, 10),
          amount: 300,
          categoryId: 'cat-food',
        ),
        _expense(
          id: 't2',
          occurredAt: DateTime(2026, 4, 11),
          amount: 200,
          categoryId: 'cat-shop', // 别的分类——不计
        ),
      ];
      final result = settleBudgetIfNeeded(
        budget: budget,
        transactions: txs,
        now: DateTime(2026, 5, 15),
      );
      // 食物 4 月只花 300，剩 700
      expect(result.carryBalance, 700);
    });
  });

  group('Step 6.4 验收场景', () {
    test('上月剩 200，本月预算 1000 + 结转 200 → 本月可用 1200', () {
      // 模拟"5 月初进入预算页"——上月 (4 月) 用 800/1000，结转 200。
      final budget = _makeBudget(
        id: 'b',
        carryOver: true,
        amount: 1000,
        carryBalance: 0,
        lastSettledAt: DateTime(2026, 4, 1),
      );
      final txs = [
        _expense(id: 't1', occurredAt: DateTime(2026, 4, 10), amount: 800),
      ];
      final settled = settleBudgetIfNeeded(
        budget: budget,
        transactions: txs,
        now: DateTime(2026, 5, 1),
      );
      expect(settled.carryBalance, 200);

      // "本月可用" = amount + carryBalance = 1200
      final available =
          settled.amount + (settled.carryOver ? settled.carryBalance : 0);
      expect(available, 1200);
    });

    test('关闭结转重新打开，不回溯历史（只影响开启后的月份）', () {
      // 时间线：
      // - 4/1：用户首次创建预算，carryOver=true。
      // - 4 月：花 800（未结算，因为还在当月）。
      // - 5/1：用户关闭 carryOver。预期：4 月剩余的 200 不应该被结转。
      // - 5 月：花 600。
      // - 6/1：用户重新打开 carryOver。预期：anchor 重置到 6/1，4 月与 5 月
      //   的剩余都不被回溯到 carryBalance。
      // - 6 月：花 100。
      // - 7/1：触发懒结算。预期：仅 6 月（开启后）剩余 900 被加到 carryBalance。

      final txs = [
        _expense(id: 't1', occurredAt: DateTime(2026, 4, 10), amount: 800),
        _expense(id: 't2', occurredAt: DateTime(2026, 5, 10), amount: 600),
        _expense(id: 't3', occurredAt: DateTime(2026, 6, 10), amount: 100),
      ];

      // (1) 4/1 创建：carryOver=true → applyCarryOverToggle(null, ...,
      //     now=4/1) → lastSettledAt=4/1, carryBalance=0
      final initial = _makeBudget(id: 'b', carryOver: true, amount: 1000);
      final created = applyCarryOverToggle(
        prev: null,
        next: initial,
        now: DateTime(2026, 4, 1),
      );
      expect(created.lastSettledAt, DateTime(2026, 4, 1));
      expect(created.carryBalance, 0);

      // (2) 5/1 关闭：carryOver=true → false。继承 prev 的
      //     carryBalance=0、lastSettledAt=4/1（保留）。
      final closed = applyCarryOverToggle(
        prev: created,
        next: created.copyWith(carryOver: false),
        now: DateTime(2026, 5, 1),
      );
      expect(closed.carryOver, isFalse);
      expect(closed.carryBalance, 0);
      // 此时若有人尝试 settle，应直接 short-circuit（carryOver=false）。
      final settledWhileClosed = settleBudgetIfNeeded(
        budget: closed,
        transactions: txs,
        now: DateTime(2026, 5, 31),
      );
      expect(settledWhileClosed, same(closed));

      // (3) 6/1 重新打开：carryOver=false → true。anchor 重置到当前周期
      //     start=6/1。carryBalance 仍继承 prev=0。
      final reopened = applyCarryOverToggle(
        prev: closed,
        next: closed.copyWith(carryOver: true),
        now: DateTime(2026, 6, 1),
      );
      expect(reopened.carryOver, isTrue);
      expect(reopened.lastSettledAt, DateTime(2026, 6, 1));
      expect(reopened.carryBalance, 0);

      // (4) 7/1 懒结算：anchor=6/1, currentPeriodStart=7/1 →
      //     仅结算 6 月：剩余 1000-100=900。
      final finalSettled = settleBudgetIfNeeded(
        budget: reopened,
        transactions: txs,
        now: DateTime(2026, 7, 1),
      );
      expect(finalSettled.carryBalance, 900);
      expect(finalSettled.lastSettledAt, DateTime(2026, 7, 1));
      // 关键验收：4 月剩 200 与 5 月剩 400 都没被回溯。
    });
  });
}
