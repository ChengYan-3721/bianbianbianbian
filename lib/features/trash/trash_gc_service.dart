import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/account_repository.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/category_repository.dart';
import '../../data/repository/ledger_repository.dart';
import '../../data/repository/providers.dart';
import '../../data/repository/transaction_repository.dart';
import 'trash_attachment_cleaner.dart';
import 'trash_providers.dart';

/// Phase 12 Step 12.3 启动定时清理服务。`gcExpired(now)` 在 App 启动时由
/// `main.dart` bootstrap 链 fire-and-forget 触发；行为：
///
/// 1. 计算 `cutoff = now - kTrashRetention`（默认 30 天）；
/// 2. 4 类实体（流水/分类/账户/账本）各自调 `repo.listExpired(cutoff)` 取全部
///    超期软删项；
/// 3. **流水**：先调 [TrashAttachmentCleaner.deleteForTransactions] 物理删除
///    `<documents>/attachments/<txId>/` 目录，再 `repo.purgeById` 硬删 DB 行；
/// 4. **账本**：`purgeById` 自身级联硬删该账本下所有流水/预算（[LedgerRepository]
///    的契约），但**不**清流水附件——为了保险，账本超期前会先把它下属流水
///    各自的 `deleted_at` 推到同一时间戳，所以 TX GC 路径会先一步处理附件。
///    冷启动多账本同时过期时，TX 先于 Ledger GC 执行，附件也已被清。
/// 5. 分类 / 账户：仅硬删行（无附件 / 无级联依赖）。
///
/// 返回 [TrashGcReport]：四类实体各自删了多少条 + 附件目录清理统计——供 UI
/// 调试或未来"上次清理报告"展示。
class TrashGcReport {
  const TrashGcReport({
    required this.transactions,
    required this.attachmentsRemoved,
    required this.categories,
    required this.accounts,
    required this.ledgers,
  });

  final int transactions;
  final int attachmentsRemoved;
  final int categories;
  final int accounts;
  final int ledgers;

  bool get isEmpty =>
      transactions == 0 &&
      categories == 0 &&
      accounts == 0 &&
      ledgers == 0;

  @override
  String toString() =>
      'TrashGcReport(tx=$transactions, att=$attachmentsRemoved, '
      'cat=$categories, acc=$accounts, ledger=$ledgers)';
}

class TrashGcService {
  TrashGcService({
    required this.transactionRepository,
    required this.categoryRepository,
    required this.accountRepository,
    required this.ledgerRepository,
    required this.budgetRepository,
    required this.attachmentCleaner,
    Duration retention = kTrashRetention,
  }) : _retention = retention;

  final TransactionRepository transactionRepository;
  final CategoryRepository categoryRepository;
  final AccountRepository accountRepository;
  final LedgerRepository ledgerRepository;
  final BudgetRepository budgetRepository;
  final TrashAttachmentCleaner attachmentCleaner;
  final Duration _retention;

  /// 一次性扫描并硬删全部超期软删项。
  /// `now` 显式注入便于测试锁定参考时间。
  Future<TrashGcReport> gcExpired({required DateTime now}) async {
    final cutoff = now.subtract(_retention);

    // 1. 流水：附件 GC 先于 DB 硬删——
    //    DB 行硬删后再去查附件路径会丢失映射；保守做法是用 txId 直接删目录。
    final expiredTx = await transactionRepository.listExpired(cutoff);
    var attachments = 0;
    var txCount = 0;
    for (final tx in expiredTx) {
      if (await attachmentCleaner.deleteForTransaction(tx.id)) attachments++;
      txCount += await transactionRepository.purgeById(tx.id);
    }

    // 2. 预算：UI 不暴露但仍要 GC（账本级联软删的预算可能超期）。
    final expiredBudgets = await budgetRepository.listExpired(cutoff);
    for (final b in expiredBudgets) {
      await budgetRepository.purgeById(b.id);
    }

    // 3. 分类。
    final expiredCats = await categoryRepository.listExpired(cutoff);
    var catCount = 0;
    for (final c in expiredCats) {
      catCount += await categoryRepository.purgeById(c.id);
    }

    // 4. 账户。
    final expiredAccs = await accountRepository.listExpired(cutoff);
    var accCount = 0;
    for (final a in expiredAccs) {
      accCount += await accountRepository.purgeById(a.id);
    }

    // 5. 账本——`purgeById` 自身级联硬删该账本下流水/预算；附件已由 step 1 处理。
    final expiredLedgers = await ledgerRepository.listExpired(cutoff);
    var ledgerCount = 0;
    for (final l in expiredLedgers) {
      ledgerCount += await ledgerRepository.purgeById(l.id);
    }

    return TrashGcReport(
      transactions: txCount,
      attachmentsRemoved: attachments,
      categories: catCount,
      accounts: accCount,
      ledgers: ledgerCount,
    );
  }
}

/// `keepAlive` 单例。由 main.dart 在 bootstrap 链中 fire-and-forget 触发一次。
final trashGcServiceProvider = FutureProvider<TrashGcService>((ref) async {
  final tx = await ref.watch(transactionRepositoryProvider.future);
  final cat = await ref.watch(categoryRepositoryProvider.future);
  final acc = await ref.watch(accountRepositoryProvider.future);
  final ledger = await ref.watch(ledgerRepositoryProvider.future);
  final budget = await ref.watch(budgetRepositoryProvider.future);
  final cleaner = ref.watch(trashAttachmentCleanerProvider);
  return TrashGcService(
    transactionRepository: tx,
    categoryRepository: cat,
    accountRepository: acc,
    ledgerRepository: ledger,
    budgetRepository: budget,
    attachmentCleaner: cleaner,
  );
});
