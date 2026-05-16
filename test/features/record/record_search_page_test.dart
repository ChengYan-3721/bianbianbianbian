/// Step 3.6 widget 测试：流水搜索页 `/record/search`。
///
/// 覆盖以下关键路径：
/// - 空查询：进入页面不返回任何结果，显示"输入条件开始搜索"提示；
/// - 关键词命中：输入"午餐"后，备注为"和同事的午餐"的流水出现在结果列表；
/// - 空结果：输入不存在的关键词，列表为空 + 显示"没有找到相关流水"；
/// - 点击结果：弹出详情底部表单，可触发复制 / 编辑 / 删除三个动作；
/// - 删除路径：在详情中点删除 → 二次确认 → 列表中该流水消失。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/data/repository/account_repository.dart';
import 'package:bianbianbianbian/data/repository/category_repository.dart';
import 'package:bianbianbianbian/data/repository/providers.dart'
    show
        CurrentLedgerId,
        accountRepositoryProvider,
        categoryRepositoryProvider,
        currentLedgerIdProvider,
        transactionRepositoryProvider;
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/record/record_search_page.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';

class _TestCurrentLedgerId extends CurrentLedgerId {
  _TestCurrentLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
}

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository(this.transactions);
  final List<TransactionEntry> transactions;

  /// 收集 `softDeleteById` 调用——给「点击结果 → 删除」用例做断言。
  final List<String> softDeletedIds = [];

  @override
  Future<List<TransactionEntry>> listActiveByLedger(String ledgerId) async {
    // 模拟 DB：软删后的流水从 listActive 中消失。这样删除后第二次拉取
    // 才能反映出列表减少。
    return transactions
        .where((tx) => !softDeletedIds.contains(tx.id))
        .toList(growable: false);
  }

  @override
  Future<TransactionEntry> save(TransactionEntry entity) => fail('unexpected');

  @override
  Future<void> softDeleteById(String id) async {
    softDeletedIds.add(id);
  }

  @override
  Future<int> softDeleteByLedgerId(String ledgerId) => fail('unexpected');
  @override
  Future<List<TransactionEntry>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) => fail('unexpected');
  @override
  Future<int> purgeById(String id) => fail('unexpected');
  @override
  Future<int> purgeAllDeleted() => fail('unexpected');
  @override
  Future<List<TransactionEntry>> listExpired(DateTime cutoff) async => const [];
  @override
  Future<DateTime?> latestOccurredAtByLedger(String ledgerId) async => null;
}

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository(this.categories);
  final List<Category> categories;
  @override
  Future<List<Category>> listActiveAll() async => categories;
  @override
  Future<List<Category>> listActiveByParentKey(String parentKey) async =>
      categories.where((c) => c.parentKey == parentKey).toList();
  @override
  Future<List<Category>> listFavorites() async =>
      categories.where((c) => c.isFavorite).toList();
  @override
  Future<Category> save(Category entity) => fail('unexpected');
  @override
  Future<void> toggleFavorite(String id, bool isFavorite) => fail('unexpected');
  @override
  Future<void> softDeleteById(String id) => fail('unexpected');
  @override
  Future<List<Category>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) => fail('unexpected');
  @override
  Future<int> purgeById(String id) => fail('unexpected');
  @override
  Future<int> purgeAllDeleted() => fail('unexpected');
  @override
  Future<List<Category>> listExpired(DateTime cutoff) async => const [];
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(this.accounts);
  final List<Account> accounts;
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
  Future<Account> save(Account entity) => fail('unexpected');
  @override
  Future<void> softDeleteById(String id) => fail('unexpected');
  @override
  Future<List<Account>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) => fail('unexpected');
  @override
  Future<int> purgeById(String id) => fail('unexpected');
  @override
  Future<int> purgeAllDeleted() => fail('unexpected');
  @override
  Future<List<Account>> listExpired(DateTime cutoff) async => const [];
}

