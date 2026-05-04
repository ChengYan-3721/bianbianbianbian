import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:bianbianbianbian/app/app.dart';
import 'package:bianbianbianbian/data/repository/account_repository.dart';
import 'package:bianbianbianbian/data/repository/ledger_repository.dart';
import 'package:bianbianbianbian/data/repository/providers.dart';
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/account/account_providers.dart';
import 'package:bianbianbianbian/features/record/record_providers.dart';
import 'package:bianbianbianbian/features/stats/stats_range_providers.dart';
import 'package:bianbianbianbian/features/budget/budget_providers.dart';

// ---- 假仓库 / 假 provider ----

class _TestCurrentLedgerId extends CurrentLedgerId {
  _TestCurrentLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
}

/// 固定月份的 RecordMonth，避免 widget 测试随真实日期跨月而 flaky。
class _FixedRecordMonth extends RecordMonth {
  _FixedRecordMonth(this._month);
  final DateTime _month;
  @override
  DateTime build() => _month;
}

class _FakeLedgerRepository implements LedgerRepository {
  _FakeLedgerRepository({this.ledger});

  final Ledger? ledger;

  @override
  Future<Ledger?> getById(String id) async => ledger;

  @override
  Future<List<Ledger>> listActive() async =>
      ledger == null ? [] : [ledger!];

  @override
  Future<Ledger> save(Ledger entity) => fail('FakeLedgerRepository.unsaved');

  @override
  Future<void> softDeleteById(String id) =>
      fail('FakeLedgerRepository.unsaved');

  @override
  Future<Ledger> setArchived(String id, bool archived) =>
      fail('FakeLedgerRepository.unsaved');

  @override
  Future<List<Ledger>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) => fail('FakeLedgerRepository.unsaved');
  @override
  Future<int> purgeById(String id) => fail('FakeLedgerRepository.unsaved');
  @override
  Future<int> purgeAllDeleted() => fail('FakeLedgerRepository.unsaved');
  @override
  Future<List<Ledger>> listExpired(DateTime cutoff) async => const [];
}

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository({this.transactions = const []});

  final List<TransactionEntry> transactions;

  @override
  Future<List<TransactionEntry>> listActiveByLedger(String ledgerId) async =>
      transactions;

  @override
  Future<TransactionEntry> save(TransactionEntry entity) =>
      fail('FakeTransactionRepository.unsaved');

  @override
  Future<void> softDeleteById(String id) =>
      fail('FakeTransactionRepository.unsaved');

  @override
  Future<int> softDeleteByLedgerId(String ledgerId) =>
      fail('FakeTransactionRepository.unsaved');

  @override
  Future<List<TransactionEntry>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) =>
      fail('FakeTransactionRepository.unsaved');
  @override
  Future<int> purgeById(String id) =>
      fail('FakeTransactionRepository.unsaved');
  @override
  Future<int> purgeAllDeleted() =>
      fail('FakeTransactionRepository.unsaved');
  @override
  Future<List<TransactionEntry>> listExpired(DateTime cutoff) async => const [];
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({this.accounts = const []});

  /// 可变字段——回归测试 `删除账户后流水副标题立即刷新` 用例需要在
  /// 运行中改变 listActive 的结果，并 invalidate `accountsListProvider`
  /// 模拟"用户在 /accounts 页删账户 → 返回首页流水立即刷新"。
  List<Account> accounts;

  @override
  Future<List<Account>> listActive() async => accounts;

  @override
  Future<Account?> getById(String id) async {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<Account> save(Account entity) =>
      fail('FakeAccountRepository.unsaved');

  @override
  Future<void> softDeleteById(String id) =>
      fail('FakeAccountRepository.unsaved');

  @override
  Future<List<Account>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) =>
      fail('FakeAccountRepository.unsaved');
  @override
  Future<int> purgeById(String id) =>
      fail('FakeAccountRepository.unsaved');
  @override
  Future<int> purgeAllDeleted() =>
      fail('FakeAccountRepository.unsaved');
  @override
  Future<List<Account>> listExpired(DateTime cutoff) async => const [];
}

