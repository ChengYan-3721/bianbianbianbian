import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/account/account_balance.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account({
  required String id,
  required String name,
  String type = 'cash',
  bool includeInTotal = true,
}) => Account(
  id: id,
  name: name,
  type: type,
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
}) => TransactionEntry(
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
    test('empty transactions returns empty map', () {
      expect(aggregateNetAmountsByAccount(const []), isEmpty);
    });

    test('expense subtracts from accountId', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'expense', amount: 30, accountId: 'A'),
      ]);
      expect(nets['A']?.original, -30);
      expect(nets['A']?.converted, -30);
    });

    test('income adds to accountId', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'income', amount: 100, accountId: 'A'),
      ]);
      expect(nets['A']?.original, 100);
      expect(nets['A']?.converted, 100);
    });

    test('transfer subtracts from source and adds to target', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(
          id: 't1',
          type: 'transfer',
          amount: 200,
          accountId: 'A',
          toAccountId: 'B',
        ),
      ]);
      expect(nets['A']?.original, -200);
      expect(nets['A']?.converted, -200);
      expect(nets['B']?.original, 200);
      expect(nets['B']?.converted, 200);
    });

    test('deleted transactions and empty account ids are ignored', () {
      final nets = aggregateNetAmountsByAccount([
        _tx(id: 't1', type: 'expense', amount: 30, accountId: 'A'),
        _tx(
          id: 't2',
          type: 'expense',
          amount: 999,
          accountId: 'A',
          deletedAt: DateTime(2026, 4, 26),
        ),
        _tx(id: 't3', type: 'income', amount: 50),
      ]);
      expect(nets['A']?.original, -30);
      expect(nets['A']?.converted, -30);
    });
  });

  group('computeAccountBalances', () {
    test('accounts without transactions have zero balance', () {
      final balances = computeAccountBalances(
        accounts: [
          _account(id: 'A', name: 'Cash'),
          _account(id: 'B', name: 'Card'),
        ],
        transactions: const [],
      );
      expect(balances.map((b) => b.currentBalance).toList(), [0, 0]);
    });

    test('keeps account order and applies transaction net amounts', () {
      final balances = computeAccountBalances(
        accounts: [
          _account(id: 'B', name: 'B'),
          _account(id: 'A', name: 'A'),
        ],
        transactions: [
          _tx(id: 't1', type: 'expense', amount: 30, accountId: 'A'),
          _tx(id: 't2', type: 'income', amount: 200, accountId: 'B'),
        ],
      );
      expect(balances.map((b) => b.accountId).toList(), ['B', 'A']);
      expect(balances.map((b) => b.currentBalance).toList(), [200, -30]);
    });
  });

  group('computeTotalAssets', () {
    test('sums only included accounts using transaction-derived balances', () {
      final accs = [
        _account(id: 'A', name: 'Cash'),
        _account(id: 'B', name: 'Hidden', includeInTotal: false),
        _account(id: 'C', name: 'Card', type: 'credit'),
      ];
      final txs = [
        _tx(id: 't1', type: 'income', amount: 1000, accountId: 'A'),
        _tx(id: 't2', type: 'income', amount: 500, accountId: 'B'),
        _tx(id: 't3', type: 'expense', amount: 300, accountId: 'C'),
      ];
      expect(computeTotalAssets(accounts: accs, transactions: txs), 700);
    });

    test('switching includeInTotal changes total assets', () {
      final accA = _account(id: 'A', name: 'Cash');
      final accB = _account(id: 'B', name: 'Bank');
      final txs = [
        _tx(id: 't1', type: 'income', amount: 50, accountId: 'A'),
        _tx(id: 't2', type: 'expense', amount: 30, accountId: 'B'),
      ];

      expect(computeTotalAssets(accounts: [accA, accB], transactions: txs), 20);
      expect(
        computeTotalAssets(
          accounts: [accA, accB.copyWith(includeInTotal: false)],
          transactions: txs,
        ),
        50,
      );
    });
  });

  group('computeAssetsAndLiabilities', () {
    test('splits positive and negative transaction-derived balances', () {
      final accs = [
        _account(id: 'A', name: 'Cash'),
        _account(id: 'B', name: 'Bank'),
        _account(id: 'C', name: 'Card', type: 'credit'),
      ];
      final txs = [
        _tx(id: 't1', type: 'income', amount: 1000, accountId: 'A'),
        _tx(id: 't2', type: 'income', amount: 500, accountId: 'B'),
        _tx(id: 't3', type: 'expense', amount: 300, accountId: 'C'),
      ];
      final r = computeAssetsAndLiabilities(accounts: accs, transactions: txs);
      expect(r.assets, 1500);
      expect(r.liabilities, 300);
      expect(
        r.assets - r.liabilities,
        computeTotalAssets(accounts: accs, transactions: txs),
      );
    });

    test('includeInTotal=false accounts do not affect either bucket', () {
      final r = computeAssetsAndLiabilities(
        accounts: [
          _account(id: 'A', name: 'Cash'),
          _account(id: 'C', name: 'Hidden card', includeInTotal: false),
        ],
        transactions: [
          _tx(id: 't1', type: 'income', amount: 1000, accountId: 'A'),
          _tx(id: 't2', type: 'expense', amount: 300, accountId: 'C'),
        ],
      );
      expect(r.assets, 1000);
      expect(r.liabilities, 0);
    });
  });

  group('computeAccountYearDetail', () {
    test('income/expense/transfer are grouped by year and month', () {
      final txs = [
        _tx(
          id: 'income',
          type: 'income',
          amount: 100,
          accountId: 'A',
          occurredAt: DateTime(2026, 5, 10),
        ),
        _tx(
          id: 'expense',
          type: 'expense',
          amount: 30,
          accountId: 'A',
          occurredAt: DateTime(2026, 5, 11),
        ),
        _tx(
          id: 'transfer-in',
          type: 'transfer',
          amount: 50,
          accountId: 'B',
          toAccountId: 'A',
          occurredAt: DateTime(2026, 5, 12),
        ),
      ];
      final r = computeAccountYearDetail(
        accountId: 'A',
        year: 2026,
        transactions: txs,
      );
      expect(r.yearInflow, 150);
      expect(r.yearOutflow, 30);
      final may = r.months.firstWhere((m) => m.month == 5);
      expect(may.inflow, 150);
      expect(may.outflow, 30);
      expect(may.transactions.map((t) => t.id).toList(), [
        'transfer-in',
        'expense',
        'income',
      ]);
    });

    test('unrelated, deleted, and out-of-year transactions are ignored', () {
      final r = computeAccountYearDetail(
        accountId: 'A',
        year: 2026,
        transactions: [
          _tx(id: 'x', type: 'expense', amount: 30, accountId: 'X'),
          _tx(
            id: 'old',
            type: 'income',
            amount: 100,
            accountId: 'A',
            occurredAt: DateTime(2025, 12, 31),
          ),
          _tx(
            id: 'deleted',
            type: 'expense',
            amount: 30,
            accountId: 'A',
            deletedAt: DateTime(2026, 4, 2),
          ),
        ],
      );
      expect(r.yearInflow, 0);
      expect(r.yearOutflow, 0);
      expect(r.months.every((m) => m.transactions.isEmpty), isTrue);
    });
  });
}
