import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/core/util/quick_text_parser.dart';
import 'package:bianbianbianbian/data/repository/category_repository.dart';
import 'package:bianbianbianbian/data/repository/providers.dart'
    show
        CurrentLedgerId,
        categoryRepositoryProvider,
        currentLedgerIdProvider,
        transactionRepositoryProvider;
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/record/ai_input_enhance_service.dart';
import 'package:bianbianbianbian/features/record/quick_confirm_sheet.dart';
import 'package:bianbianbianbian/features/record/quick_input_providers.dart';
import 'package:bianbianbianbian/features/settings/ai_input_settings_providers.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';

// ---- 假仓库 / 假 provider ----

class _TestCurrentLedgerId extends CurrentLedgerId {
  _TestCurrentLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
}

class _TestAiInputSettings extends AiInputSettingsNotifier {
  _TestAiInputSettings(this._initial);
  final AiInputSettings _initial;
  @override
  Future<AiInputSettings> build() async => _initial;
  @override
  Future<void> save(AiInputSettings settings) async {
    state = AsyncValue.data(settings);
  }
}

/// Step 9.3 测试用 fake——记录 enhance 调用次数 & 注入伪造结果或异常。
class _FakeAiEnhanceService implements AiInputEnhanceService {
  // ignore: unused_element_parameter
  _FakeAiEnhanceService({this.result, this.error});

  final AiEnhanceResult? result;
  final Object? error;
  int callCount = 0;
  String? lastInput;

  @override
  AiInputSettings get settings => const AiInputSettings();

  @override
  Future<AiEnhanceResult> enhance(String rawText) async {
    callCount++;
    lastInput = rawText;
    if (error != null) {
      if (error is AiEnhanceException) throw error as AiEnhanceException;
      throw AiEnhanceException('$error');
    }
    return result ?? const AiEnhanceResult();
  }

