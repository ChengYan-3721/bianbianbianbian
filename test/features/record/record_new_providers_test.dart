import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bianbianbianbian/data/repository/ledger_repository.dart';
import 'package:bianbianbianbian/data/repository/providers.dart'
    show
        CurrentLedgerId,
        currentLedgerIdProvider,
        ledgerRepositoryProvider,
        transactionRepositoryProvider;
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/record/record_new_providers.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';

/// 假 TransactionRepository —— save 返回收到的实体，softDeleteById 静默成功。
class _FakeTransactionRepository implements TransactionRepository {
  TransactionEntry? lastSaved;

  @override
  Future<List<TransactionEntry>> listActiveByLedger(String ledgerId) async => [];

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

class _TestCurrentLedgerId extends CurrentLedgerId {
  _TestCurrentLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
}

class _FakeLedgerRepository implements LedgerRepository {
  _FakeLedgerRepository({required this.ledger});
  final Ledger ledger;

  @override
  Future<Ledger?> getById(String id) async => ledger;

  @override
  Future<List<Ledger>> listActive() async => [ledger];

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

Ledger _testLedger({String defaultCurrency = 'CNY'}) => Ledger(
      id: 'test-ledger',
      name: '测试账本',
      defaultCurrency: defaultCurrency,
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
      deviceId: 'dev',
    );

void main() {
  ProviderContainer makeContainer({
    TransactionRepository? txRepo,
    String ledgerId = 'test-ledger',
    String ledgerCurrency = 'CNY',
    Map<String, double>? fxRates,
  }) {
    final repo = txRepo ?? _FakeTransactionRepository();
    final ledger = _testLedger(defaultCurrency: ledgerCurrency);
    return ProviderContainer(overrides: [
      currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId(ledgerId)),
      transactionRepositoryProvider.overrideWith((ref) async => repo),
      ledgerRepositoryProvider.overrideWith(
        (ref) async => _FakeLedgerRepository(ledger: ledger),
      ),
      currentLedgerDefaultCurrencyProvider.overrideWith(
        (ref) async => ledgerCurrency,
      ),
      fxRatesProvider.overrideWith(
        (ref) async =>
            fxRates ?? const {'CNY': 1.0, 'USD': 7.2, 'EUR': 7.85},
      ),
    ]);
  }

  // ---- 表达式求值（通过 RecordForm.onKeyTap 间接测 _parseExpr）----

  group('表达式求值', () {
    test('单个数字直接显示', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.onKeyTap('1');
      notifier.onKeyTap('2');

      final form = container.read(recordFormProvider);
      expect(form.expression, '12');
      expect(form.amount, 12.0);
    });

    test('12.5+3= → 15.5', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.onKeyTap('1');
      notifier.onKeyTap('2');
      notifier.onKeyTap('.');
      notifier.onKeyTap('5');
      notifier.onKeyTap('+');
      notifier.onKeyTap('3');

      var form = container.read(recordFormProvider);
      expect(form.expression, '12.5+3');
      expect(form.amount, 15.5);

      // = 号也求值
      notifier.onKeyTap('=');
      form = container.read(recordFormProvider);
      expect(form.amount, 15.5);
    });

    test('10-3.5+2 → 8.5', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.onKeyTap('1');
      notifier.onKeyTap('0');
      notifier.onKeyTap('-');
      notifier.onKeyTap('3');
      notifier.onKeyTap('.');
      notifier.onKeyTap('5');
      notifier.onKeyTap('+');
      notifier.onKeyTap('2');

      final form = container.read(recordFormProvider);
      expect(form.expression, '10-3.5+2');
      expect(form.amount, 8.5);
    });

