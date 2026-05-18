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

  group('computeAssetsAndLiabilities', () {
    test('空账户返回 0/0', () {
      final r = computeAssetsAndLiabilities(
        accounts: const [],
        transactions: const [],
      );
      expect(r.assets, 0);
      expect(r.liabilities, 0);
    });

    test('正余额计入资产、负余额取绝对值计入负债', () {
      final accs = [
        _account(id: 'A', name: '现金', initialBalance: 1000),
        _account(id: 'B', name: '储蓄卡', initialBalance: 500),
        _account(
          id: 'C',
          name: '信用卡',
          type: 'credit',
          initialBalance: -300,
        ),
      ];
      final r = computeAssetsAndLiabilities(
        accounts: accs,
        transactions: const [],
      );
      expect(r.assets, 1500);
      expect(r.liabilities, 300);
      // 净资产恒等于 totalAssets
      expect(
        r.assets - r.liabilities,
        computeTotalAssets(accounts: accs, transactions: const []),
      );
    });

    test('includeInTotal=false 的账户既不计资产也不计负债', () {
      final accs = [
        _account(id: 'A', name: '现金', initialBalance: 1000),
        _account(
          id: 'C',
          name: '隐藏信用卡',
          type: 'credit',
          initialBalance: -300,
          includeInTotal: false,
        ),
      ];
      final r = computeAssetsAndLiabilities(
        accounts: accs,
        transactions: const [],
      );
      expect(r.assets, 1000);
      expect(r.liabilities, 0);
    });

    test('流水使账户跨越正负边界后会切换计入桶', () {
      final accs = [
        _account(id: 'A', name: '现金', initialBalance: 100),
      ];
      final txs = [
        _tx(id: 't1', type: 'expense', amount: 250, accountId: 'A'),
      ];
      final r = computeAssetsAndLiabilities(
        accounts: accs,
        transactions: txs,
      );
      // 100 - 250 = -150 → 负债 150,资产 0
      expect(r.assets, 0);
      expect(r.liabilities, 150);
    });
  });

  group('computeAccountYearDetail', () {
    test('空流水返回 12 个零月份', () {
      final r = computeAccountYearDetail(
        accountId: 'A',
        year: 2026,
        transactions: const [],
      );
      expect(r.year, 2026);
      expect(r.yearInflow, 0);
      expect(r.yearOutflow, 0);
      expect(r.months.length, 12);
      expect(r.months.every((m) => m.transactions.isEmpty), isTrue);
    });

    test('income 流水进本账户=流入；expense 出本账户=流出', () {
      final txs = [
        _tx(
          id: 't1',
          type: 'income',
          amount: 100,
          accountId: 'A',
          occurredAt: DateTime(2026, 5, 10),
        ),
        _tx(
          id: 't2',
          type: 'expense',
          amount: 30,
          accountId: 'A',
          occurredAt: DateTime(2026, 5, 11),
        ),
      ];
      final r = computeAccountYearDetail(
        accountId: 'A',
        year: 2026,
        transactions: txs,
      );
      expect(r.yearInflow, 100);
      expect(r.yearOutflow, 30);
      final may = r.months.firstWhere((m) => m.month == 5);
      expect(may.inflow, 100);
      expect(may.outflow, 30);
      expect(may.transactions.length, 2);
    });

    test('transfer 双向：转入本账户=流入；转出本账户=流出', () {
      final txs = [
        _tx(
          id: 't1',
          type: 'transfer',
          amount: 200,
          accountId: 'A',
          toAccountId: 'B',
          occurredAt: DateTime(2026, 3, 15),
        ),
        _tx(
          id: 't2',
          type: 'transfer',
          amount: 50,
          accountId: 'B',
          toAccountId: 'A',
          occurredAt: DateTime(2026, 3, 16),
        ),
      ];
      final rA = computeAccountYearDetail(
        accountId: 'A',
        year: 2026,
        transactions: txs,
      );
      expect(rA.yearOutflow, 200);
      expect(rA.yearInflow, 50);
      final marchA = rA.months.firstWhere((m) => m.month == 3);
      expect(marchA.outflow, 200);
      expect(marchA.inflow, 50);
      expect(marchA.transactions.length, 2);

      final rB = computeAccountYearDetail(
        accountId: 'B',
        year: 2026,
        transactions: txs,
      );
      expect(rB.yearInflow, 200);
      expect(rB.yearOutflow, 50);
    });

    test('与本账户无关的流水被忽略', () {
      final txs = [
        _tx(
          id: 't1',
          type: 'expense',
          amount: 30,
          accountId: 'X',
          occurredAt: DateTime(2026, 1, 1),
        ),
        _tx(
          id: 't2',
          type: 'transfer',
          amount: 50,
          accountId: 'X',
          toAccountId: 'Y',
          occurredAt: DateTime(2026, 2, 1),
        ),
      ];
      final r = computeAccountYearDetail(
        accountId: 'A',
        year: 2026,
        transactions: txs,
      );
      expect(r.yearInflow, 0);
      expect(r.yearOutflow, 0);
      expect(r.months.every((m) => m.transactions.isEmpty), isTrue);
    });

    test('非本年流水被忽略；软删流水被忽略', () {
      final txs = [
        _tx(
          id: 't1',
          type: 'income',
          amount: 100,
          accountId: 'A',
          occurredAt: DateTime(2025, 12, 31),
        ),
        _tx(
          id: 't2',
          type: 'expense',
          amount: 30,
          accountId: 'A',
          occurredAt: DateTime(2026, 4, 1),
          deletedAt: DateTime(2026, 4, 2),
        ),
      ];
      final r = computeAccountYearDetail(
        accountId: 'A',
        year: 2026,
        transactions: txs,
      );
      expect(r.yearInflow, 0);
      expect(r.yearOutflow, 0);
    });

    test('同月多条流水按 occurredAt 倒序', () {
      final txs = [
        _tx(
          id: 'early',
          type: 'expense',
          amount: 10,
          accountId: 'A',
          occurredAt: DateTime(2026, 5, 3, 9),
        ),
        _tx(
          id: 'late',
          type: 'expense',
          amount: 20,
          accountId: 'A',
          occurredAt: DateTime(2026, 5, 28, 18),
        ),
        _tx(
          id: 'mid',
          type: 'income',
          amount: 5,
          accountId: 'A',
          occurredAt: DateTime(2026, 5, 15, 12),
        ),
      ];
      final r = computeAccountYearDetail(
        accountId: 'A',
        year: 2026,
        transactions: txs,
      );
      final may = r.months.firstWhere((m) => m.month == 5);
      expect(may.transactions.map((t) => t.id).toList(),
          ['late', 'mid', 'early']);
    });
  });
}
