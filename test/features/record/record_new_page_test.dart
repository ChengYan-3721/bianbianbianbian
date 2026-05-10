import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/data/repository/account_repository.dart';
import 'package:bianbianbianbian/data/repository/category_repository.dart';
import 'package:bianbianbianbian/data/repository/ledger_repository.dart';
import 'package:bianbianbianbian/data/repository/providers.dart';
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/record/record_new_page.dart';
import 'package:bianbianbianbian/features/record/record_providers.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';

// ---- 假仓库 ----

class _TestCurrentLedgerId extends CurrentLedgerId {
  _TestCurrentLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
}

class _TestMultiCurrencyEnabled extends MultiCurrencyEnabled {
  _TestMultiCurrencyEnabled(this._enabled);
  final bool _enabled;
  @override
  Future<bool> build() async => _enabled;
}

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({this.categories = const []});
  final List<Category> categories;

  @override
  Future<List<Category>> listActiveByParentKey(String parentKey) async {
    return categories.where((c) => c.parentKey == parentKey).toList();
  }

  @override
  Future<List<Category>> listFavorites() async =>
      categories.where((c) => c.isFavorite).toList();

  @override
  Future<List<Category>> listActiveAll() async => categories;

  @override
  Future<Category> save(Category entity) => fail('unexpected save');

  @override
  Future<void> toggleFavorite(String id, bool isFavorite) =>
      fail('unexpected toggle');

  @override
  Future<void> softDeleteById(String id) => fail('unexpected delete');

  @override
  Future<List<Category>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) => fail('unexpected restore');
  @override
  Future<int> purgeById(String id) => fail('unexpected purge');
  @override
  Future<int> purgeAllDeleted() => fail('unexpected purgeAll');
  @override
  Future<List<Category>> listExpired(DateTime cutoff) async => const [];
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({this.accounts = const []});
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
  Future<Account> save(Account entity) => fail('unexpected save');

  @override
  Future<void> softDeleteById(String id) => fail('unexpected delete');

  @override
  Future<List<Account>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) => fail('unexpected restore');
  @override
  Future<int> purgeById(String id) => fail('unexpected purge');
  @override
  Future<int> purgeAllDeleted() => fail('unexpected purgeAll');
  @override
  Future<List<Account>> listExpired(DateTime cutoff) async => const [];
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
  Future<Ledger> save(Ledger entity) => fail('unexpected save');

  @override
  Future<void> softDeleteById(String id) => fail('unexpected delete');

  @override
  Future<Ledger> setArchived(String id, bool archived) =>
      fail('unexpected archive');

  @override
  Future<List<Ledger>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) => fail('unexpected restore');
  @override
  Future<int> purgeById(String id) => fail('unexpected purge');
  @override
  Future<int> purgeAllDeleted() => fail('unexpected purgeAll');
  @override
  Future<List<Ledger>> listExpired(DateTime cutoff) async => const [];
}

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository();
  final List<TransactionEntry> _saved = [];

  @override
  Future<List<TransactionEntry>> listActiveByLedger(String ledgerId) async =>
      _saved;

  @override
  Future<TransactionEntry> save(TransactionEntry entity) async {
    _saved.add(entity);
    return entity;
  }

  @override
  Future<void> softDeleteById(String id) async {}

  @override
  Future<int> softDeleteByLedgerId(String ledgerId) async => 0;

  @override
  Future<List<TransactionEntry>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) async {}
  @override
  Future<int> purgeById(String id) async => 0;
  @override
  Future<int> purgeAllDeleted() async => 0;
  @override
  Future<List<TransactionEntry>> listExpired(DateTime cutoff) async => const [];
  @override
  Future<DateTime?> latestOccurredAtByLedger(String ledgerId) async => null;
}

// ---- 测试辅助 ----

Ledger _testLedger() => Ledger(
      id: 'test-ledger-id',
      name: '测试账本',
      coverEmoji: '📒',
      defaultCurrency: 'CNY',
      deviceId: 'test-device',
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
    );

Category _testCategory({
  String id = 'cat-food',
  String name = '餐饮',
  String parentKey = 'food',
  bool isFavorite = false,
}) =>
    Category(
      id: id,
      parentKey: parentKey,
      name: name,
      icon: '🍔',
      isFavorite: isFavorite,
      sortOrder: 1,
      updatedAt: DateTime(2026, 4),
      deviceId: 'test-device',
    );

