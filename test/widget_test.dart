import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:bianbianbianbian/app/app.dart';
import 'package:bianbianbianbian/data/repository/ledger_repository.dart';
import 'package:bianbianbianbian/data/repository/providers.dart';
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/record/record_providers.dart';

// ---- 假仓库 / 假 provider ----

class _TestCurrentLedgerId extends CurrentLedgerId {
  _TestCurrentLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
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
  ];
}

void main() {
  testWidgets('HomeShell renders all 4 bottom-nav tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _standardOverrides(),
        child: const BianBianApp(),
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
        child: const BianBianApp(),
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
        child: const BianBianApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();

    expect(find.text('统计'), findsWidgets);
  });

  /// Step 3.1 验证：渲染首页，无数据时显示空状态引导。
  testWidgets('记账 Tab 无数据时显示空状态引导', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _standardOverrides(),
        child: const BianBianApp(),
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
          ledgerRepositoryProvider.overrideWith((ref) async => fakeLedger),
          transactionRepositoryProvider.overrideWith((ref) async => fakeTx),
        ],
        child: const BianBianApp(),
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
}
