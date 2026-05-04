import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/account/account_balance.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account({
  required String id,
  required String name,
  String type = 'cash',
  double initialBalance = 0,
  bool includeInTotal = true,
}) =>
    Account(
      id: id,
      name: name,
      type: type,
      initialBalance: initialBalance,
      includeInTotal: includeInTotal,
      currency: 'CNY',
      updatedAt: DateTime(2026, 4, 1),
      deviceId: 'test-device',
    );

TransactionEntry _tx({
  required String id,
  required String type,
  required double amount,
  String? accountId,
  String? toAccountId,
  DateTime? deletedAt,
  DateTime? occurredAt,
}) =>
    TransactionEntry(
      id: id,
      ledgerId: 'L1',
      type: type,
      amount: amount,
      currency: 'CNY',
      accountId: accountId,
      toAccountId: toAccountId,
      occurredAt: occurredAt ?? DateTime(2026, 4, 25, 10),
      updatedAt: occurredAt ?? DateTime(2026, 4, 25, 10),
      deletedAt: deletedAt,
      deviceId: 'test-device',
    );

void main() {
  group('aggregateNetAmountsByAccount', () {
    test('空流水返回空 map', () {
      expect(aggregateNetAmountsByAccount(const []), isEmpty);
    });

    test('expense 流水从 accountId 扣除', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'expense', amount: 30, accountId: 'A'),
      ]);
      expect(nets, {'A': -30});
    });

    test('income 流水向 accountId 增加', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'income', amount: 100, accountId: 'A'),
      ]);
      expect(nets, {'A': 100});
    });

    test('transfer 流水双向流动（from 减、to 加）', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(
          id: 't1',
          type: 'transfer',
          amount: 200,
          accountId: 'A',
          toAccountId: 'B',
        ),
      ]);
      expect(nets, {'A': -200, 'B': 200});
    });

    test('多笔混合按账户聚合', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'expense', amount: 30, accountId: 'A'),
        _tx(id: 't2', type: 'income', amount: 200, accountId: 'A'),
        _tx(id: 't3', type: 'expense', amount: 50, accountId: 'B'),
        _tx(
          id: 't4',
          type: 'transfer',
          amount: 100,
          accountId: 'A',
          toAccountId: 'B',
        ),
      ]);
      expect(nets, {'A': -30 + 200 - 100, 'B': -50 + 100});
    });

    test('已软删流水被忽略', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'expense', amount: 30, accountId: 'A'),
        _tx(
          id: 't2',
          type: 'expense',
          amount: 999,
          accountId: 'A',
          deletedAt: DateTime(2026, 4, 26),
        ),
      ]);
      expect(nets, {'A': -30});
    });

    test('accountId 为 null 的非 transfer 流水被忽略', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'expense', amount: 30),
        _tx(id: 't2', type: 'income', amount: 50),
      ]);
      expect(nets, isEmpty);
    });

    test('transfer 流水 toAccountId 缺失时仅扣 from', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'transfer', amount: 80, accountId: 'A'),
      ]);
      expect(nets, {'A': -80});
    });
  });

  group('computeAccountBalances', () {
    test('未发生流水的账户 netAmount = 0、currentBalance = initialBalance', () {
      final accs = [
        _account(id: 'A', name: '现金', initialBalance: 100),
        _account(id: 'B', name: '信用卡', initialBalance: -200),
      ];
      final balances = computeAccountBalances(
        accounts: accs,
        transactions: const [],
      );
      expect(balances.length, 2);
      expect(balances[0].accountId, 'A');
      expect(balances[0].netAmount, 0);
      expect(balances[0].currentBalance, 100);
      expect(balances[1].accountId, 'B');
      expect(balances[1].currentBalance, -200);
    });

    test('保持 accounts 入参顺序', () {
      final accs = [
        _account(id: 'B', name: 'B'),
        _account(id: 'A', name: 'A'),
      ];
      final balances = computeAccountBalances(
        accounts: accs,
        transactions: const [],
      );
      expect(balances.map((b) => b.accountId).toList(), ['B', 'A']);
    });

    test('应用净额到对应账户', () {
      final accs = [
        _account(id: 'A', name: '现金', initialBalance: 100),
        _account(id: 'B', name: '储蓄卡', initialBalance: 500),
      ];
      final txs = [
        _tx(id: 't1', type: 'expense', amount: 30, accountId: 'A'),
        _tx(id: 't2', type: 'income', amount: 200, accountId: 'B'),
      ];
      final balances = computeAccountBalances(
        accounts: accs,
        transactions: txs,
      );
      expect(balances[0].currentBalance, 100 - 30);
      expect(balances[1].currentBalance, 500 + 200);
    });
  });

  group('computeTotalAssets', () {
    test('空账户返回 0', () {
      expect(
        computeTotalAssets(accounts: const [], transactions: const []),
        0,
      );
    });

    test('仅累加 includeInTotal=true 的账户', () {
      final accs = [
        _account(id: 'A', name: '现金', initialBalance: 100),
        _account(
          id: 'B',
          name: '小金库',
          initialBalance: 500,
          includeInTotal: false,
        ),
      ];
      expect(
        computeTotalAssets(accounts: accs, transactions: const []),
        100,
      );
    });

    test('信用卡负余额计入为减项', () {
      final accs = [
        _account(id: 'A', name: '现金', initialBalance: 1000),
        _account(
          id: 'C',
          name: '信用卡',
          type: 'credit',
          initialBalance: -300,
        ),
      ];
      expect(
        computeTotalAssets(accounts: accs, transactions: const []),
        700,
      );
    });

    test('叠加流水净额', () {
      final accs = [
        _account(id: 'A', name: '现金', initialBalance: 100),
        _account(id: 'B', name: '储蓄卡', initialBalance: 500),
      ];
      final txs = [
        _tx(id: 't1', type: 'expense', amount: 30, accountId: 'A'),
        _tx(id: 't2', type: 'income', amount: 200, accountId: 'B'),
        _tx(
          id: 't3',
          type: 'transfer',
          amount: 50,
          accountId: 'A',
          toAccountId: 'B',
        ),
      ];
      // A: 100 - 30 - 50 = 20; B: 500 + 200 + 50 = 750; total = 770
      expect(
        computeTotalAssets(accounts: accs, transactions: txs),
        770,
      );
    });

    /// implementation-plan Step 7.1 验收：切换 includeInTotal 后总资产数值
    /// 跟随变化。
    test('切换 includeInTotal 后总资产变化', () {
      final accA = _account(id: 'A', name: '现金', initialBalance: 100);
      final accB = _account(id: 'B', name: '储蓄卡', initialBalance: 200);
      final txs = [
        _tx(id: 't1', type: 'income', amount: 50, accountId: 'A'),
        _tx(id: 't2', type: 'expense', amount: 30, accountId: 'B'),
      ];

      // 全部计入：100+50 + 200-30 = 320
      final totalAll = computeTotalAssets(
        accounts: [accA, accB],
        transactions: txs,
      );
      expect(totalAll, 320);

      // B 不计入：仅 A 当前余额 = 150
      final totalOnlyA = computeTotalAssets(
        accounts: [accA, accB.copyWith(includeInTotal: false)],
        transactions: txs,
      );
      expect(totalOnlyA, 150);

      // 都不计入：0
      final totalNone = computeTotalAssets(
        accounts: [
          accA.copyWith(includeInTotal: false),
          accB.copyWith(includeInTotal: false),
        ],
        transactions: txs,
      );
      expect(totalNone, 0);
    });
  });
}
