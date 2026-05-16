import 'package:bianbianbianbian/data/repository/providers.dart';
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/record/record_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('daysSinceLastTransactionProvider', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('returns null when no transactions', () async {
      final repo = _FakeTxRepo(latestAt: null);
      container = ProviderContainer(overrides: [
        currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId('l1')),
        transactionRepositoryProvider.overrideWith((ref) async => repo),
      ]);
      final days = await container.read(daysSinceLastTransactionProvider.future);
      expect(days, isNull);
    });

    test('returns 0 when last transaction is today', () async {
      final repo = _FakeTxRepo(latestAt: DateTime.now());
      container = ProviderContainer(overrides: [
        currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId('l1')),
        transactionRepositoryProvider.overrideWith((ref) async => repo),
      ]);
      final days = await container.read(daysSinceLastTransactionProvider.future);
      expect(days, 0);
    });

    test('returns 3 when last transaction was 3 days ago', () async {
      final repo = _FakeTxRepo(
          latestAt: DateTime.now().subtract(const Duration(days: 3)));
      container = ProviderContainer(overrides: [
        currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId('l1')),
        transactionRepositoryProvider.overrideWith((ref) async => repo),
      ]);
      final days = await container.read(daysSinceLastTransactionProvider.future);
      expect(days, 3);
    });

    test('returns 1 when last transaction was yesterday', () async {
      final repo = _FakeTxRepo(
          latestAt: DateTime.now().subtract(const Duration(days: 1)));
      container = ProviderContainer(overrides: [
        currentLedgerIdProvider.overrideWith(() => _TestCurrentLedgerId('l1')),
        transactionRepositoryProvider.overrideWith((ref) async => repo),
      ]);
      final days = await container.read(daysSinceLastTransactionProvider.future);
      expect(days, 1);
    });
  });

  group('IdleReminderShownDate', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('initially returns null', () async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      final date = await container.read(idleReminderShownDateProvider.future);
      expect(date, isNull);
    });

    test('markToday persists today date', () async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      await container.read(idleReminderShownDateProvider.notifier).markToday();
      final date = container.read(idleReminderShownDateProvider).valueOrNull;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      expect(date, today);
    });

    test('markToday survives container recreation', () async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      await container.read(idleReminderShownDateProvider.notifier).markToday();
      container.dispose();

      final container2 = ProviderContainer();
      final date = await container2.read(idleReminderShownDateProvider.future);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      expect(date, today);
      container2.dispose();
    });

    test('previously set date returns correctly', () async {
      final yesterday =
          DateFormat('yyyy-MM-dd')
              .format(DateTime.now().subtract(const Duration(days: 1)));
      SharedPreferences.setMockInitialValues({
        'idle_reminder_last_date': yesterday,
      });
      container = ProviderContainer();
      final date = await container.read(idleReminderShownDateProvider.future);
      expect(date, yesterday);
    });
  });
}

class _TestCurrentLedgerId extends CurrentLedgerId {
  _TestCurrentLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
}

/// 测试用仓库——只实现 [latestOccurredAtByLedger]，其余方法不可调用。
class _FakeTxRepo implements TransactionRepository {
  _FakeTxRepo({this.latestAt});

  final DateTime? latestAt;

  @override
  Future<DateTime?> latestOccurredAtByLedger(String ledgerId) async => latestAt;

  @override
  Future<List<TransactionEntry>> listActiveByLedger(String ledgerId) =>
      throw UnimplementedError();
  @override
  Future<TransactionEntry> save(TransactionEntry entity) =>
      throw UnimplementedError();
  @override
  Future<void> softDeleteById(String id) => throw UnimplementedError();
  @override
  Future<int> softDeleteByLedgerId(String ledgerId) =>
      throw UnimplementedError();
  @override
  Future<List<TransactionEntry>> listDeleted() => throw UnimplementedError();
  @override
  Future<void> restoreById(String id) => throw UnimplementedError();
  @override
  Future<int> purgeById(String id) => throw UnimplementedError();
  @override
  Future<int> purgeAllDeleted() => throw UnimplementedError();
  @override
  Future<List<TransactionEntry>> listExpired(DateTime cutoff) =>
      throw UnimplementedError();
}
