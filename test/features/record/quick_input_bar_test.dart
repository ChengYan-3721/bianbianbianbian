/// Step 9.2 集成验收：首页快捷输入条 → 解析 → 确认卡片 → 保存。
///
/// 单独成文件而非塞进 `widget_test.dart`，是为了承载 `quick_*` 与
/// `categoryRepository` 等 9.2 专属 override，避免影响 home shell 基线
/// 测试。本文件只覆盖"链路畅通"——卡片的字段细节由 `quick_confirm_sheet_test`
/// 单元测试负责。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/app/app.dart';
import 'package:bianbianbianbian/core/util/quick_text_parser.dart';
import 'package:bianbianbianbian/data/repository/account_repository.dart';
import 'package:bianbianbianbian/data/repository/category_repository.dart';
import 'package:bianbianbianbian/data/repository/ledger_repository.dart';
import 'package:bianbianbianbian/data/repository/providers.dart'
    show
        CurrentLedgerId,
        accountRepositoryProvider,
        categoryRepositoryProvider,
        currentLedgerIdProvider,
        ledgerRepositoryProvider,
        transactionRepositoryProvider;
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/budget/budget_providers.dart';
import 'package:bianbianbianbian/features/record/quick_input_providers.dart';
import 'package:bianbianbianbian/features/record/record_providers.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';
import 'package:bianbianbianbian/features/stats/stats_range_providers.dart';

class _TestCurrentLedgerId extends CurrentLedgerId {
  _TestCurrentLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
}

class _FixedRecordMonth extends RecordMonth {
  _FixedRecordMonth(this._month);
  final DateTime _month;
  @override
  DateTime build() => _month;
}

class _FakeLedgerRepository implements LedgerRepository {
  _FakeLedgerRepository(this.ledger);
  final Ledger ledger;

  @override
  Future<Ledger?> getById(String id) async => ledger;
  @override
  Future<List<Ledger>> listActive() async => [ledger];
  @override
  Future<Ledger> save(Ledger entity) => fail('unexpected');
  @override
  Future<void> softDeleteById(String id) => fail('unexpected');
  @override
  Future<Ledger> setArchived(String id, bool archived) => fail('unexpected');

  @override
  Future<List<Ledger>> listDeleted() async => const [];
  @override
  Future<void> restoreById(String id) => fail('unexpected');
  @override
  Future<int> purgeById(String id) => fail('unexpected');
  @override
  Future<int> purgeAllDeleted() => fail('unexpected');
  @override
  Future<List<Ledger>> listExpired(DateTime cutoff) async => const [];
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

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository(this.categories);
  final List<Category> categories;
  @override
  Future<List<Category>> listActiveByParentKey(String parentKey) async =>
      categories.where((c) => c.parentKey == parentKey).toList();
  @override
  Future<List<Category>> listActiveAll() async => categories;
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

/// 记录 save() 的 fake——区别于 widget_test.dart 里那个 fail 的同名类。
class _RecordingTransactionRepository implements TransactionRepository {
  TransactionEntry? lastSaved;

  @override
  Future<List<TransactionEntry>> listActiveByLedger(String ledgerId) async =>
      const [];

  @override
  Future<TransactionEntry> save(TransactionEntry entity) async {
    lastSaved = entity;
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
}

void main() {
  testWidgets(
    'Step 9.2 验收：首页输入"昨天打车 25" → 弹确认卡片 → 保存 → 流水落库',
    (tester) async {
      final ledger = Ledger(
        id: 'test-ledger-id',
        name: '测试账本',
        coverEmoji: '📒',
        defaultCurrency: 'CNY',
        archived: false,
        createdAt: DateTime.utc(2026, 4),
        updatedAt: DateTime.utc(2026, 4),
        deviceId: 'test-device',
      );
      final categories = <Category>[
        Category(
          id: 'cat-trans-1',
          parentKey: 'transport',
          name: '地铁公交',
          icon: '🚇',
          isFavorite: false,
          sortOrder: 0,
          updatedAt: DateTime(2026, 4),
          deviceId: 'test-device',
        ),
        Category(
          id: 'cat-trans-2',
          parentKey: 'transport',
          name: '打车',
          icon: '🚕',
          isFavorite: false,
          sortOrder: 1,
          updatedAt: DateTime(2026, 4),
          deviceId: 'test-device',
        ),
      ];
      final txRepo = _RecordingTransactionRepository();
      // RecordMonth 锚定 2026-04，parser 时钟也设到 2026-04-26：
      // "昨天" → 2026-04-25 落在测试月内，统计/列表 invalidate 不会 flaky。
      final parserClock = DateTime(2026, 4, 26);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLedgerIdProvider.overrideWith(
              () => _TestCurrentLedgerId('test-ledger-id'),
            ),
            recordMonthProvider.overrideWith(
              () => _FixedRecordMonth(DateTime(2026, 4)),
            ),
            ledgerRepositoryProvider.overrideWith(
              (ref) async => _FakeLedgerRepository(ledger),
            ),
            transactionRepositoryProvider.overrideWith(
              (ref) async => txRepo,
            ),
            categoryRepositoryProvider.overrideWith(
              (ref) async => _FakeCategoryRepository(categories),
            ),
            accountRepositoryProvider.overrideWith(
              (ref) async => _FakeAccountRepository(const []),
            ),
            currentLedgerDefaultCurrencyProvider.overrideWith(
              (ref) async => 'CNY',
            ),
            fxRatesProvider.overrideWith(
              (ref) async => const {'CNY': 1.0, 'USD': 7.2},
            ),
            // 解析器注入固定时钟——保证"昨天" → 2026-04-25 稳定。
            quickTextParserProvider.overrideWith(
              (ref) => QuickTextParser(clock: () => parserClock),
            ),
            // 防止首页其它 watcher 触达真实 DB。
            recordMonthSummaryProvider.overrideWith(
              (ref) async => RecordMonthSummary(
                month: DateTime(2026, 4),
                income: 0,
                expense: 0,
                dailyGroups: const [],
              ),
            ),
            statsLinePointsProvider.overrideWith((ref) async => const []),
            statsPieSlicesProvider.overrideWith((ref) async => const []),
            statsRankItemsProvider.overrideWith((ref) async => const []),
            statsHeatmapCellsProvider.overrideWith((ref) async => const []),
            activeBudgetsProvider.overrideWith((ref) async => const []),
          ],
          child: const BianBianApp(enableSyncLifecycle: false),
        ),
      );
      await tester.pumpAndSettle();

