import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import '../../data/local/app_database.dart';
import '../../data/local/attachment_meta_codec.dart';
import '../../data/repository/account_repository.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/category_repository.dart';
import '../../data/repository/ledger_repository.dart';
import '../../data/repository/transaction_repository.dart';
import '../../domain/entity/attachment_meta.dart';
import 'attachment/attachment_uploader.dart';
import 'snapshot_serializer.dart';

/// V1 同步服务：账本快照模型（整库 upload / 整库 download / 指纹比对）。
///
/// **不**实现 implementation-plan §10.2 的 sync_op 队列 + LWW 增量合并；
/// 那是 V2 多设备双向同步的形态。V1 选择与"参考方案"（蜜蜂记账）一致的
/// 简化：账本视为一个 JSON 文件，每次上传/下载是整体覆盖。
abstract class SyncService {
  /// 上传当前账本快照到云端（覆盖现有备份）。
  Future<void> upload({required String ledgerId});

  /// 从云端下载快照并恢复到本地（覆盖式）。
  /// 返回写入的流水条数；云端不存在备份时返回 0。
  Future<int> downloadAndRestore({required String ledgerId});

  /// 当前账本的同步状态。`forceRefresh=true` 跳过 cache 重新拉云端。
  Future<SyncStatus> getStatus({
    required String ledgerId,
    bool forceRefresh = false,
  });

  /// 删除云端备份。云端无备份视为成功（幂等）。
  Future<void> deleteRemote({required String ledgerId});

  /// 清除内部状态缓存。本地数据变更后调用，强制下次 [getStatus] 重算。
  void clearCache();
}

/// 未配置或未激活云服务时的兜底实现——所有操作抛 [UnsupportedError]，
/// [getStatus] 返回 [SyncState.notConfigured]。
class LocalOnlySyncService implements SyncService {
  const LocalOnlySyncService();