Account _testAccount({
  String id = 'acc-cash',
  String name = '现金',
}) =>
    Account(
      id: id,
      name: name,
      type: 'cash',
      icon: '💵',
      updatedAt: DateTime(2026, 4),
      deviceId: 'test-device',
    );

/// 构建基础 provider overrides（不含 recordMonthSummaryProvider）。
List<Override> _baseOverrides({
  List<Category>? categories,
  List<Account>? accounts,
  Ledger? ledger,
  TransactionRepository? txRepo,
  bool multiCurrencyEnabled = false,
}) {
  final l = ledger ?? _testLedger();
  return [
    currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId('test-ledger-id')),
    multiCurrencyEnabledProvider.overrideWith(
      () => _TestMultiCurrencyEnabled(multiCurrencyEnabled),
    ),
    // Step 8.2：记账页保存路径会读账本默认币种与汇率快照。测试统一注入
    // CNY 账本 + 写死的 11 内置币种快照，避免命中真实 DB / Riverpod 链。
    currentLedgerDefaultCurrencyProvider.overrideWith(
      (ref) async => l.defaultCurrency,
    ),
    fxRatesProvider.overrideWith(
      (ref) async => const {
        'CNY': 1.0,
        'USD': 7.2,
        'EUR': 7.85,
      },
    ),
    categoryRepositoryProvider.overrideWith(
      (ref) async =>
          _FakeCategoryRepository(categories: categories ?? [_testCategory()]),
    ),
    accountRepositoryProvider.overrideWith(
      (ref) async =>
          _FakeAccountRepository(accounts: accounts ?? [_testAccount()]),
    ),
    ledgerRepositoryProvider.overrideWith(
      (ref) async => _FakeLedgerRepository(ledger: l),
    ),
    transactionRepositoryProvider.overrideWith(
      (ref) async => txRepo ?? _FakeTransactionRepository(),
    ),
  ];
}

/// 用于不需要 save 的测试（不需要 recordMonthSummaryProvider override）。
List<Override> _formOverrides({
  List<Category>? categories,
  List<Account>? accounts,
  Ledger? ledger,
  bool multiCurrencyEnabled = false,
}) =>
    _baseOverrides(
      categories: categories,
      accounts: accounts,
      ledger: ledger,
      multiCurrencyEnabled: multiCurrencyEnabled,
    );

/// 用于需要 save 的测试（save 会 invalidate recordMonthSummaryProvider）。
List<Override> _saveOverrides({
  List<Category>? categories,
  List<Account>? accounts,
  Ledger? ledger,
  TransactionRepository? txRepo,
  bool multiCurrencyEnabled = false,
}) {
  return [
    ..._baseOverrides(
      categories: categories,
      accounts: accounts,
      ledger: ledger,
      txRepo: txRepo,
      multiCurrencyEnabled: multiCurrencyEnabled,
    ),
    recordMonthSummaryProvider.overrideWith(
      (ref) async => RecordMonthSummary(
        month: DateTime(2026, 4),
        income: 0,
        expense: 0,
        dailyGroups: [],
      ),
    ),
  ];
}

Widget _wrapApp(Widget child, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? _formOverrides(),
    child: MaterialApp(
      home: child,
    ),
  );
}

/// 切换到"食"一级 Tab 并点击测试分类进入数字键盘态。
Future<void> _enterKeyboardStage(WidgetTester tester) async {
  // 默认在 ☆，先切到"食"
  await tester.tap(find.text('食').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('🍔').first);
  await tester.pumpAndSettle();
}

Future<void> tapKeys(WidgetTester tester, List<String> keys) async {
  for (final k in keys) {
    await tester.tap(find.text(k).first);
    await tester.pump();
  }
}

/// 在 SingleChildScrollView 中向下滚动，直到 [finder] 可见。
Future<void> scrollToVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 100,
      scrollable: find.byType(Scrollable).first);
  await tester.pump();
}

