import 'package:flutter/foundation.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/local/attachment_meta_codec.dart';
import '../../data/local/providers.dart' as local;
import '../../data/repository/account_repository.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/category_repository.dart';
import '../../data/repository/ledger_repository.dart';
import '../../data/repository/providers.dart';
import '../../data/repository/transaction_repository.dart';
import '../sync/attachment/attachment_providers.dart';
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
/// **Step 11.4 扩展**：硬删流水时除了 documents 目录还要删远端对象。
/// 流程在 `TX 循环` 内：① 解码该流水的 BLOB → 收集 `remoteKey != null` 的 meta；
/// ② 逐条 `attachmentStorage.delete(path: key)`，单条失败 `debugPrint` 后继续，
/// 不阻塞硬删（孤儿 sweep 会兜底）；③ 删 documents 目录；④ purgeById。
/// `attachmentStorage == null`（未配置云服务）时跳过远端删除——本地附件仍走
/// documents 清理。
///
/// 返回 [TrashGcReport]：四类实体各自删了多少条 + 附件目录清理 + 远端对象
/// 删除统计——供 UI 调试或未来"上次清理报告"展示。
class TrashGcReport {
  const TrashGcReport({
    required this.transactions,
    required this.attachmentsRemoved,
    required this.categories,
    required this.accounts,
    required this.ledgers,
    this.remoteAttachmentsDeleted = 0,
    this.remoteAttachmentsFailed = 0,
  });

  final int transactions;
  final int attachmentsRemoved;
  final int categories;
  final int accounts;
  final int ledgers;

  /// Step 11.4：硬删时通过 [CloudStorageService.delete] 真实删除的远端对象数。
  final int remoteAttachmentsDeleted;

  /// Step 11.4：远端 delete 抛异常被跳过的对象数（log 已打）。下次孤儿 sweep
  /// 会按 lastModified 兜底。
  final int remoteAttachmentsFailed;

  bool get isEmpty =>
      transactions == 0 &&
      categories == 0 &&
      accounts == 0 &&
      ledgers == 0;

  @override
  String toString() =>
      'TrashGcReport(tx=$transactions, att=$attachmentsRemoved, '
      'remoteDel=$remoteAttachmentsDeleted, remoteFail=$remoteAttachmentsFailed, '
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
    this.db,
    this.attachmentStorage,
  }) : _retention = retention;

  final TransactionRepository transactionRepository;
  final CategoryRepository categoryRepository;
  final AccountRepository accountRepository;
  final LedgerRepository ledgerRepository;
  final BudgetRepository budgetRepository;
  final TrashAttachmentCleaner attachmentCleaner;

  /// Step 11.4：可选的 DB 句柄——读流水的 `attachments_encrypted` BLOB 找出
  /// `remoteKey` 集合。`null` 时跳过远端删除（保留兼容旧调用 + 单测）。
  final AppDatabase? db;

  /// Step 11.4：可选的远端存储——`null` 表示未配置云服务或 local-only 模式，
  /// 此时只删 documents 不删远端。
  final CloudStorageService? attachmentStorage;

  final Duration _retention;

  /// 一次性扫描并硬删全部超期软删项。
  /// `now` 显式注入便于测试锁定参考时间。
  Future<TrashGcReport> gcExpired({required DateTime now}) async {
    final cutoff = now.subtract(_retention);

    // 1. 流水：附件 GC 先于 DB 硬删——
    //    DB 行硬删后再去查附件路径会丢失映射；保守做法是用 txId 直接删目录。
    final expiredTx = await transactionRepository.listExpired(cutoff);
    var attachments = 0;
    var remoteDeleted = 0;
    var remoteFailed = 0;
    var txCount = 0;
    for (final tx in expiredTx) {
      // Step 11.4：远端附件删除（best-effort，不阻塞硬删）。
      // 必须在 purgeById 之前——硬删后 BLOB 就读不到了。
      if (db != null && attachmentStorage != null) {
        final remoteKeys = await _collectRemoteKeysForTx(db!, tx.id);
        for (final key in remoteKeys) {
          try {
            await attachmentStorage!.delete(path: key);
            remoteDeleted++;
          } catch (e, st) {
            debugPrint(
              'TrashGcService: remote delete $key failed — $e\n$st',
            );
            remoteFailed++;
          }
        }
      }
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
      remoteAttachmentsDeleted: remoteDeleted,
      remoteAttachmentsFailed: remoteFailed,
      categories: catCount,
      accounts: accCount,
      ledgers: ledgerCount,
    );
  }

  /// 解码指定 txId 行的 `attachments_encrypted`，返回所有 `remoteKey != null`
  /// 的 key 列表。不存在 / 空 BLOB / 无远端引用 → 返回 const []。
  ///
  /// 同 sha256 跨 tx 不去重（Phase 11.2 决策）；本方法只看单条流水，所以
  /// 列表内同 path 至多出现一次（用户给同一笔流水加了同图两次也只算一次远端
  /// 对象——和 [AttachmentUploader] 同 sha256 命中 exists 跳过的语义一致）。
  Future<List<String>> _collectRemoteKeysForTx(
    AppDatabase database,
    String txId,
  ) async {
    final row = await (database.select(database.transactionEntryTable)
          ..where((t) => t.id.equals(txId)))
        .getSingleOrNull();
    if (row == null) return const [];
    final blob = row.attachmentsEncrypted;
    if (blob == null || blob.isEmpty) return const [];
    final metas = AttachmentMetaCodec.decode(blob);
    final out = <String>[];
    for (final m in metas) {
      final key = m.remoteKey;
      if (key != null) out.add(key);
    }
    return out;
  }
}

/// `keepAlive` 单例。由 main.dart 在 bootstrap 链中 fire-and-forget 触发一次。
///
/// Step 11.4：附加注入 `appDatabase` + `attachmentStorageService`（nullable）
/// 让 GC 路径具备远端 delete 能力。未配置云服务时 storage 解析为 null，
/// 服务内部跳过远端步骤。
final trashGcServiceProvider = FutureProvider<TrashGcService>((ref) async {
  final tx = await ref.watch(transactionRepositoryProvider.future);
  final cat = await ref.watch(categoryRepositoryProvider.future);
  final acc = await ref.watch(accountRepositoryProvider.future);
  final ledger = await ref.watch(ledgerRepositoryProvider.future);
  final budget = await ref.watch(budgetRepositoryProvider.future);
  final cleaner = ref.watch(trashAttachmentCleanerProvider);
  final storage = await ref.watch(attachmentStorageServiceProvider.future);
  final db = ref.watch(local.appDatabaseProvider);
  return TrashGcService(
    transactionRepository: tx,
    categoryRepository: cat,
    accountRepository: acc,
    ledgerRepository: ledger,
    budgetRepository: budget,
    attachmentCleaner: cleaner,
    db: db,
    attachmentStorage: storage,
  );
});
