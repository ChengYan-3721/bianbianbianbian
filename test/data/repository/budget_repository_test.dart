import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/budget_repository.dart';
import 'package:bianbianbianbian/domain/entity/budget.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 6.1 验收：同账本 + 同周期 + 同分类（含 categoryId=null 总预算）
/// 只能存在一个未软删的预算。
void main() {
  late AppDatabase db;
  late BudgetRepository repo;

  const fixedTs = 1714000000000;
  DateTime fixedClock() => DateTime.fromMillisecondsSinceEpoch(fixedTs);

  Budget makeBudget({
    required String id,
    String ledgerId = 'ledger-1',
    String period = 'monthly',
    String? categoryId,
    double amount = 1000,
    bool carryOver = false,
  }) {
    return Budget(
      id: id,
      ledgerId: ledgerId,
      period: period,
      categoryId: categoryId,
      amount: amount,
      carryOver: carryOver,
      startDate: DateTime.fromMillisecondsSinceEpoch(fixedTs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fixedTs),
      deviceId: 'device-test',
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalBudgetRepository(
      db: db,
      deviceId: 'device-test',
      clock: fixedClock,
    );
    // 种子父 ledger
    await db.into(db.ledgerTable).insert(
          LedgerTableCompanion.insert(
            id: 'ledger-1',
            name: '生活',
            createdAt: fixedTs,
            updatedAt: fixedTs,
            deviceId: 'device-seed',
          ),
        );
    await db.into(db.ledgerTable).insert(
          LedgerTableCompanion.insert(
            id: 'ledger-2',
            name: '工作',
            createdAt: fixedTs,
            updatedAt: fixedTs,
            deviceId: 'device-seed',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('同账本同周期同分类（categoryId 非空）二次保存抛 BudgetConflictException', () async {
    await repo.save(makeBudget(id: 'b-1', categoryId: 'cat-food'));
    expect(
      () => repo.save(makeBudget(id: 'b-2', categoryId: 'cat-food')),
      throwsA(isA<BudgetConflictException>()),
    );
  });

  test('同账本同周期 categoryId=null 总预算二次保存抛冲突', () async {
    await repo.save(makeBudget(id: 'b-total-1'));
    expect(
      () => repo.save(makeBudget(id: 'b-total-2')),
      throwsA(isA<BudgetConflictException>()),
    );
  });

  test('同账本同周期不同分类可共存', () async {
    await repo.save(makeBudget(id: 'b-food', categoryId: 'cat-food'));
    await repo.save(makeBudget(id: 'b-shop', categoryId: 'cat-shop'));
    final list = await repo.listActiveByLedger('ledger-1');
    expect(list, hasLength(2));
  });

  test('总预算与同账本同周期分类预算可共存', () async {
    await repo.save(makeBudget(id: 'b-total'));
    await repo.save(makeBudget(id: 'b-food', categoryId: 'cat-food'));
    final list = await repo.listActiveByLedger('ledger-1');
    expect(list, hasLength(2));
  });

  test('同分类不同周期（月 / 年）可共存', () async {
    await repo.save(
      makeBudget(id: 'b-food-month', period: 'monthly', categoryId: 'cat-food'),
    );
    await repo.save(
      makeBudget(id: 'b-food-year', period: 'yearly', categoryId: 'cat-food'),
    );
    final list = await repo.listActiveByLedger('ledger-1');
    expect(list, hasLength(2));
  });

  test('不同账本同周期同分类可共存', () async {
    await repo.save(
      makeBudget(id: 'b-l1', ledgerId: 'ledger-1', categoryId: 'cat-food'),
    );
    await repo.save(
      makeBudget(id: 'b-l2', ledgerId: 'ledger-2', categoryId: 'cat-food'),
    );
    final l1 = await repo.listActiveByLedger('ledger-1');
    final l2 = await repo.listActiveByLedger('ledger-2');
    expect(l1, hasLength(1));
    expect(l2, hasLength(1));
  });

  test('同 id 二次保存视为更新，不算冲突', () async {
    final saved = await repo.save(
      makeBudget(id: 'b-1', categoryId: 'cat-food', amount: 1000),
    );
    final updated = await repo.save(
      saved.copyWith(amount: 2000),
    );
    expect(updated.amount, 2000);
    final list = await repo.listActiveByLedger('ledger-1');
    expect(list, hasLength(1));
    expect(list.first.amount, 2000);
  });

  test('软删除已存在预算后允许重建同分类同周期', () async {
    final saved = await repo.save(
      makeBudget(id: 'b-1', categoryId: 'cat-food'),
    );
    await repo.softDeleteById(saved.id);
    // 软删后不再阻塞同 (ledger, period, category) 的新预算
    await repo.save(makeBudget(id: 'b-2', categoryId: 'cat-food'));
    final list = await repo.listActiveByLedger('ledger-1');
    expect(list, hasLength(1));
    expect(list.first.id, 'b-2');
  });
}