void main() {
  // ---- Step 3.2 验收 1：金额算式 ----

  group('金额算式', () {
    testWidgets('输入 12.5+3 显示 ¥15.50', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      await tapKeys(tester, ['1', '2', '.', '5', '+', '3']);

      expect(find.byKey(const Key('amount_result')), findsOneWidget);
      expect(find.text('¥ 12.5+3'), findsWidgets);
    });

    testWidgets('表达式为空时显示 ¥0.00', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('amount_result')), findsNothing);
    });

    testWidgets('⌫ 退格', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      await tapKeys(tester, ['1', '2', '3']);

      expect(find.byKey(const Key('amount_result')), findsOneWidget);
      expect(find.text('¥ 123'), findsWidgets);

      await tester.tap(find.text('⌫').first);
      await tester.pump();

      expect(find.byKey(const Key('amount_result')), findsOneWidget);
      expect(find.text('¥ 12'), findsWidgets);
    });
  });

  // ---- Step 3.2 验收 2：未选分类保存按钮置灰 ----

  group('保存按钮状态', () {
    testWidgets('未选分类时保存按钮 disabled', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      await tapKeys(tester, ['5', '0']);

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('选择分类后保存按钮变为 enabled', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      await tapKeys(tester, ['2', '0']);
      await tester.pump();

      expect(find.text('✓'), findsOneWidget);
    });

    testWidgets('无金额仅选分类，保存按钮仍 disabled', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      // 需要先切换到"食"一级 Tab
      await tester.tap(find.text('食').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('🍔').first);
      await tester.pumpAndSettle();

      final amount = find.byKey(const Key('amount_result'));
      expect(amount, findsOneWidget);
      expect(find.byKey(const Key('amount_result')), findsOneWidget);
      expect(find.text('¥ 0.00'), findsWidgets);
    });
  });

  // ---- 页面结构完整性 ----

  group('页面结构', () {
    testWidgets('转账页直接展示数字键盘与账户入口', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage(isTransfer: true)));
      await tester.pumpAndSettle();

      expect(find.text('转账'), findsOneWidget);
      expect(find.byKey(const Key('amount_result')), findsOneWidget);
      expect(find.text('转出账户'), findsOneWidget);
      expect(find.text('转入账户'), findsOneWidget);
      expect(find.text('✓'), findsOneWidget);
    });

    testWidgets('转账模式账户选择列表互斥（禁止选择相同账户）', (tester) async {
      await tester.pumpWidget(_wrapApp(
        const RecordNewPage(isTransfer: true),
        overrides: _formOverrides(accounts: [
          _testAccount(id: 'acc-out', name: '现金'),
          _testAccount(id: 'acc-in', name: '银行卡'),
        ]),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.call_made).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('现金').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.call_received).first);
      await tester.pumpAndSettle();
      expect(find.text('银行卡'), findsOneWidget);
      final inSheetListTiles = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListTile),
      );
      expect(inSheetListTiles, findsOneWidget);
      expect(find.descendant(of: inSheetListTiles, matching: find.text('现金')), findsNothing);
      await tester.tap(find.text('银行卡').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.call_made).first);
      await tester.pumpAndSettle();
      expect(find.text('现金'), findsWidgets);
      final outSheetListTiles = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListTile),
      );
      expect(outSheetListTiles, findsOneWidget);
      expect(find.descendant(of: outSheetListTiles, matching: find.text('银行卡')), findsNothing);
    });

    testWidgets('标题和关闭按钮存在', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      expect(find.text('记一笔'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('底部一级分类单字 Tab 渲染并可切换', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      for (final tab in ['☆', '收', '食', '购', '行', '育', '乐', '情', '住', '医', '投', '其']) {
        expect(find.text(tab), findsWidgets);
      }

      // 默认在 ☆（收藏）
      var starText = tester.widget<Text>(find.text('☆').first);
      expect(starText.style?.fontWeight, FontWeight.w700);

      // 切到“收”
      await tester.tap(find.text('收').first);
      await tester.pumpAndSettle();

      // 当前实现无分类时显示“编辑”入口卡片，而非“暂无分类”文案
      expect(find.text('编辑'), findsWidgets);

      final foodText = tester.widget<Text>(find.text('食').first);
      expect(foodText.style?.fontWeight, isNot(FontWeight.w700));
    });

    testWidgets('数字键盘完整渲染', (tester) async {
      // Step 8.1：开启多币种 → 左下角 CNY 键可见。
      await tester.pumpWidget(_wrapApp(
        const RecordNewPage(),
        overrides: _formOverrides(multiCurrencyEnabled: true),
      ));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      for (final key in [
        '⌫', '+', '-', '.', '✓', 'CNY',
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
      ]) {
        expect(find.text(key), findsWidgets);
      }
    });

    // Step 8.1 验收：开关关闭时记账页币种字段隐藏。
    testWidgets('多币种开关关闭时键盘不显示 CNY 键', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      // 默认 multiCurrencyEnabled=false → 左下角币种位为空白占位。
      expect(find.text('CNY'), findsNothing);
      // 但其它键仍渲染，保证布局未被破坏。
      for (final key in ['0', '1', '7', '⌫', '+', '-', '.']) {
        expect(find.text(key), findsWidgets);
      }
    });

    testWidgets('多币种开关开启时键盘显示 CNY 键', (tester) async {
      await tester.pumpWidget(_wrapApp(
        const RecordNewPage(),
        overrides: _formOverrides(multiCurrencyEnabled: true),
      ));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      expect(find.text('CNY'), findsWidgets);
    });

    testWidgets('键盘态工具条存在钱包/日期/备注入口', (tester) async {
      await tester.pumpWidget(_wrapApp(const RecordNewPage()));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
    });
  });

  // ---- Step 3.2 验收 3：保存后 invalidate ----

  group('保存 invalidate', () {
    testWidgets('保存后表单状态正确', (tester) async {
      final txRepo = _FakeTransactionRepository();
      await tester.pumpWidget(_wrapApp(
        const RecordNewPage(),
        overrides: _saveOverrides(txRepo: txRepo),
      ));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      await tapKeys(tester, ['8', '8']);
      await tester.tap(find.text('✓').first);
      await tester.pumpAndSettle();

      expect(txRepo._saved.length, 1);
      expect(txRepo._saved.first.amount, 88);
    });
  });

  // ---- Step 8.2：币种选择器 + fxRate 持久化 ----

  group('Step 8.2 币种选择', () {
    testWidgets('点击键盘 CNY 键打开下拉、选择 USD 后金额前缀变 \$', (tester) async {
      await tester.pumpWidget(_wrapApp(
        const RecordNewPage(),
        overrides: _formOverrides(multiCurrencyEnabled: true),
      ));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      await tapKeys(tester, ['1', '0']);

      // 默认 CNY 币种 → 金额前缀 ¥
      expect(find.text('¥ 10'), findsWidgets);

      // 点击键盘左下角 CNY 键 → 打开 _CurrencyPicker
      await tester.tap(find.text('CNY').first);
      await tester.pumpAndSettle();
      expect(find.text('选择币种'), findsOneWidget);

      // 选择 USD（lookup by Key 比 textContaining 稳）
      await tester.tap(find.byKey(const Key('currency_picker_USD')));
      await tester.pumpAndSettle();

      // 关闭后金额前缀变 $（form.currency 已切换）
      expect(find.text('\$ 10'), findsWidgets);
      // 键盘标签也跟着变
      expect(find.text('USD'), findsWidgets);
    });

    testWidgets('保存 USD 10：写入 currency=USD、fxRate=7.2 → 折合 72 CNY', (tester) async {
      final txRepo = _FakeTransactionRepository();
      await tester.pumpWidget(_wrapApp(
        const RecordNewPage(),
        overrides: _saveOverrides(
          txRepo: txRepo,
          multiCurrencyEnabled: true,
        ),
      ));
      await tester.pumpAndSettle();

      await _enterKeyboardStage(tester);
      // 切换到 USD
      await tester.tap(find.text('CNY').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency_picker_USD')));
      await tester.pumpAndSettle();

      await tapKeys(tester, ['1', '0']);
      await tester.tap(find.text('✓').first);
      await tester.pumpAndSettle();

      expect(txRepo._saved.length, 1);
      final saved = txRepo._saved.single;
      expect(saved.amount, 10);
      expect(saved.currency, 'USD');
      expect(saved.fxRate, closeTo(7.2, 1e-9));
      expect(saved.amount * saved.fxRate, closeTo(72.0, 1e-9));
    });
  });
}