  // 以下两个方法不会在测试中被调用——抛 fail 帮助暴露意外路径。
  @override
  String buildPromptForTesting(String rawText) =>
      throw UnimplementedError('not used in tests');
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

class _FakeTransactionRepository implements TransactionRepository {
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
  @override
  Future<DateTime?> latestOccurredAtByLedger(String ledgerId) async => null;
}
Category _cat({
  required String id,
  required String name,
  required String parentKey,
  String? icon,
  int sort = 0,
}) =>
    Category(
      id: id,
      parentKey: parentKey,
      name: name,
      icon: icon,
      isFavorite: false,
      sortOrder: sort,
      updatedAt: DateTime(2026, 4),
      deviceId: 'test-device',
    );

/// 默认分类集合：覆盖快速输入解析器词典的高频 parentKey。
/// transport 下首个（sortOrder=0）= 地铁公交（解析器命中"打车"时默认选中）。
List<Category> _defaultCategories() => [
      _cat(id: 'cat-food-1', name: '午餐', parentKey: 'food', icon: '🍱', sort: 0),
      _cat(id: 'cat-food-2', name: '早餐', parentKey: 'food', icon: '🥣', sort: 1),
      _cat(
        id: 'cat-transport-1',
        name: '地铁公交',
        parentKey: 'transport',
        icon: '🚇',
        sort: 0,
      ),
      _cat(
        id: 'cat-transport-2',
        name: '打车',
        parentKey: 'transport',
        icon: '🚕',
        sort: 1,
      ),
      _cat(
        id: 'cat-shop-1',
        name: '日用品',
        parentKey: 'shopping',
        icon: '🧻',
        sort: 0,
      ),
      _cat(
        id: 'cat-income-1',
        name: '工资',
        parentKey: 'income',
        icon: '💰',
        sort: 0,
      ),
    ];

List<Override> _overrides({
  required QuickTextParser parser,
  List<Category>? categories,
  _FakeTransactionRepository? txRepo,
  String ledgerCurrency = 'CNY',
  AiInputSettings aiSettings = const AiInputSettings(),
  _FakeAiEnhanceService? aiService,
}) {
  final cats = categories ?? _defaultCategories();
  final tx = txRepo ?? _FakeTransactionRepository();
  return [
    currentLedgerIdProvider.overrideWith(
      () => _TestCurrentLedgerId('test-ledger'),
    ),
    categoryRepositoryProvider.overrideWith(
      (ref) async => _FakeCategoryRepository(cats),
    ),
    transactionRepositoryProvider.overrideWith((ref) async => tx),
    currentLedgerDefaultCurrencyProvider.overrideWith(
      (ref) async => ledgerCurrency,
    ),
    fxRatesProvider.overrideWith(
      (ref) async => const {'CNY': 1.0, 'USD': 7.2, 'EUR': 7.85},
    ),
    quickTextParserProvider.overrideWith((ref) => parser),
    aiInputSettingsNotifierProvider.overrideWith(
      () => _TestAiInputSettings(aiSettings),
    ),
    if (aiService != null)
      aiInputEnhanceServiceProvider.overrideWithValue(aiService),
  ];
}

Widget _cardHarness(
  QuickParseResult parsed, {
  required QuickTextParser parser,
  List<Category>? categories,
  _FakeTransactionRepository? txRepo,
  String ledgerCurrency = 'CNY',
  AiInputSettings aiSettings = const AiInputSettings(),
  _FakeAiEnhanceService? aiService,
}) {
  return ProviderScope(
    overrides: _overrides(
      parser: parser,
      categories: categories,
      txRepo: txRepo,
      ledgerCurrency: ledgerCurrency,
      aiSettings: aiSettings,
      aiService: aiService,
    ),
    child: MaterialApp(
      home: Scaffold(
        body: QuickConfirmCard(parsed: parsed),
      ),
    ),
  );
}

void main() {
  /// 与 quick_text_parser_test 对齐的固定基准时间（2026-05-04 周一）。
  final fixedNow = DateTime(2026, 5, 4);
  QuickTextParser parserAt(DateTime now) =>
      QuickTextParser(clock: () => now);

  group('QuickConfirmCard - 解析结果初始展示', () {
    testWidgets(
      '低置信度（仅金额命中）→ 顶部红色"请核对"横幅；保存按钮 disabled',
      (tester) async {
        final parser = parserAt(fixedNow);
        final parsed = parser.parse('30');
        expect(parsed.amount, 30.0);
        expect(parsed.categoryParentKey, isNull);
        expect(parsed.confidence, lessThan(quickConfidenceThreshold));

        await tester.pumpWidget(_cardHarness(parsed, parser: parser));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('quick_confirm_low_conf_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('识别置信度较低'), findsOneWidget);

        // 分类未选 → 行内展示"请选择"占位
        expect(find.text('请选择'), findsOneWidget);

        // 保存 disabled
        final saveBtn = tester.widget<FilledButton>(
          find.byKey(const Key('quick_confirm_save_button')),
        );
        expect(saveBtn.onPressed, isNull);
      },
    );

    testWidgets('备注字段显示残余文本', (tester) async {
      final parser = parserAt(fixedNow);
      // "今天 午饭 30 跟同事" → 时间/分类/金额识别后残余 "跟同事"
      final parsed = parser.parse('今天 午饭 30 跟同事');
      expect(parsed.note, '跟同事');

      await tester.pumpWidget(_cardHarness(parsed, parser: parser));
      await tester.pumpAndSettle();

      final noteField = tester.widget<TextField>(
        find.byKey(const Key('quick_confirm_note_field')),
      );
      expect(noteField.controller!.text, '跟同事');
    });
  });

  group('QuickConfirmCard - 保存', () {
    testWidgets(
      '「昨天打车 25」点保存 → 流水写为 expense + 二次匹配 transport/打车',
      (tester) async {
        final parser = parserAt(fixedNow);
        final parsed = parser.parse('昨天打车 25');
        final txRepo = _FakeTransactionRepository();

        await tester.pumpWidget(
          _cardHarness(parsed, parser: parser, txRepo: txRepo),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('quick_confirm_save_button')),
        );
        await tester.pumpAndSettle();

        expect(txRepo.lastSaved, isNotNull);
        final saved = txRepo.lastSaved!;
        expect(saved.amount, 25.0);
        expect(saved.type, 'expense');
        // rawText 包含 subcategory "打车" → 覆盖 parser 默认的 sortOrder=0
        // (地铁公交) → 命中 cat-transport-2（打车）。
        expect(saved.categoryId, 'cat-transport-2');
        expect(saved.currency, 'CNY');
        expect(saved.fxRate, 1.0);
        expect(saved.tags, isNull);
        // 日期部分必须等于解析的 occurredAt（昨天）
        expect(saved.occurredAt.year, 2026);
        expect(saved.occurredAt.month, 5);
        expect(saved.occurredAt.day, 3);
      },
    );

    testWidgets(
      '「工资 5000」→ 自动判定 income type 并保存（与 record_new_page 同语义）',
      (tester) async {
        final parser = parserAt(fixedNow);
        final parsed = parser.parse('工资 5000');
        expect(parsed.amount, 5000.0);
        expect(parsed.categoryParentKey, 'income');

        final txRepo = _FakeTransactionRepository();
        await tester.pumpWidget(
          _cardHarness(parsed, parser: parser, txRepo: txRepo),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('quick_confirm_save_button')),
        );
        await tester.pumpAndSettle();

        expect(txRepo.lastSaved, isNotNull);
        expect(txRepo.lastSaved!.type, 'income');
        expect(txRepo.lastSaved!.amount, 5000.0);
        expect(txRepo.lastSaved!.categoryId, 'cat-income-1');
      },
    );

    testWidgets('用户改写金额 → 保存使用最终值', (tester) async {
      final parser = parserAt(fixedNow);
      final parsed = parser.parse('昨天打车 25');
      final txRepo = _FakeTransactionRepository();

      await tester.pumpWidget(
        _cardHarness(parsed, parser: parser, txRepo: txRepo),
      );
      await tester.pumpAndSettle();

      // 清空并改写为 "42.5"
      await tester.enterText(
        find.byKey(const Key('quick_confirm_amount_field')),
        '42.5',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('quick_confirm_save_button')),
      );
      await tester.pumpAndSettle();

      expect(txRepo.lastSaved, isNotNull);
      expect(txRepo.lastSaved!.amount, 42.5);
    });

    testWidgets(
      '点取消 → 不保存；showQuickConfirmSheet 返回 false',
      (tester) async {
        final parser = parserAt(fixedNow);
        final parsed = parser.parse('昨天打车 25');
        final txRepo = _FakeTransactionRepository();

        bool? sheetResult;
        await tester.pumpWidget(
          ProviderScope(
            overrides: _overrides(parser: parser, txRepo: txRepo),
            child: MaterialApp(
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        sheetResult = await showQuickConfirmSheet(
                          context: ctx,
                          parsed: parsed,
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('确认记一笔'), findsOneWidget);

        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        expect(sheetResult, isFalse);
        expect(txRepo.lastSaved, isNull);
      },
    );
  });

  group('QuickConfirmCard - 分类选择器', () {
    testWidgets(
      '在选择器里点 cat-transport-1 → 卡片 categoryId 切换并保存正确',
      (tester) async {
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;

        final parser = parserAt(fixedNow);
        final parsed = parser.parse('昨天打车 25');
        final txRepo = _FakeTransactionRepository();

        await tester.pumpWidget(
          _cardHarness(parsed, parser: parser, txRepo: txRepo),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('quick_confirm_category_row')),
        );
        await tester.pumpAndSettle();

        // 默认是 cat-transport-2（打车），点 cat-transport-1（地铁公交）
        // 验证用户主动切换 → 卡片状态跟随。
        await tester.tap(
          find.byKey(const Key('quick_confirm_picker_cat-transport-1')),
        );
        await tester.pumpAndSettle();

        // 保存 → categoryId = cat-transport-1
        await tester.tap(
          find.byKey(const Key('quick_confirm_save_button')),
        );
        await tester.pumpAndSettle();

        expect(txRepo.lastSaved!.categoryId, 'cat-transport-1');
      },
    );
  });

  /// Step 9.2 v2：实际分类名二次匹配 - 修复"午餐 20 误判成早餐 / 红包收入
  /// 200 误判成红包支出"两个用户报告的 case。
  group('QuickConfirmCard - 实际分类名二次匹配（subcategory override）', () {
    testWidgets(
      '"红包收入 200" → 二次匹配命中 income/红包（覆盖 parser 的 social），'
      '"收入"从 note 剥离',
      (tester) async {
        // 模拟生产 seeder：income 下有"红包"二级分类、social 下有"红包支出"。
        // 解析器词典 `'红包' → 'social'` 会让 parser 错判到 social；二次匹
        // 配按"分类名长度倒序"扫描——
        //   红包支出（4 字）：rawText 不含"支出" → miss；
        //   红包（2 字，income）：rawText 含"红包" → 命中 → 覆盖 parentKey
        //   到 income，并把 parent label "收入" 从 note 剥离。
        final cats = [
          _cat(
            id: 'cat-income-redbao',
            name: '红包',
            parentKey: 'income',
            icon: '🧧',
            sort: 6,
          ),
          _cat(
            id: 'cat-social-redbaozc',
            name: '红包支出',
            parentKey: 'social',
            icon: '🧧',
            sort: 2,
          ),
          _cat(
            id: 'cat-social-gift',
            name: '礼物',
            parentKey: 'social',
            icon: '🎁',
            sort: 0,
          ),
        ];

        final parser = parserAt(fixedNow);
        final parsed = parser.parse('红包收入 200');
        // 解析器：amount=200, parentKey=social（dict 中红包先于收入）, note 残
        // 余="收入"。
        expect(parsed.amount, 200.0);
        expect(parsed.categoryParentKey, 'social');
        expect(parsed.note, contains('收入'));

        final txRepo = _FakeTransactionRepository();
        await tester.pumpWidget(
          _cardHarness(
            parsed,
            parser: parser,
            categories: cats,
            txRepo: txRepo,
          ),
        );
        await tester.pumpAndSettle();

        // 卡片显示 income/红包，不再是 social/任何分类
        expect(find.textContaining('收入 / 红包'), findsOneWidget);
        expect(find.textContaining('人情 / '), findsNothing);

        // 备注空（"收入"已被作为 income parent label 剥离）
        final noteField = tester.widget<TextField>(
          find.byKey(const Key('quick_confirm_note_field')),
        );
        expect(noteField.controller!.text, '');

        await tester.tap(
          find.byKey(const Key('quick_confirm_save_button')),
        );
        await tester.pumpAndSettle();

        expect(txRepo.lastSaved, isNotNull);
        final saved = txRepo.lastSaved!;
        expect(saved.type, 'income');
        expect(saved.categoryId, 'cat-income-redbao');
        expect(saved.tags, isNull); // note 空 → tags=null
      },
    );

    testWidgets(
      '"红包支出 100" → 二次匹配命中 social/红包支出（最长精确匹配胜）',
      (tester) async {
        final cats = [
          _cat(
            id: 'cat-income-redbao',
            name: '红包',
            parentKey: 'income',
            icon: '🧧',
            sort: 6,
          ),
          _cat(
            id: 'cat-social-redbaozc',
            name: '红包支出',
            parentKey: 'social',
            icon: '🧧',
            sort: 2,
          ),
        ];

        final parser = parserAt(fixedNow);
        final parsed = parser.parse('红包支出 100');

        final txRepo = _FakeTransactionRepository();
        await tester.pumpWidget(
          _cardHarness(
            parsed,
            parser: parser,
            categories: cats,
            txRepo: txRepo,
          ),
        );
        await tester.pumpAndSettle();

        // "红包支出" 4 字胜过"红包" 2 字 → 选 social/红包支出
        expect(find.textContaining('人情 / 红包支出'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('quick_confirm_save_button')),
        );
        await tester.pumpAndSettle();

        expect(txRepo.lastSaved!.categoryId, 'cat-social-redbaozc');
        expect(txRepo.lastSaved!.type, 'expense');
      },
    );
  });

  /// Step 9.3：LLM 增强按钮接线测试（4 用例覆盖 implementation-plan §9.3 三条验证）。
  group('QuickConfirmCard - Step 9.3 AI 增强按钮', () {
    const enabledSettings = AiInputSettings(
      enabled: true,
      endpoint: 'https://api.openai.com/v1/chat/completions',
      apiKey: 'sk-test',
      model: 'gpt-4o-mini',
    );

    testWidgets(
      '验证 1：无 AI 配置 + 低置信度 → AI 增强按钮不显示（横幅仍显示）',
      (tester) async {
        final parser = parserAt(fixedNow);
        // 仅金额命中 → 低置信度 0.5 < 0.6
        final parsed = parser.parse('30');
        expect(parsed.confidence, lessThan(quickConfidenceThreshold));

        await tester.pumpWidget(
          _cardHarness(parsed, parser: parser),
        );
        await tester.pumpAndSettle();

        // 横幅可见，但 AI 增强按钮不可见
        expect(
          find.byKey(const Key('quick_confirm_low_conf_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('quick_confirm_ai_enhance_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '验证 1+：AI 配置完整 + 低置信度 → AI 增强按钮显示；高置信度即使配置完整也不显示',
      (tester) async {
        // (a) 低置信度 + 配置完整 → 按钮可见
        final parser = parserAt(fixedNow);
        final lowConf = parser.parse('30');
        await tester.pumpWidget(
          _cardHarness(
            lowConf,
            parser: parser,
            aiSettings: enabledSettings,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('quick_confirm_ai_enhance_button')),
          findsOneWidget,
        );

        // (b) 高置信度（昨天打车 25 = 1.0）+ 配置完整 → 按钮不可见
        final highConf = parser.parse('昨天打车 25');
        await tester.pumpWidget(
          _cardHarness(
            highConf,
            parser: parser,
            aiSettings: enabledSettings,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('quick_confirm_ai_enhance_button')),
          findsNothing,
        );
        // 横幅也不应可见
        expect(
          find.byKey(const Key('quick_confirm_low_conf_banner')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '验证 2/3：AI 解析失败（网络或 schema 错误）→ SnackBar 提示，字段保持本地值',
      (tester) async {
        final parser = parserAt(fixedNow);
        final parsed = parser.parse('30');
        final fakeService = _FakeAiEnhanceService(
          error: const AiEnhanceException('网络请求失败：模拟断网'),
        );

        await tester.pumpWidget(
          _cardHarness(
            parsed,
            parser: parser,
            aiSettings: enabledSettings,
            aiService: fakeService,
          ),
        );
        await tester.pumpAndSettle();

        // 初始 amount=30
        final amount0 = tester.widget<TextField>(
          find.byKey(const Key('quick_confirm_amount_field')),
        );
        expect(amount0.controller!.text, '30');

        await tester.tap(
          find.byKey(const Key('quick_confirm_ai_enhance_button')),
        );
        await tester.pumpAndSettle();

        // SnackBar 内容包含 "AI 解析失败"
        expect(find.textContaining('AI 解析失败'), findsOneWidget);
        expect(find.textContaining('模拟断网'), findsOneWidget);

        // 字段保持原值不变
        final amount1 = tester.widget<TextField>(
          find.byKey(const Key('quick_confirm_amount_field')),
        );
        expect(amount1.controller!.text, '30');
        // 分类仍为"请选择"占位
        expect(find.text('请选择'), findsOneWidget);
      },
    );
  });
}