// ---- 测试辅助 ----

Ledger _testLedger() => Ledger(
      id: const Uuid().v4(),
      name: '测试账本',
      coverEmoji: '📒',
      defaultCurrency: 'CNY',
      archived: false,
      createdAt: DateTime.utc(2026, 4),
      updatedAt: DateTime.utc(2026, 4),
      deviceId: 'test-device',
    );

List<Override> _standardOverrides() {
  final fakeLedger = _FakeLedgerRepository(ledger: _testLedger());
  final fakeTx = _FakeTransactionRepository();
  return [
    currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId('test-ledger-id')),
    recordMonthProvider.overrideWith(() => _FixedRecordMonth(DateTime(2026, 4))),
    ledgerRepositoryProvider.overrideWith((ref) async => fakeLedger),
    transactionRepositoryProvider.overrideWith((ref) async => fakeTx),
    // 空流水 → 月度汇总三卡全零 + 空状态引导
    recordMonthSummaryProvider
        .overrideWith((ref) async => RecordMonthSummary(
              month: DateTime(2026, 4),
              income: 0,
              expense: 0,
              dailyGroups: [],
            )),
    statsLinePointsProvider.overrideWith((ref) async => []),
    statsPieSlicesProvider.overrideWith((ref) async => []),
    statsRankItemsProvider.overrideWith((ref) async => []),
    statsHeatmapCellsProvider.overrideWith((ref) async => []),
    // 无总预算时进度环隐藏；防止 _CategoryPieCard 触达真实 DB。
    activeBudgetsProvider.overrideWith((ref) async => []),
  ];
}