  @override
  Future<void> upload({required String ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<int> downloadAndRestore({required String ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<SyncStatus> getStatus({
    required String ledgerId,
    bool forceRefresh = false,
  }) async {
    return const SyncStatus(
      state: SyncState.notConfigured,
      message: '__SYNC_NOT_CONFIGURED__',
    );
  }

  @override
  Future<void> deleteRemote({required String ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  void clearCache() {}
}

/// 快照模式同步服务（V1）：把账本视作一个文件，整体上传/下载/对比。
class SnapshotSyncService implements SyncService {
  SnapshotSyncService({
    required CloudSyncManager<LedgerSnapshot> manager,
    required AppDatabase db,
    required String deviceId,
    required LedgerRepository ledgerRepo,
    required CategoryRepository categoryRepo,
    required AccountRepository accountRepo,
    required TransactionRepository transactionRepo,
    required BudgetRepository budgetRepo,
  })  : _manager = manager,
        _db = db,
        _deviceId = deviceId,
        _ledgerRepo = ledgerRepo,
        _categoryRepo = categoryRepo,
        _accountRepo = accountRepo,
        _transactionRepo = transactionRepo,
        _budgetRepo = budgetRepo;

  final CloudSyncManager<LedgerSnapshot> _manager;
  final AppDatabase _db;
  final String _deviceId;
  final LedgerRepository _ledgerRepo;
  final CategoryRepository _categoryRepo;
  final AccountRepository _accountRepo;
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;

  /// 云端路径——与"蜜蜂记账云同步方案.md"约定一致：
  /// `users/<userId>/ledgers/<ledgerId>.json`。
  ///
  /// Supabase RLS 依赖 `(storage.foldername(name))[1] = 'users'` AND
  /// `(storage.foldername(name))[2] = auth.uid()`，所以 `userId` 必须等于
  /// `auth.uid()`。其他 backend（WebDAV/iCloud/S3）不强制此格式，但保留
  /// `users/<deviceId>/...` 前缀以统一目录结构。
  Future<String> _path(String ledgerId) async {
    final user = await _manager.provider.auth.currentUser;
    final userId = user?.id ?? _deviceId;
    return 'users/$userId/ledgers/$ledgerId.json';
  }

  Future<LedgerSnapshot> _exportLocal(String ledgerId) {
    return exportLedgerSnapshot(
      ledgerId: ledgerId,
      deviceId: _deviceId,
      ledgerRepo: _ledgerRepo,
      categoryRepo: _categoryRepo,
      accountRepo: _accountRepo,
      transactionRepo: _transactionRepo,
      budgetRepo: _budgetRepo,
    );
  }

  @override
  Future<void> upload({required String ledgerId}) async {
    // Step 11.2：上传 JSON 快照前先把所有 remoteKey == null 的附件上云。
    // 顺序：附件先 → 快照后。这样 B 设备拉到的快照里所有 attachmentsEncrypted
    // 已含 remoteKey，可以走 lazy download 路径（Step 11.3）。
    // 单个附件失败不阻塞快照——uploadPending 会把失败的 meta 留 remoteKey 为
    // null，下次同步重试。
    await _uploadPendingAttachments(ledgerId);

    final snapshot = await _exportLocal(ledgerId);
    final path = await _path(ledgerId);
    await _manager.upload(data: snapshot, path: path);
  }

  /// Step 11.2：扫描指定账本下所有流水的附件元数据，把 `remoteKey == null`
  /// 的项上传到云端，然后把回填的元数据写回 DB。仅在云端可写时调用。
  ///
  /// 实现细节：
  /// 1. 直接从 `_db.transactionEntryTable` 读出（避免穿过 repository 触发
  ///    sync_op 队列）；
  /// 2. 单条流水内的多个附件串行上传——已是 fast path（小于 3 张图）；
  /// 3. 写回时对 `attachments_encrypted` 走 customStatement，**不**改
  ///    `updated_at`——避免因 metadata 回填触发额外的快照「本地较新」判定。
  Future<void> _uploadPendingAttachments(String ledgerId) async {
    final storage = _manager.provider.storage;
    final user = await _manager.provider.auth.currentUser;
    final uid = user?.id ?? _deviceId;

    final txRows = await (_db.select(_db.transactionEntryTable)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..where((t) => t.attachmentsEncrypted.isNotNull()))
        .get();

    for (final row in txRows) {
      final raw = row.attachmentsEncrypted;
      if (raw == null || raw.isEmpty) continue;
      final metas = AttachmentMetaCodec.decode(raw);
      if (metas.isEmpty) continue;

      final hasPending = metas.any((m) => m.remoteKey == null);
      if (!hasPending) continue;

      final uploader = AttachmentUploader(storage: storage);
      final List<AttachmentMeta> updated = await uploader.uploadPending(
        metas,
        txId: row.id,
        uid: uid,
      );

      // 没有任何 meta 真的被回填（全部失败 / 全部跳过）→ 跳过 DB 写入。
      final changed = !_metasEqual(updated, metas);
      if (!changed) continue;

      final encoded = AttachmentMetaCodec.encode(updated);
      await _db.customStatement(
        'UPDATE transaction_entry SET attachments_encrypted = ? WHERE id = ?',
        [encoded, row.id],
      );
    }
  }

  bool _metasEqual(List<AttachmentMeta> a, List<AttachmentMeta> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<int> downloadAndRestore({required String ledgerId}) async {
    final path = await _path(ledgerId);
    final snapshot = await _manager.download(path: path);
    if (snapshot == null) return 0;
    if (snapshot.ledger.id != ledgerId) {
      throw StateError(
        'Snapshot ledger id mismatch: expected $ledgerId, '
        'got ${snapshot.ledger.id}',
      );
    }
    return importLedgerSnapshot(snapshot: snapshot, db: _db);
  }

  @override
  Future<SyncStatus> getStatus({
    required String ledgerId,
    bool forceRefresh = false,
  }) async {
    final snapshot = await _exportLocal(ledgerId);
    final path = await _path(ledgerId);
    return _manager.getStatus(
      data: snapshot,
      path: path,
      localUpdatedAt: snapshot.exportedAt,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<void> deleteRemote({required String ledgerId}) async {
    final path = await _path(ledgerId);
    try {
      await _manager.deleteRemote(path: path);
    } on CloudStorageException {
      // 云端已不存在视为幂等成功。
    }
  }

  @override
  void clearCache() => _manager.clearCache();
}
