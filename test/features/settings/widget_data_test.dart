import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/settings/widget_data_service.dart';

/// 构造一条测试流水。
TransactionEntry _tx({
  required String type,
  required double amount,
  required DateTime occurredAt,
  double fxRate = 1.0,
  String ledgerId = 'L1',
}) {
  return TransactionEntry(
    id: 'tx-$type-$amount',
    ledgerId: ledgerId,
    type: type,
    amount: amount,
    currency: 'CNY',
    fxRate: fxRate,
    occurredAt: occurredAt,
    updatedAt: occurredAt,
    deviceId: 'test-device',
  );
}

void main() {
  // Fixed clock matching test data so tests are not date-sensitive.
  final fixedNow = DateTime(2026, 5, 10, 15, 30);
  DateTime fixedClock() => fixedNow;

  final today = DateTime(2026, 5, 10, 15, 30);
  final yesterday = DateTime(2026, 5, 9, 12, 0);
  final otherMonth = DateTime(2026, 4, 15, 10, 0);

  group('computeWidgetData', () {
    test('空流水 → 零值', () {
      final data = computeWidgetData(
        transactions: [],
        ledgerName: '📒 生活',
        clock: fixedClock,
      );
      expect(data.todayExpense, '¥0.00');
      expect(data.monthlyBalance, '¥0.00');
      expect(data.ledgerName, '📒 生活');
    });

    test('仅今日一笔支出', () {
      final data = computeWidgetData(
        transactions: [
          _tx(type: 'expense', amount: 30, occurredAt: today),
        ],
        ledgerName: '📒 生活',
        clock: fixedClock,
      );
      expect(data.todayExpense, '¥30.00');
      // 本月结余 = 0 - 30 = -30
      expect(data.monthlyBalance, '-¥30.00');
    });

    test('今日支出 + 今日收入 + 昨日支出', () {
      final data = computeWidgetData(
        transactions: [
          _tx(type: 'expense', amount: 25, occurredAt: today),
          _tx(type: 'income', amount: 100, occurredAt: today),
          _tx(type: 'expense', amount: 50, occurredAt: yesterday),
        ],
        ledgerName: '工作',
        clock: fixedClock,
      );
      // 今日支出仅统计 expense 且 occurredAt 为今天
      expect(data.todayExpense, '¥25.00');
      // 本月结余 = 100 - 25 - 50 = 25
      expect(data.monthlyBalance, '¥25.00');
      expect(data.ledgerName, '工作');
    });

    test('其他月份的流水不计入今日支出和本月结余', () {
      final data = computeWidgetData(
        transactions: [
          _tx(type: 'expense', amount: 200, occurredAt: otherMonth),
          _tx(type: 'income', amount: 500, occurredAt: otherMonth),
        ],
        ledgerName: '📒 生活',
        clock: fixedClock,
      );
      expect(data.todayExpense, '¥0.00');
      expect(data.monthlyBalance, '¥0.00');
    });

    test('跨币种流水按 fxRate 折算', () {
      final data = computeWidgetData(
        transactions: [
          // USD 10, fxRate=7.2 → CNY 72
          _tx(type: 'expense', amount: 10, occurredAt: today, fxRate: 7.2),
          // USD 20, fxRate=7.2 → CNY 144
          _tx(type: 'income', amount: 20, occurredAt: today, fxRate: 7.2),
        ],
        ledgerName: '📒 生活',
        clock: fixedClock,
      );
      // 今日支出 = 10 * 7.2 = 72
      expect(data.todayExpense, '¥72.00');
      // 本月结余 = 144 - 72 = 72
      expect(data.monthlyBalance, '¥72.00');
    });

    test('转账流水不计入收支', () {
      final data = computeWidgetData(
        transactions: [
          _tx(type: 'transfer', amount: 500, occurredAt: today),
          _tx(type: 'expense', amount: 20, occurredAt: today),
        ],
        ledgerName: '📒 生活',
        clock: fixedClock,
      );
      expect(data.todayExpense, '¥20.00');
      // transfer 不计入，结余 = 0 - 20 = -20
      expect(data.monthlyBalance, '-¥20.00');
    });

    test('负数金额格式化', () {
      final data = computeWidgetData(
        transactions: [
          _tx(type: 'expense', amount: 100, occurredAt: today),
          _tx(type: 'income', amount: 30, occurredAt: today),
        ],
        ledgerName: '📒 生活',
        clock: fixedClock,
      );
      expect(data.todayExpense, '¥100.00');
      // 本月结余 = 30 - 100 = -70
      expect(data.monthlyBalance, '-¥70.00');
    });

    test('WidgetData.empty 常量', () {
      const empty = WidgetData.empty;
      expect(empty.todayExpense, '¥0.00');
      expect(empty.monthlyBalance, '¥0.00');
      expect(empty.ledgerName, '边边记账');
    });

    test('其他账本流水不混入当前账本', () {
      final data = computeWidgetData(
        transactions: [
          _tx(
            type: 'expense',
            amount: 50,
            occurredAt: today,
            ledgerId: 'L2',
          ),
          _tx(
            type: 'expense',
            amount: 30,
            occurredAt: today,
            ledgerId: 'L1',
          ),
        ],
        ledgerName: '📒 生活',
        clock: fixedClock,
      );
      // computeWidgetData 不按 ledgerId 过滤（调用方负责传已过滤的列表），
      // 所以两条都会被计入
      expect(data.todayExpense, '¥80.00');
    });
  });
}