      // 输入"昨天打车 25" 并点识别按钮
      await tester.enterText(
        find.byKey(const Key('quick_input_field')),
        '昨天打车 25',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('quick_input_recognize_button')),
      );
      await tester.pumpAndSettle();

      // 验收 §9.2：确认卡片打开 → 金额=25 / 分类=交通 / 时间=昨天
      expect(find.text('确认记一笔'), findsOneWidget);
      final amountField = tester.widget<TextField>(
        find.byKey(const Key('quick_confirm_amount_field')),
      );
      expect(amountField.controller!.text, '25');
      // Step 9.2 v2：rawText 含"打车" → 二次匹配命中 cat-trans-2（打车），
      // 覆盖默认 sortOrder=0 的地铁公交。
      expect(find.textContaining('交通 / 打车'), findsOneWidget);
      final timeText = tester.widget<Text>(
        find.byKey(const Key('quick_confirm_time_text')),
      );
      expect(timeText.data, contains('2026-04-25'));

      // 点保存 → 卡片关闭 + 输入框清空 + tx repo 被调
      await tester.tap(
        find.byKey(const Key('quick_confirm_save_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('确认记一笔'), findsNothing);
      // 输入框清空
      final inputField = tester.widget<TextField>(
        find.byKey(const Key('quick_input_field')),
      );
      expect(inputField.controller!.text, '');
      // 流水落库
      expect(txRepo.lastSaved, isNotNull);
      final saved = txRepo.lastSaved!;
      expect(saved.amount, 25.0);
      expect(saved.type, 'expense');
      expect(saved.categoryId, 'cat-trans-2');
      expect(saved.currency, 'CNY');
      expect(saved.fxRate, 1.0);
      expect(saved.occurredAt.year, 2026);
      expect(saved.occurredAt.month, 4);
      expect(saved.occurredAt.day, 25);
    },
  );

  testWidgets(
    'Step 9.2：空文本时点识别 → SnackBar 提示，不弹卡片',
    (tester) async {
      final ledger = Ledger(
        id: 'test-ledger-id',
        name: '测试账本',
        coverEmoji: '📒',
        defaultCurrency: 'CNY',
        archived: false,
        createdAt: DateTime.utc(2026, 4),
        updatedAt: DateTime.utc(2026, 4),
        deviceId: 'test-device',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentLedgerIdProvider.overrideWith(
              () => _TestCurrentLedgerId('test-ledger-id'),
            ),
            recordMonthProvider.overrideWith(
              () => _FixedRecordMonth(DateTime(2026, 4)),
            ),
            ledgerRepositoryProvider.overrideWith(
              (ref) async => _FakeLedgerRepository(ledger),
            ),
            transactionRepositoryProvider.overrideWith(
              (ref) async => _RecordingTransactionRepository(),
            ),
            categoryRepositoryProvider.overrideWith(
              (ref) async => _FakeCategoryRepository(const []),
            ),
            accountRepositoryProvider.overrideWith(
              (ref) async => _FakeAccountRepository(const []),
            ),
            currentLedgerDefaultCurrencyProvider.overrideWith(
              (ref) async => 'CNY',
            ),
            fxRatesProvider.overrideWith(
              (ref) async => const {'CNY': 1.0},
            ),
            quickTextParserProvider.overrideWith(
              (ref) => QuickTextParser(clock: () => DateTime(2026, 4, 26)),
            ),
            recordMonthSummaryProvider.overrideWith(
              (ref) async => RecordMonthSummary(
                month: DateTime(2026, 4),
                income: 0,
                expense: 0,
                dailyGroups: const [],
              ),
            ),
            statsLinePointsProvider.overrideWith((ref) async => const []),
            statsPieSlicesProvider.overrideWith((ref) async => const []),
            statsRankItemsProvider.overrideWith((ref) async => const []),
            statsHeatmapCellsProvider.overrideWith((ref) async => const []),
            activeBudgetsProvider.overrideWith((ref) async => const []),
          ],
          child: const BianBianApp(enableSyncLifecycle: false),
        ),
      );
      await tester.pumpAndSettle();

      // 不输入直接点识别
      await tester.tap(
        find.byKey(const Key('quick_input_recognize_button')),
      );
      await tester.pumpAndSettle();

      // SnackBar 文案出现
      expect(find.text('请先输入一段话再点识别'), findsOneWidget);
      // 不弹确认卡片
      expect(find.text('确认记一笔'), findsNothing);
    },
  );
}