void main() {
  testWidgets('HomeShell renders all 4 bottom-nav tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _standardOverrides(),
        child: const BianBianApp(enableSyncLifecycle: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('记账'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('账本'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('BottomNavigationBar background is cream yellow #FFE9B0',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _standardOverrides(),
        child: const BianBianApp(enableSyncLifecycle: false),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    final theme = Theme.of(
      tester.element(find.byType(BottomNavigationBar)),
    );
    final bgColor = bar.backgroundColor ??
        theme.bottomNavigationBarTheme.backgroundColor;
    expect(bgColor, const Color(0xFFFFF9EF));
  });

  testWidgets('Tapping "统计" tab switches body text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _standardOverrides(),
        child: const BianBianApp(enableSyncLifecycle: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();

    expect(find.text('统计分析'), findsOneWidget);
    expect(find.text('本月'), findsOneWidget);
    expect(find.text('上月'), findsOneWidget);
    expect(find.text('本年'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
  });

  /// Step 3.1 验证：渲染首页，无数据时显示空状态引导。
  testWidgets('记账 Tab 无数据时显示空状态引导', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _standardOverrides(),
        child: const BianBianApp(enableSyncLifecycle: false),
      ),
    );
    await tester.pumpAndSettle();

    // 顶栏显示账本名与 emoji
    expect(find.text('测试账本'), findsOneWidget);
    expect(find.text('📒'), findsOneWidget);

    // 月份栏显示当月
    expect(find.text('2026年4月'), findsOneWidget);

    // 数据卡片三标签
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('结余'), findsOneWidget);

    // 快捷输入条
    expect(find.text('识别'), findsOneWidget);

    // 无流水时显示空状态引导
    expect(find.text('开始记第一笔吧 🐰'), findsOneWidget);

    // FAB 存在
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  /// Step 3.1 验证：有 mock 数据时流水列表按天分组。
  testWidgets('有 mock 数据时流水列表按天分组', (tester) async {
    final tx1 = TransactionEntry(
      id: 'tx-1',
      ledgerId: 'test-ledger-id',
      type: 'expense',
      amount: 30,
      currency: 'CNY',
      occurredAt: DateTime(2026, 4, 25, 12, 0),
      updatedAt: DateTime(2026, 4, 25),
      deviceId: 'test-device',
    );
    final tx2 = TransactionEntry(
      id: 'tx-2',
      ledgerId: 'test-ledger-id',
      type: 'income',
      amount: 100,
      currency: 'CNY',
      occurredAt: DateTime(2026, 4, 24, 18, 0),
      updatedAt: DateTime(2026, 4, 24),
      deviceId: 'test-device',
    );
    final fakeLedger = _FakeLedgerRepository(ledger: _testLedger());
    final fakeTx = _FakeTransactionRepository(transactions: [tx1, tx2]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
              currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId('test-ledger-id')),
          recordMonthProvider.overrideWith(() => _FixedRecordMonth(DateTime(2026, 4))),
          ledgerRepositoryProvider.overrideWith((ref) async => fakeLedger),
          transactionRepositoryProvider.overrideWith((ref) async => fakeTx),
          statsLinePointsProvider.overrideWith((ref) async => []),
          statsPieSlicesProvider.overrideWith((ref) async => []),
          statsRankItemsProvider.overrideWith((ref) async => []),
          statsHeatmapCellsProvider.overrideWith((ref) async => []),
          activeBudgetsProvider.overrideWith((ref) async => []),
        ],
        child: const BianBianApp(enableSyncLifecycle: false),
      ),
    );
    await tester.pumpAndSettle();

    // 分组日期 header
    expect(find.textContaining('4月25日'), findsOneWidget);
    expect(find.textContaining('4月24日'), findsOneWidget);

    // 金额显示
    expect(find.text('-¥30.00'), findsOneWidget);
    expect(find.text('+¥100.00'), findsOneWidget);

    // 数据卡片有值
    expect(find.text('¥100.00'), findsOneWidget); // income
    expect(find.text('¥30.00'), findsOneWidget);  // expense
    // balance = 100 - 30 = 70
    expect(find.text('¥70.00'), findsOneWidget);
  });

  /// Step 7.2 验收：删除账户后，首页流水（含转账）显示"（已删账户）"
  /// 占位且不崩溃。
  testWidgets('删除账户后转账流水显示"（已删账户）"占位', (tester) async {
    final transferTx = TransactionEntry(
      id: 'tx-transfer-1',
      ledgerId: 'test-ledger-id',
      type: 'transfer',
      // 这两个 accountId 在仓库 listActive 结果里都不存在 → 视为"已删"。
      accountId: 'deleted-account-out',
      toAccountId: 'deleted-account-in',
      amount: 200,
      currency: 'CNY',
      occurredAt: DateTime(2026, 4, 25, 10, 0),
      updatedAt: DateTime(2026, 4, 25),
      deviceId: 'test-device',
    );
    final fakeLedger = _FakeLedgerRepository(ledger: _testLedger());
    final fakeTx = _FakeTransactionRepository(transactions: [transferTx]);
    // 模拟"两个账户均已被软删" → listActive 返回空列表。
    final fakeAccount = _FakeAccountRepository(accounts: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLedgerIdProvider.overrideWith(
            () => _TestCurrentLedgerId('test-ledger-id'),
          ),
          recordMonthProvider.overrideWith(
            () => _FixedRecordMonth(DateTime(2026, 4)),
          ),
          ledgerRepositoryProvider.overrideWith((ref) async => fakeLedger),
          transactionRepositoryProvider.overrideWith((ref) async => fakeTx),
          accountRepositoryProvider.overrideWith((ref) async => fakeAccount),
          statsLinePointsProvider.overrideWith((ref) async => []),
          statsPieSlicesProvider.overrideWith((ref) async => []),
          statsRankItemsProvider.overrideWith((ref) async => []),
          statsHeatmapCellsProvider.overrideWith((ref) async => []),
          activeBudgetsProvider.overrideWith((ref) async => []),
        ],
        child: const BianBianApp(enableSyncLifecycle: false),
      ),
    );
    await tester.pumpAndSettle();

    // 转账流水副标题应显示 "（已删账户） → （已删账户）"，
    // 一行同时出现两次"（已删账户）"——textContaining 匹配应为 1 处。
    expect(
      find.textContaining('（已删账户） → （已删账户）'),
      findsOneWidget,
    );

    // 转账金额仍正常渲染（未崩溃）。
    expect(find.text('¥200.00'), findsOneWidget);
  });

  /// Step 7.2 修复回归：删除账户后流水副标题**立即**刷新——不再依赖
  /// 切换账本来强制重建。
  ///
  /// 复现路径：删除账户时只 invalidate `accountsListProvider`；
  /// 修复前 `_TxTile` 走 `accountRepositoryProvider` + FutureBuilder，
  /// 仓库实例不变 → tile 不重建 → 缓存的账户列表保持陈旧。
  /// 修复后 `_TxTile` 直接 `ref.watch(accountsListProvider)` →
  /// invalidate 立即触发 tile 重建。
  testWidgets('删除账户后流水副标题立即刷新（无需切换账本）', (tester) async {
    final acc = Account(
      id: 'acc-out',
      name: '工商卡',
      type: 'debit',
      updatedAt: DateTime(2026, 4),
      deviceId: 'test-device',
    );
    final accIn = Account(
      id: 'acc-in',
      name: '招商卡',
      type: 'debit',
      updatedAt: DateTime(2026, 4),
      deviceId: 'test-device',
    );
    final transferTx = TransactionEntry(
      id: 'tx-transfer-2',
      ledgerId: 'test-ledger-id',
      type: 'transfer',
      accountId: 'acc-out',
      toAccountId: 'acc-in',
      amount: 500,
      currency: 'CNY',
      occurredAt: DateTime(2026, 4, 25, 10, 0),
      updatedAt: DateTime(2026, 4, 25),
      deviceId: 'test-device',
    );

    final fakeLedger = _FakeLedgerRepository(ledger: _testLedger());
    final fakeTx = _FakeTransactionRepository(transactions: [transferTx]);
    // 用可变 fake：先暴露两个活跃账户。
    final fakeAccount = _FakeAccountRepository(accounts: [acc, accIn]);

    final container = ProviderContainer(
      overrides: [
        currentLedgerIdProvider.overrideWith(
          () => _TestCurrentLedgerId('test-ledger-id'),
        ),
        recordMonthProvider.overrideWith(
          () => _FixedRecordMonth(DateTime(2026, 4)),
        ),
        ledgerRepositoryProvider.overrideWith((ref) async => fakeLedger),
        transactionRepositoryProvider.overrideWith((ref) async => fakeTx),
        accountRepositoryProvider.overrideWith((ref) async => fakeAccount),
        statsLinePointsProvider.overrideWith((ref) async => []),
        statsPieSlicesProvider.overrideWith((ref) async => []),
        statsRankItemsProvider.overrideWith((ref) async => []),
        statsHeatmapCellsProvider.overrideWith((ref) async => []),
        activeBudgetsProvider.overrideWith((ref) async => []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BianBianApp(enableSyncLifecycle: false),
      ),
    );
    await tester.pumpAndSettle();

    // 初始态：副标题展示真实账户名。
    expect(find.textContaining('工商卡 → 招商卡'), findsOneWidget);
    expect(find.textContaining('（已删账户）'), findsNothing);

    // 模拟"用户在 /accounts 页软删 acc-out + acc-in"——只改变 fake 状态
    // 并 invalidate `accountsListProvider`，**不**碰 `recordMonthSummary`。
    fakeAccount.accounts = const [];
    container.invalidate(accountsListProvider);
    await tester.pumpAndSettle();

    // 验收：副标题立即刷新为占位。
    expect(find.textContaining('（已删账户） → （已删账户）'), findsOneWidget);
    expect(find.textContaining('工商卡 → 招商卡'), findsNothing);
  });
}
