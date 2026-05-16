import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/account_repository.dart';
import 'package:bianbianbianbian/data/repository/budget_repository.dart';
import 'package:bianbianbianbian/data/repository/category_repository.dart';
import 'package:bianbianbianbian/data/repository/ledger_repository.dart';
import 'package:bianbianbianbian/data/repository/transaction_repository.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/trash/trash_attachment_cleaner.dart';
import 'package:bianbianbianbian/features/trash/trash_gc_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 12 Step 12.3 启动定时清理：核心不变量
/// - cutoff = now - 30 天，分别覆盖流水/分类/账户/账本；
/// - 流水的附件清理先于 DB 硬删（用 fake cleaner 验证调用顺序）；
/// - 未到期项不动；活跃项绝不被清理。
void main() {
  late AppDatabase db;
  late LocalTransactionRepository txRepo;
  late LocalCategoryRepository catRepo;
  late LocalAccountRepository accRepo;
  late LocalLedgerRepository ledgerRepo;
  late LocalBudgetRepository budgetRepo;
  late _RecordingCleaner cleaner;

  late int currentTs;
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(currentTs);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    currentTs = 1714000000000;
    txRepo = LocalTransactionRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
    catRepo = LocalCategoryRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
    accRepo = LocalAccountRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
    ledgerRepo = LocalLedgerRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
    budgetRepo = LocalBudgetRepository(
      db: db,
      deviceId: 'device-test',
      clock: clock,
    );
    cleaner = _RecordingCleaner();
  });

  tearDown(() async {
    await db.close();
  });

  TrashGcService makeService({Duration? retention}) {
    return TrashGcService(
      transactionRepository: txRepo,
      categoryRepository: catRepo,
      accountRepository: accRepo,
      ledgerRepository: ledgerRepo,
      budgetRepository: budgetRepo,
      attachmentCleaner: cleaner,
      retention: retention ?? const Duration(days: 30),
    );
  }

  test('空 DB → 报告全 0 + isEmpty', () async {
    final report = await makeService().gcExpired(now: clock());
    expect(report.transactions, 0);
    expect(report.categories, 0);
    expect(report.accounts, 0);
    expect(report.ledgers, 0);
    expect(report.attachmentsRemoved, 0);
    expect(report.isEmpty, isTrue);
  });

  test('30 天前软删的流水被硬删 + 附件目录被清', () async {
    // 种父 ledger
    await ledgerRepo.save(Ledger(
      id: 'L1',
      name: '生活',
      createdAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
    // 31 天前软删的流水（需要硬删）
    final old = await txRepo.save(TransactionEntry(
      id: 'tx-old',
      ledgerId: 'L1',
      type: 'expense',
      amount: 30,
      currency: 'CNY',
      occurredAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
    currentTs += const Duration(days: 31).inMilliseconds * -1; // 退到 31 天前
    await txRepo.softDeleteById(old.id);
    // 时光回正：now 比 deletedAt 大 31 天
    currentTs += const Duration(days: 31).inMilliseconds;

    // 13 天前软删的流水（不应被硬删）
    final fresh = await txRepo.save(TransactionEntry(
      id: 'tx-fresh',
      ledgerId: 'L1',
      type: 'expense',
      amount: 50,
      currency: 'CNY',
      occurredAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
    final freshDeletedAt = currentTs - const Duration(days: 13).inMilliseconds;
    final savedTs = currentTs;
    currentTs = freshDeletedAt;
    await txRepo.softDeleteById(fresh.id);
    currentTs = savedTs;

    final report = await makeService().gcExpired(now: clock());

    expect(report.transactions, 1, reason: '只清 31 天前的');
    expect(cleaner.deletedTxIds, ['tx-old']);
    expect(report.attachmentsRemoved, 1, reason: 'fake cleaner 默认 deleteForTransaction 返回 true');

    // 仍能在 listDeleted 找到 fresh（13 天前），但 old 已物理消失
    final remainingDeleted = await txRepo.listDeleted();
    expect(remainingDeleted.map((t) => t.id), ['tx-fresh']);
  });

  test('cutoff 在分类/账户/账本各类生效', () async {
    // 31 天前软删的分类 + 账户 + 账本
    final c = await catRepo.save(Category(
      id: 'cat-1',
      parentKey: 'food',
      name: '午餐',
      sortOrder: 0,
      isFavorite: false,
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
    final a = await accRepo.save(Account(
      id: 'acc-1',
      name: '现金',
      type: 'cash',
      initialBalance: 0,
      includeInTotal: true,
      currency: 'CNY',
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
    final l = await ledgerRepo.save(Ledger(
      id: 'L-purge',
      name: '过期账本',
      createdAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));

    // 把 deleted_at 设到 31 天前
    final deletedTs = currentTs - const Duration(days: 31).inMilliseconds;
    final savedTs = currentTs;
    currentTs = deletedTs;
    await catRepo.softDeleteById(c.id);
    await accRepo.softDeleteById(a.id);
    await ledgerRepo.softDeleteById(l.id);
    currentTs = savedTs;

    final report = await makeService().gcExpired(now: clock());
    expect(report.categories, 1);
    expect(report.accounts, 1);
    expect(report.ledgers, 1);

    expect(await catRepo.listDeleted(), isEmpty);
    expect(await accRepo.listDeleted(), isEmpty);
    expect(await ledgerRepo.listDeleted(), isEmpty);
  });

  test('活跃项绝不被 GC 触碰', () async {
    await ledgerRepo.save(Ledger(
      id: 'L1',
      name: 'active',
      createdAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
    await txRepo.save(TransactionEntry(
      id: 'tx-active',
      ledgerId: 'L1',
      type: 'expense',
      amount: 10,
      currency: 'CNY',
      occurredAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));

    await makeService().gcExpired(now: clock());

    final activeTx = await txRepo.listActiveByLedger('L1');
    expect(activeTx.length, 1);
    final activeLedgers = await ledgerRepo.listActive();
    expect(activeLedgers.length, 1);
    expect(cleaner.deletedTxIds, isEmpty);
  });

  test('自定义 retention=7 天：8 天前软删的项被清', () async {
    await ledgerRepo.save(Ledger(
      id: 'L1',
      name: 'x',
      createdAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
    final tx = await txRepo.save(TransactionEntry(
      id: 'tx-1',
      ledgerId: 'L1',
      type: 'expense',
      amount: 10,
      currency: 'CNY',
      occurredAt: clock(),
      updatedAt: clock(),
      deviceId: 'device-test',
    ));
    final softTs = currentTs - const Duration(days: 8).inMilliseconds;
    final savedTs = currentTs;
    currentTs = softTs;
    await txRepo.softDeleteById(tx.id);
    currentTs = savedTs;

    final report = await makeService(retention: const Duration(days: 7))
        .gcExpired(now: clock());
    expect(report.transactions, 1);
  });
}

/// Fake 附件清理器：记录被调用的 txId，默认返回 true（"成功删除"）。
class _RecordingCleaner implements TrashAttachmentCleaner {
  final List<String> deletedTxIds = [];

  @override
  Future<bool> deleteForTransaction(String txId) async {
    deletedTxIds.add(txId);
    return true;
  }

  @override
  Future<int> deleteForTransactions(Iterable<String> txIds) async {
    var ok = 0;
    for (final id in txIds) {
      if (await deleteForTransaction(id)) ok++;
    }
    return ok;
  }
}