    test('非法表达式 = 号不改变 amount', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      // 先输入有效数字拿到一个确定的 amount
      notifier.onKeyTap('5');
      notifier.onKeyTap('0');
      var form = container.read(recordFormProvider);
      expect(form.amount, 50);

      // 继续输入形成非法表达式 50+ —— _parseExpr('50+')=null，copyWith(null) 保持旧值
      notifier.onKeyTap('+');
      form = container.read(recordFormProvider);
      expect(form.expression, '50+');
      expect(form.amount, 50); // copyWith(null) → 保持上一步的 50

      // = 不改变 amount
      notifier.onKeyTap('=');
      form = container.read(recordFormProvider);
      expect(form.amount, 50);
    });
  });

  // ---- 退格 ----

  group('退格', () {
    test('⌫ 退格并重新求值，退到空后表达式为空', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.onKeyTap('1');
      notifier.onKeyTap('5');

      var form = container.read(recordFormProvider);
      expect(form.expression, '15');
      expect(form.amount, 15);

      notifier.onKeyTap('⌫');
      form = container.read(recordFormProvider);
      expect(form.expression, '1');
      expect(form.amount, 1);

      notifier.onKeyTap('⌫');
      form = container.read(recordFormProvider);
      expect(form.expression, '');
    });

    test('空表达式时 ⌫ 不报错', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.onKeyTap('⌫');
      final form = container.read(recordFormProvider);
      expect(form.expression, '');
    });
  });

  // ---- 表单状态管理 ----

  group('表单状态管理', () {
    test('canSave 默认 false', () {
      final container = makeContainer();
      final form = container.read(recordFormProvider);
      expect(form.canSave, isFalse);
    });

    test('有金额无分类时 canSave 为 false', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.onKeyTap('1');
      notifier.onKeyTap('0');

      final form = container.read(recordFormProvider);
      expect(form.amount, 10);
      expect(form.categoryId, isNull);
      expect(form.canSave, isFalse);
    });

    test('有分类无金额时 canSave 为 false', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-1');

      final form = container.read(recordFormProvider);
      expect(form.amount, isNull);
      expect(form.canSave, isFalse);
    });

    test('选择分类 + 输入金额后 canSave 为 true', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-1');
      notifier.onKeyTap('2');
      notifier.onKeyTap('5');

      final form = container.read(recordFormProvider);
      expect(form.amount, 25);
      expect(form.categoryId, 'cat-1');
      expect(form.canSave, isTrue);
    });

    test('金额为 0 时 canSave 为 false', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-1');
      notifier.onKeyTap('0');

      final form = container.read(recordFormProvider);
      expect(form.amount, 0);
      expect(form.canSave, isFalse);
    });

    test('setParentKey 切换一级分类并自动推导 type', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      var form = container.read(recordFormProvider);
      expect(form.selectedParentKey, 'favorite');
      expect(form.inferredType, 'expense');

      notifier.setParentKey('income');
      form = container.read(recordFormProvider);
      expect(form.selectedParentKey, 'income');
      expect(form.inferredType, 'income');
    });

    test('setCategory / setAccount / setNote / setOccurredAt', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-food');
      notifier.setAccount('acc-cash');
      notifier.setNote('午饭');
      final dt = DateTime(2026, 4, 25, 12, 0);
      notifier.setOccurredAt(dt);

      final form = container.read(recordFormProvider);
      expect(form.categoryId, 'cat-food');
      expect(form.accountId, 'acc-cash');
      expect(form.note, '午饭');
      expect(form.occurredAt, dt);
    });

    test('转账模式下 canSave 依赖转出/转入账户且不能相同', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setTransferMode(true);
      notifier.onKeyTap('1');
      notifier.onKeyTap('0');

      var form = container.read(recordFormProvider);
      expect(form.inferredType, 'transfer');
      expect(form.canSave, isFalse);

      notifier.setAccount('acc-a');
      form = container.read(recordFormProvider);
      expect(form.canSave, isFalse);

      notifier.setToAccount('acc-a');
      form = container.read(recordFormProvider);
      expect(form.canSave, isFalse);

      notifier.setToAccount('acc-b');
      form = container.read(recordFormProvider);
      expect(form.canSave, isTrue);
    });
  });

  // ---- 保存行为 ----

  group('保存行为', () {
    test('canSave 为 false 时 save 返回 false', () async {
      final repo = _FakeTransactionRepository();
      final container = makeContainer(txRepo: repo);
      final notifier = container.read(recordFormProvider.notifier);

      final ok = await notifier.save();
      expect(ok, isFalse);
      expect(repo.lastSaved, isNull);
    });

    test('保存成功后 recordMonthSummaryProvider 被 invalidate', () async {
      final repo = _FakeTransactionRepository();
      final container = makeContainer(txRepo: repo);
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-food');
      notifier.onKeyTap('5');
      notifier.onKeyTap('0');

      final ok = await notifier.save();
      expect(ok, isTrue);
      expect(repo.lastSaved, isNotNull);
      expect(repo.lastSaved!.amount, 50);
      expect(repo.lastSaved!.categoryId, 'cat-food');
      expect(repo.lastSaved!.type, 'expense');
    });

    test('保存后不清空表单（由 UI 层 pop 处理）', () async {
      final repo = _FakeTransactionRepository();
      final container = makeContainer(txRepo: repo);
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-food');
      notifier.onKeyTap('2');
      notifier.onKeyTap('0');

      final ok = await notifier.save();
      expect(ok, isTrue);

      final form = container.read(recordFormProvider);
      // 表单未清空（UI pop 负责离开页面）
      expect(form.expression, '20');
      expect(form.amount, 20);
      expect(form.categoryId, 'cat-food');
    });

    test('转账模式保存写入 transfer + toAccountId 且 categoryId 为空', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = _FakeTransactionRepository();
      final container = makeContainer(txRepo: repo);
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setTransferMode(true);
      notifier.setAccount('acc-out');
      notifier.setToAccount('acc-in');
      notifier.onKeyTap('8');
      notifier.onKeyTap('8');

      final ok = await notifier.save();
      expect(ok, isTrue);
      expect(repo.lastSaved, isNotNull);
      expect(repo.lastSaved!.type, 'transfer');
      expect(repo.lastSaved!.accountId, 'acc-out');
      expect(repo.lastSaved!.toAccountId, 'acc-in');
      expect(repo.lastSaved!.categoryId, isNull);
      expect(repo.lastSaved!.amount, 88);
    });

    test('保存时将 attachmentPaths 序列化到 attachmentsEncrypted(JSON utf8)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = _FakeTransactionRepository();
      final container = makeContainer(txRepo: repo);
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-food');
      notifier.onKeyTap('6');
      notifier.onKeyTap('6');

      final current = container.read(recordFormProvider);
      final injected = current.copyWith(
        attachmentPaths: const ['/a/1.jpg', '/a/2.jpg'],
      );
      container.updateOverrides([
        currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId('test-ledger')),
        transactionRepositoryProvider.overrideWith((ref) async => repo),
        ledgerRepositoryProvider.overrideWith(
          (ref) async => _FakeLedgerRepository(ledger: _testLedger()),
        ),
        currentLedgerDefaultCurrencyProvider.overrideWith((ref) async => 'CNY'),
        fxRatesProvider.overrideWith(
          (ref) async => const {'CNY': 1.0, 'USD': 7.2},
        ),
      ]);
      container.read(recordFormProvider.notifier).state = injected;

      final ok = await notifier.save();
      expect(ok, isTrue);
      expect(repo.lastSaved, isNotNull);
      final bytes = repo.lastSaved!.attachmentsEncrypted;
      expect(bytes, isNotNull);
      final decoded = jsonDecode(utf8.decode(bytes!)) as List<dynamic>;
      expect(decoded, ['/a/1.jpg', '/a/2.jpg']);
    });
  });

  // ---- Step 8.2：币种选择 + fxRate 写入 ----

  group('Step 8.2 币种与汇率', () {
    test('setCurrency 直接写入 form.currency', () {
      final container = makeContainer();
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCurrency('USD');
      expect(container.read(recordFormProvider).currency, 'USD');

      notifier.setCurrency('EUR');
      expect(container.read(recordFormProvider).currency, 'EUR');
    });

    test('initDefaultCurrency 把 form.currency 设为账本默认币种', () async {
      final container = makeContainer(ledgerCurrency: 'USD');
      final notifier = container.read(recordFormProvider.notifier);

      // 初值是 'CNY'（RecordFormData 默认）
      expect(container.read(recordFormProvider).currency, 'CNY');

      await notifier.initDefaultCurrency();
      expect(container.read(recordFormProvider).currency, 'USD');
    });

    test('initDefaultCurrency 在已选非 CNY 时不覆盖（避免覆盖用户选择）', () async {
      final container = makeContainer(ledgerCurrency: 'CNY');
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCurrency('JPY');
      expect(container.read(recordFormProvider).currency, 'JPY');

      await notifier.initDefaultCurrency();
      // 已是非 CNY，跳过
      expect(container.read(recordFormProvider).currency, 'JPY');
    });

    test('save 时写入 currency = "USD" 且 fxRate = 7.2（账本默认 CNY）', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = _FakeTransactionRepository();
      final container = makeContainer(
        txRepo: repo,
        ledgerCurrency: 'CNY',
        fxRates: const {'CNY': 1.0, 'USD': 7.2, 'EUR': 7.85},
      );
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-food');
      notifier.setCurrency('USD');
      notifier.onKeyTap('1');
      notifier.onKeyTap('0');

      final ok = await notifier.save();
      expect(ok, isTrue);
      expect(repo.lastSaved, isNotNull);
      expect(repo.lastSaved!.amount, 10);
      expect(repo.lastSaved!.currency, 'USD');
      expect(repo.lastSaved!.fxRate, closeTo(7.2, 1e-9));
      // 折合金额 = 10 * 7.2 = 72 CNY
      expect(
        repo.lastSaved!.amount * repo.lastSaved!.fxRate,
        closeTo(72.0, 1e-9),
      );
    });

    test('save 时同币种 fxRate = 1.0', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = _FakeTransactionRepository();
      final container = makeContainer(
        txRepo: repo,
        ledgerCurrency: 'CNY',
      );
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-food');
      // currency 默认 'CNY' = 账本默认
      notifier.onKeyTap('5');
      notifier.onKeyTap('0');

      final ok = await notifier.save();
      expect(ok, isTrue);
      expect(repo.lastSaved!.currency, 'CNY');
      expect(repo.lastSaved!.fxRate, 1.0);
    });

    test('save 时跨币种到 USD 账本：CNY 50 → fxRate ≈ 1/7.2、折合 ≈ USD 6.94', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = _FakeTransactionRepository();
      final container = makeContainer(
        txRepo: repo,
        ledgerCurrency: 'USD',
      );
      final notifier = container.read(recordFormProvider.notifier);

      notifier.setCategory('cat-food');
      notifier.setCurrency('CNY');
      notifier.onKeyTap('5');
      notifier.onKeyTap('0');

      final ok = await notifier.save();
      expect(ok, isTrue);
      expect(repo.lastSaved!.currency, 'CNY');
      expect(repo.lastSaved!.fxRate, closeTo(1 / 7.2, 1e-9));
      expect(
        repo.lastSaved!.amount * repo.lastSaved!.fxRate,
        closeTo(50 / 7.2, 1e-9),
      );
    });
  });
}