TransactionEntry _tx({
  required String id,
  String type = 'expense',
  double amount = 30,
  String? note,
  DateTime? at,
}) {
  return TransactionEntry(
    id: id,
    ledgerId: 'L1',
    type: type,
    amount: amount,
    currency: 'CNY',
    occurredAt: at ?? DateTime(2026, 5, 1, 12, 0),
    tags: note,
    updatedAt: at ?? DateTime(2026, 5, 1, 12, 0),
    deviceId: 'dev',
  );
}

Widget _harness({
  required List<TransactionEntry> txs,
  List<Category> categories = const [],
  List<Account> accounts = const [],
  _FakeTransactionRepository? sharedTxRepo,
}) {
  final txRepo = sharedTxRepo ?? _FakeTransactionRepository(txs);
  return ProviderScope(
    overrides: [
      currentLedgerIdProvider
          .overrideWith(() => _TestCurrentLedgerId('L1')),
      transactionRepositoryProvider.overrideWith((ref) async => txRepo),
      categoryRepositoryProvider
          .overrideWith((ref) async => _FakeCategoryRepository(categories)),
      accountRepositoryProvider
          .overrideWith((ref) async => _FakeAccountRepository(accounts)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: const RecordSearchPage(),
    ),
  );
}

void main() {
  testWidgets('空查询展示"输入条件开始搜索"提示', (tester) async {
    await tester.pumpWidget(
      _harness(txs: [_tx(id: 't1', note: '午餐')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('搜索流水'), findsOneWidget);
    expect(find.text('输入关键词或筛选条件后开始搜索'), findsOneWidget);
  });

  testWidgets('搜索"午餐"命中备注为"和同事的午餐"的流水', (tester) async {
    final txs = [
      _tx(id: 't1', note: '和同事的午餐', amount: 35),
      _tx(id: 't2', note: '打车', amount: 28),
    ];
    await tester.pumpWidget(_harness(txs: txs));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('search_keyword_field')),
      '午餐',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('和同事的午餐'), findsOneWidget);
    expect(find.textContaining('打车'), findsNothing);
  });

  testWidgets('无结果时显示"没有找到相关流水"提示', (tester) async {
    final txs = [_tx(id: 't1', note: '午餐')];
    await tester.pumpWidget(_harness(txs: txs));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('search_keyword_field')),
      '完全不存在的关键词xyz',
    );
    await tester.pumpAndSettle();

    expect(find.text('没有找到相关流水'), findsOneWidget);
  });

  testWidgets('点击搜索结果弹出详情底部表单（含复制 / 编辑 / 删除按钮）', (tester) async {
    final txs = [_tx(id: 't1', note: '和同事的午餐', amount: 35)];
    await tester.pumpWidget(_harness(txs: txs));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('search_keyword_field')),
      '午餐',
    );
    await tester.pumpAndSettle();

    // 点击命中的结果项
    await tester.tap(find.textContaining('和同事的午餐'));
    await tester.pumpAndSettle();

    // 详情底部表单应展示金额 + 三个动作按钮
    expect(find.byKey(const Key('detail_amount')), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('详情底部表单点删除 + 二次确认 → 流水从搜索结果消失', (tester) async {
    final txs = [
      _tx(id: 't1', note: '和同事的午餐', amount: 35),
      _tx(id: 't2', note: '另一笔午餐', amount: 22),
    ];
    final repo = _FakeTransactionRepository(txs);
    await tester.pumpWidget(_harness(txs: txs, sharedTxRepo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('search_keyword_field')),
      '午餐',
    );
    await tester.pumpAndSettle();

    // 两条都命中
    expect(find.textContaining('和同事的午餐'), findsOneWidget);
    expect(find.textContaining('另一笔午餐'), findsOneWidget);

    // 点第一条 → 详情 → 删除 → 二次确认对话框 → 确认
    await tester.tap(find.textContaining('和同事的午餐'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    // 二次确认对话框：标题 "删除这条记录？"
    expect(find.text('删除这条记录？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    // 仓库收到了 softDeleteById('t1')
    expect(repo.softDeletedIds, ['t1']);

    // 列表立即刷新——'和同事的午餐' 消失，'另一笔午餐' 仍在
    expect(find.textContaining('和同事的午餐'), findsNothing);
    expect(find.textContaining('另一笔午餐'), findsOneWidget);
  });
}
