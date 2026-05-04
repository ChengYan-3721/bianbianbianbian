import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/budget.dart';
import 'package:bianbianbianbian/features/budget/budget_providers.dart';

Budget _makeBudget({
  required String id,
  required String period,
  String? categoryId,
  double amount = 1000,
}) {
  return Budget(
    id: id,
    ledgerId: 'ledger-1',
    period: period,
    categoryId: categoryId,
    amount: amount,
    carryOver: false,
    startDate: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 4, 1),
    deviceId: 'test-device',
  );
}

ProviderContainer _containerWith(List<Budget> budgets) {
  return ProviderContainer(overrides: [
    activeBudgetsProvider.overrideWith((ref) async => budgets),
  ]);
}

void main() {
  group('totalBudgetProvider', () {
    test('无总预算时返回 null', () async {
      final container = _containerWith([
        _makeBudget(id: 'b-1', period: 'monthly', categoryId: 'cat-food'),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(totalBudgetProvider.future);
      expect(result, isNull);
    });

    test('同时存在月度与年度总预算时优先返回月度', () async {
      final monthly = _makeBudget(id: 'b-month', period: 'monthly');
      final yearly = _makeBudget(id: 'b-year', period: 'yearly');
      // 故意把 yearly 排在前面，验证不是简单取 first。
      final container = _containerWith([yearly, monthly]);
      addTearDown(container.dispose);

      final result = await container.read(totalBudgetProvider.future);
      expect(result?.id, 'b-month');
    });

    test('仅有年度总预算时回退到年度', () async {
      final container = _containerWith([
        _makeBudget(id: 'b-year', period: 'yearly'),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(totalBudgetProvider.future);
      expect(result?.id, 'b-year');
    });

    test('忽略分类预算（categoryId != null）', () async {
      final container = _containerWith([
        _makeBudget(id: 'b-cat', period: 'monthly', categoryId: 'cat-food'),
        _makeBudget(id: 'b-cat-yearly', period: 'yearly', categoryId: 'cat-food'),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(totalBudgetProvider.future);
      expect(result, isNull);
    });

    test('混合分类预算与总预算时只挑总预算', () async {
      final container = _containerWith([
        _makeBudget(id: 'b-cat', period: 'monthly', categoryId: 'cat-food'),
        _makeBudget(id: 'b-total-month', period: 'monthly'),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(totalBudgetProvider.future);
      expect(result?.id, 'b-total-month');
    });
  });
}
