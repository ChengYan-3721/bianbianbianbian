import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/entity_mappers.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/budget.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/ledger.dart';
import '../../domain/entity/transaction_entry.dart';
import 'cloud_backup_discovery.dart';
import 'snapshot_serializer.dart';
import 'sync_service.dart';

abstract class IncrementalCloudGateway {
  Future<void> upsertBatch({
    required String table,
    required List<Map<String, dynamic>> data,
  });

  Future<void> deleteBatch({
    required String table,
    required List<String> ids,
  });

  /// 返回 `table` 中 `updated_at > updatedAtGt` 的行，按 `(updated_at ASC, id ASC)`
  /// 稳定排序，[offset] 翻页，单批最多 [limit] 行。
  ///
  /// **关键不变量**：同一批次内不同请求即便共享同一个 `updated_at`，也能靠 `id`
  /// 当 tiebreaker 全局有序——典型场景 CSV 批量导入 4000+ 行共用同一毫秒
  /// 时间戳，单 `orderBy='updated_at'` 翻页会卡死。
  Future<List<Map<String, dynamic>>> queryUpdatedSince({
    required String table,
    required int updatedAtGt,
    required int limit,
    int offset = 0,
  });

  Future<void> deleteAll(String table);
}

class SupabaseIncrementalGateway implements IncrementalCloudGateway {
  SupabaseIncrementalGateway(this._database);
  final SupabaseDatabaseService _database;

  @override
  Future<void> upsertBatch({
    required String table,
    required List<Map<String, dynamic>> data,
  }) {
    return _database.upsertBatch(table: table, data: data);
  }

  @override
  Future<List<Map<String, dynamic>>> queryUpdatedSince({
    required String table,
    required int updatedAtGt,
    required int limit,
    int offset = 0,
  }) {
    return _database.queryStablePaginated(
      table: table,
      filters: [QueryFilter.gt('updated_at', updatedAtGt)],
      primaryOrderBy: 'updated_at',
      secondaryOrderBy: 'id',
      offset: offset,
      limit: limit,
    );
  }

  @override
  Future<void> deleteAll(String table) async {
    await _database.deleteAllUserData(table: table);
  }

  @override
  Future<void> deleteBatch({
    required String table,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return;
    await _database.batchDelete(
      table: table,
      filters: [QueryFilter.inList('id', ids)],
    );
  }
}

class IncrementalSyncService implements SyncService {
  IncrementalSyncService({
    required IncrementalCloudGateway gateway,
    required AppDatabase db,
    required String deviceId,
    DateTime Function() clock = DateTime.now,
  })  : _gateway = gateway,
        _db = db,
        _deviceId = deviceId,
        _clock = clock;

  final IncrementalCloudGateway _gateway;
  final AppDatabase _db;
  final String _deviceId;
  final DateTime Function() _clock;

  static const int _kMaxDrainRounds = 50;
  static const int _kPagePullSize = 1000;

  /// 分批硬删的单批大小。50 个 UUID ≈ 50*36 + 引号逗号 ≈ 2KB URL，
  /// 安全留余 Cloudflare 8KB 上限。
  static const int _kDeleteBatchSize = 50;

  static const List<String> _entityNames = [
    'ledger',
    'category',
    'account',
    'transaction',
    'budget',
  ];

  static const Map<String, List<String>> _dateFieldsByEntity = {
    'ledger': ['created_at', 'updated_at', 'deleted_at'],
    'category': ['updated_at', 'deleted_at'],
    'account': ['updated_at', 'deleted_at'],
    'transaction': ['occurred_at', 'updated_at', 'deleted_at'],
    'budget': ['start_date', 'last_settled_at', 'updated_at', 'deleted_at'],
  };

  static const Map<String, List<String>> _boolFieldsByEntity = {
    'ledger': ['archived'],
    'category': ['is_favorite'],
    'account': ['include_in_total'],
    'transaction': <String>[],
    'budget': ['carry_over'],
  };

  static String _remoteTableName(String entity) =>
      entity == 'transaction' ? 'transaction_entry' : entity;

  @override
  Future<void> upload({required String ledgerId}) => pullThenPush();

  @override
  Future<int> downloadAndRestore({required String ledgerId}) async {
    throw UnsupportedError(
      'IncrementalSyncService does not support per-ledger download. '
      'Use fullPull() to restore the entire database from cloud.',
    );
  }

  @override
  Future<List<RemoteBackup>> listBackups() async {
    throw UnsupportedError(
      'IncrementalSyncService does not support backup listing. '
      'Use BackupListPage only with S3/WebDAV/iCloud backends.',
    );
  }

  @override
  Future<String> restoreFromBackup(
    RemoteBackup backup, {
    LedgerNameConflictStrategy? conflictStrategy,
    String? renameTo,
  }) async {
    throw UnsupportedError(
      'IncrementalSyncService does not support backup restore.',
    );
  }

  @override
  Future<LedgerNameConflict?> checkLedgerNameConflict(String ledgerName) async {
    throw UnsupportedError(
      'IncrementalSyncService does not have backup name conflicts.',
    );
  }

  @override
  Future<void> deleteBackupAt(String cloudPath) async {
    throw UnsupportedError(
      'IncrementalSyncService does not support per-backup deletion. '
      'Use Supabase Dashboard to manually delete rows if needed.',
    );
  }

  @override
  Future<void> deleteRemote({required String ledgerId}) async {
    throw UnsupportedError(
      'IncrementalSyncService does not support remote deletion. '
      'To reset sync, manually clear cloud tables in Supabase Dashboard '
      'and clear last_pulled_at_json in user_pref.',
    );
  }

  @override
  Future<SyncStatus> getStatus({
    required String ledgerId,
    bool forceRefresh = false,
  }) async {
    final pendingCount = await _countPendingSyncOps();
    final lastSyncedAt = await _readLastSyncedAt();

    if (pendingCount > 0) {
      return SyncStatus(
        state: SyncState.outOfSync,
        direction: SyncDirection.localNewer,
        localCount: pendingCount,
        lastSyncedAt: lastSyncedAt,
      );
    }
    if (lastSyncedAt == null) {
      return const SyncStatus(state: SyncState.localOnly);
    }
    return SyncStatus(
      state: SyncState.synced,
      lastSyncedAt: lastSyncedAt,
    );
  }

  @override
  void clearCache() {}

  @override
  Future<void> forcePushAll() async {
    // 单遍策略：先推送本地全部行（清空 sync_op + 重新入队 + drain），然后从云端
    // id 集 diff 出云端独有的 id，分批硬删。这样不会出现「云端看空表」的中间态。
    // 1. 推送本地全部行——cloud 现在至少包含本地的全集。
    await _pushAllLocal();

    // 2. 各表 diff 出 cloud-only id → 分批硬删。
    for (final entityName in _entityNames) {
      final remoteTable = _remoteTableName(entityName);
      final localIds = await _collectLocalIds(entityName);
      await _deleteCloudOnly(table: remoteTable, keepIds: localIds);
    }

    // 3. 重置游标和记录同步时间。
    await _writeLastPulledAtCursors({for (final e in _entityNames) e: 0});
    await _writeLastSyncedAt(_clock());
  }

  @override
  Future<void> forcePullAll() async {
    // 下载优先策略：先下载云端全部数据，成功后再清本地 + 写入。
    // 下载在事务外——失败时本地数据毫发无损。
    // 1. 下载云端全部数据到内存。
    final allCloudData = await _downloadAll();

    // 2. 在单个事务内：清空本地 → 写入云端数据。
    //    任何一步失败自动回滚，本地原有数据不丢失。
    await _db.transaction(() async {
      // 反向依赖顺序删除，避免 FK 约束警告。
      await _db.delete(_db.budgetTable).go();
      await _db.delete(_db.transactionEntryTable).go();
      await _db.delete(_db.accountTable).go();
      await _db.delete(_db.categoryTable).go();
      await _db.delete(_db.ledgerTable).go();

      // 写入全部云端数据——DB 已空，跳过 LWW 判定直接写入。
      for (final entityName in _entityNames) {
        for (final row in allCloudData[entityName]!) {
          await _applyRemoteRow(entityName, row);
        }
      }
    });

    // 3. 清理 sync_op 队列和游标。
    await _db.syncOpDao.clearAll();
    await _writeLastPulledAtCursors({for (final e in _entityNames) e: 0});
    await _writeLastSyncedAt(_clock());
  }
  /// 把本地全部活跃行重新入队 sync_op 并全量推送到云端。
  /// 先清空旧 sync_op 队列（force 操作不需要增量历史），再遍历 5 张表入队，
  /// 最后 drain 推送。
  Future<void> _pushAllLocal() async {
    final dao = _db.syncOpDao;
    await dao.clearAll();
    final nowMs = _clock().millisecondsSinceEpoch;

    final ledgers = await _db.select(_db.ledgerTable).get();
    for (final row in ledgers) {
      final entity = rowToLedger(row);
      await dao.enqueue(
        entity: 'ledger',
        entityId: entity.id,
        op: 'upsert',
        payload: jsonEncode(entity.toJson()),
        enqueuedAt: nowMs,
      );
    }

    final categories = await _db.select(_db.categoryTable).get();
    for (final row in categories) {
      final entity = rowToCategory(row);
      await dao.enqueue(
        entity: 'category',
        entityId: entity.id,
        op: 'upsert',
        payload: jsonEncode(entity.toJson()),
        enqueuedAt: nowMs,
      );
    }

    final accounts = await _db.select(_db.accountTable).get();
    for (final row in accounts) {
      final entity = rowToAccount(row);
      await dao.enqueue(
        entity: 'account',
        entityId: entity.id,
        op: 'upsert',
        payload: jsonEncode(entity.toJson()),
        enqueuedAt: nowMs,
      );
    }

    final transactions = await _db.select(_db.transactionEntryTable).get();
    for (final row in transactions) {
      final entity = rowToTransactionEntry(row);
      await dao.enqueue(
        entity: 'transaction',
        entityId: entity.id,
        op: 'upsert',
        payload: jsonEncode(entity.toJson()),
        enqueuedAt: nowMs,
      );
    }

    final budgets = await _db.select(_db.budgetTable).get();
    for (final row in budgets) {
      final entity = rowToBudget(row);
      await dao.enqueue(
        entity: 'budget',
        entityId: entity.id,
        op: 'upsert',
        payload: jsonEncode(entity.toJson()),
        enqueuedAt: nowMs,
      );
    }

    await _pushAll();
  }

  /// Collect all local IDs for an entity table.
  Future<Set<String>> _collectLocalIds(String entityName) async {
    switch (entityName) {
      case 'ledger':
        return (_db.select(_db.ledgerTable).map((r) => r.id).get())
            .then((rows) => rows.toSet());
      case 'category':
        return (_db.select(_db.categoryTable).map((r) => r.id).get())
            .then((rows) => rows.toSet());
      case 'account':
        return (_db.select(_db.accountTable).map((r) => r.id).get())
            .then((rows) => rows.toSet());
      case 'transaction':
        return (_db.select(_db.transactionEntryTable).map((r) => r.id).get())
            .then((rows) => rows.toSet());
      case 'budget':
        return (_db.select(_db.budgetTable).map((r) => r.id).get())
            .then((rows) => rows.toSet());
      default:
        throw StateError('Unknown entity: $entityName');
    }
  }

  /// 删除云端 [table] 中 id 不在 [keepIds] 中的全部行。
  ///
  /// 实现：分页拉云端 id 全集 → 内存 diff 出 cloud-only → 分批 [_hardDeleteByIds]。
  /// 不走 `not.in` 是为了规避 Cloudflare 8KB URL 限制（414 Request-URI Too Large）：
  /// 把全部 keep id 拼成 `id=not.in.(...)` 时 1000 个 UUID ≈ 40KB 必炸。
  Future<void> _deleteCloudOnly({
    required String table,
    required Set<String> keepIds,
  }) async {
    final cloudIds = <String>[];
    var offset = 0;
    while (true) {
      final rows = await _gateway.queryUpdatedSince(
        table: table,
        updatedAtGt: 0,
        limit: _kPagePullSize,
        offset: offset,
      );
      if (rows.isEmpty) break;
      cloudIds.addAll(rows.map((r) => r['id'] as String));
      if (rows.length < _kPagePullSize) break;
      offset += rows.length;
    }
    final toDelete =
        cloudIds.where((id) => !keepIds.contains(id)).toList(growable: false);
    await _hardDeleteByIds(table, toDelete);
  }

  /// 分批 [IncrementalCloudGateway.deleteBatch]。每批 [_kDeleteBatchSize] 个 id，
  /// 避免单次 URL 超过 Cloudflare 8KB 上限。
  Future<void> _hardDeleteByIds(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    for (var i = 0; i < ids.length; i += _kDeleteBatchSize) {
      final end =
          (i + _kDeleteBatchSize > ids.length) ? ids.length : i + _kDeleteBatchSize;
      final batch = ids.sublist(i, end);
      await _gateway.deleteBatch(table: table, ids: batch);
    }
  }

  /// 下载云端全部数据到内存（分页遍历），不做任何本地写入。
  /// 返回 `Map<entityName, List<cloudRow>>`。
  Future<Map<String, List<Map<String, dynamic>>>> _downloadAll() async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entityName in _entityNames) {
      final remoteTable = _remoteTableName(entityName);
      final allRows = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        final rows = await _gateway.queryUpdatedSince(
          table: remoteTable,
          updatedAtGt: 0,
          limit: _kPagePullSize,
          offset: offset,
        );
        if (rows.isEmpty) break;
        allRows.addAll(rows);
        if (rows.length < _kPagePullSize) break;
        offset += rows.length;
      }
      result[entityName] = allRows;
    }
    return result;
  }

  Future<void> pullThenPush() async {
    await _pullAll();
    await _pushAll();
    await _writeLastSyncedAt(_clock());
  }

  Future<void> pushOnly() async {
    await _pushAll();
  }

  Future<void> fullPull() async {
    await _writeLastPulledAtCursors({for (final e in _entityNames) e: 0});
    await _pullAll();
  }

  /// 探测云端是否存在任何行（含软删）。
  ///
  /// 用途：首次同步引导对话框需要根据"云端有/无数据"分支。任意一张 5 张表
  /// 看到至少 1 行即视为云端"有数据"——含 deleted_at != null 的软删行也算。
  /// 网络/权限错误由调用方捕获处理。
  Future<bool> hasAnyCloudData() async {
    for (final entityName in _entityNames) {
      final remoteTable = _remoteTableName(entityName);
      final rows = await _gateway.queryUpdatedSince(
        table: remoteTable,
        updatedAtGt: 0,
        limit: 1,
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _pushAll() async {
    final dao = _db.syncOpDao;
    Object? firstError;
    for (var round = 0; round < _kMaxDrainRounds; round++) {
      final raw = await dao.listPendingBatch(limit: 200);
      if (raw.isEmpty) break;

      final coalesced = dao.coalesceByEntity(raw);
      final byEntity = <String, List<SyncOpEntry>>{};
      for (final op in coalesced) {
        byEntity.putIfAbsent(op.entity, () => []).add(op);
      }

      var anyFailed = false;
      for (final entry in byEntity.entries) {
        final entityName = entry.key;
        final remoteTable = _remoteTableName(entityName);
        final ops = entry.value;

        try {
          // 按 op 分流：
          // - 'upsert' / 'delete'（软删，payload 含 deleted_at != null）→ upsertBatch；
          //   云端保留软删态，让其他设备 LWW 见到并同步标记。
          // - 'hardDelete'（彻底删除 / 30 天 GC）→ deleteBatch；云端真删。
          final upsertOps = ops
              .where((o) => o.op != 'hardDelete')
              .toList(growable: false);
          final hardDeleteOps = ops
              .where((o) => o.op == 'hardDelete')
              .toList(growable: false);

          if (upsertOps.isNotEmpty) {
            final cloudRows = upsertOps
                .map((op) => _entityJsonToCloudRow(
                      entityName,
                      jsonDecode(op.payload) as Map<String, dynamic>,
                    ))
                .toList(growable: false);
            await _gateway.upsertBatch(
              table: remoteTable,
              data: cloudRows,
            );
          }

          if (hardDeleteOps.isNotEmpty) {
            final ids =
                hardDeleteOps.map((o) => o.entityId).toList(growable: false);
            await _hardDeleteByIds(remoteTable, ids);
          }

          final entityRawIds = raw
              .where((r) => r.entity == entityName)
              .map((r) => r.id)
              .toList(growable: false);
          await dao.markPushed(entityRawIds);
        } catch (e) {
          firstError ??= e;
          for (final op in ops) {
            await dao.incrementTried(op.id, e.toString());
          }
          anyFailed = true;
        }
      }
      if (anyFailed) break;
    }
    if (firstError != null) {
      throw firstError;
    }
  }

  Map<String, dynamic> _entityJsonToCloudRow(
    String entity,
    Map<String, dynamic> json,
  ) {
    final out = <String, dynamic>{...json};
    final dateFields = _dateFieldsByEntity[entity] ?? const [];
    for (final f in dateFields) {
      final v = out[f];
      if (v is String) {
        out[f] = DateTime.parse(v).millisecondsSinceEpoch;
      }
    }
    // bool 字段（archived / is_favorite / include_in_total / carry_over）
    // 转成 int 0/1：Supabase 业务表（见 docs/supabase-setup.sql §5.x）实际列类型
    // 是 integer——PostgREST 不会自动 bool→int 归一化，发 JSON bool 会被拒绝
    // 报 22P02 "invalid input syntax for type integer: 'false'"。
    final boolFields = _boolFieldsByEntity[entity] ?? const [];
    for (final f in boolFields) {
      final v = out[f];
      if (v is bool) {
        out[f] = v ? 1 : 0;
      }
    }
    return out;
  }

  Future<void> _pullAll() async {
    final cursors = await _readLastPulledAtCursors();
    for (final entityName in _entityNames) {
      final remoteTable = _remoteTableName(entityName);
      final since = cursors[entityName] ?? 0;
      var offset = 0;
      var maxSeenThisRun = since;
      while (true) {
        final rows = await _gateway.queryUpdatedSince(
          table: remoteTable,
          updatedAtGt: since,
          limit: _kPagePullSize,
          offset: offset,
        );
        if (rows.isEmpty) break;
        await _mergeRows(entityName, rows);
        final batchMax = rows
            .map((r) => (r['updated_at'] as num).toInt())
            .reduce((a, b) => a > b ? a : b);
        if (batchMax > maxSeenThisRun) maxSeenThisRun = batchMax;
        if (rows.length < _kPagePullSize) break;
        offset += rows.length;
      }
      cursors[entityName] = maxSeenThisRun;
    }
    await _writeLastPulledAtCursors(cursors);
  }

  Future<void> _mergeRows(
    String entity,
    List<Map<String, dynamic>> remoteRows,
  ) async {
    await _db.transaction(() async {
      for (final remote in remoteRows) {
        final winner = await _lwwDecide(entity, remote);
        if (winner == MergeOutcome.useRemote) {
          await _applyRemoteRow(entity, remote);
        }
      }
    });
  }

  Future<MergeOutcome> _lwwDecide(
    String entity,
    Map<String, dynamic> remote,
  ) async {
    final id = remote['id'] as String;
    final localRow = await _selectLocalRowById(entity, id);
    if (localRow == null) return MergeOutcome.useRemote;

    final remoteUp = (remote['updated_at'] as num).toInt();
    final localUp = _localUpdatedAt(entity, localRow);
    return lwwDecide(
      remoteUpdatedAt: remoteUp,
      remoteDeviceId: remote['device_id'] as String,
      localUpdatedAt: localUp,
      localDeviceId: _localDeviceId(entity, localRow),
    );
  }

  Future<dynamic> _selectLocalRowById(String entity, String id) async {
    switch (entity) {
      case 'ledger':
        return (_db.select(_db.ledgerTable)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
      case 'category':
        return (_db.select(_db.categoryTable)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
      case 'account':
        return (_db.select(_db.accountTable)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
      case 'transaction':
        return (_db.select(_db.transactionEntryTable)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
      case 'budget':
        return (_db.select(_db.budgetTable)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
      default:
        throw StateError('Unknown entity: $entity');
    }
  }

  int _localUpdatedAt(String entity, dynamic row) {
    switch (entity) {
      case 'ledger':
        return (row as LedgerEntry).updatedAt;
      case 'category':
        return (row as CategoryEntry).updatedAt;
      case 'account':
        return (row as AccountEntry).updatedAt;
      case 'transaction':
        return (row as TransactionEntryRow).updatedAt;
      case 'budget':
        return (row as BudgetEntry).updatedAt;
      default:
        throw StateError('Unknown entity: $entity');
    }
  }

  String _localDeviceId(String entity, dynamic row) {
    switch (entity) {
      case 'ledger':
        return (row as LedgerEntry).deviceId;
      case 'category':
        return (row as CategoryEntry).deviceId;
      case 'account':
        return (row as AccountEntry).deviceId;
      case 'transaction':
        return (row as TransactionEntryRow).deviceId;
      case 'budget':
        return (row as BudgetEntry).deviceId;
      default:
        throw StateError('Unknown entity: $entity');
    }
  }

  Future<void> _applyRemoteRow(
    String entity,
    Map<String, dynamic> remote,
  ) async {
    final entityJson = _cloudRowToEntityJson(entity, remote);
    switch (entity) {
      case 'ledger':
        final e = Ledger.fromJson(entityJson);
        await _db.into(_db.ledgerTable).insert(
              ledgerToCompanion(e),
              mode: InsertMode.insertOrReplace,
            );
        break;
      case 'category':
        final e = Category.fromJson(entityJson);
        await _db.into(_db.categoryTable).insert(
              categoryToCompanion(e),
              mode: InsertMode.insertOrReplace,
            );
        break;
      case 'account':
        final e = Account.fromJson(entityJson);
        await _db.into(_db.accountTable).insert(
              accountToCompanion(e),
              mode: InsertMode.insertOrReplace,
            );
        break;
      case 'transaction':
        final e = TransactionEntry.fromJson(entityJson);
        await _db.into(_db.transactionEntryTable).insert(
              transactionEntryToCompanion(e),
              mode: InsertMode.insertOrReplace,
            );
        break;
      case 'budget':
        final e = Budget.fromJson(entityJson);
        await _db.into(_db.budgetTable).insert(
              budgetToCompanion(e),
              mode: InsertMode.insertOrReplace,
            );
        break;
      default:
        throw StateError('Unknown entity: $entity');
    }
  }

  Map<String, dynamic> _cloudRowToEntityJson(
    String entity,
    Map<String, dynamic> row,
  ) {
    final out = <String, dynamic>{...row}..remove('user_id');
    final dateFields = _dateFieldsByEntity[entity] ?? const [];
    for (final f in dateFields) {
      final v = out[f];
      if (v is num) {
        out[f] = DateTime.fromMillisecondsSinceEpoch(v.toInt())
            .toUtc()
            .toIso8601String();
      }
    }
    final boolFields = _boolFieldsByEntity[entity] ?? const [];
    for (final f in boolFields) {
      final v = out[f];
      if (v is num) {
        out[f] = v.toInt() != 0;
      }
    }
    return out;
  }

  Future<Map<String, int>> _readLastPulledAtCursors() async {
    final pref = await (_db.select(_db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    final raw = pref?.lastPulledAtJson;
    if (raw == null || raw.isEmpty) {
      return {for (final e in _entityNames) e: 0};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in _entityNames)
          e: (decoded[e] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {for (final e in _entityNames) e: 0};
    }
  }

  Future<void> _writeLastPulledAtCursors(Map<String, int> cursors) async {
    final encoded = jsonEncode(cursors);
    await (_db.update(_db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(lastPulledAtJson: Value(encoded)),
    );
  }

  Future<DateTime?> _readLastSyncedAt() async {
    final pref = await (_db.select(_db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    final ms = pref?.lastSyncAt;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _writeLastSyncedAt(DateTime t) async {
    await (_db.update(_db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(lastSyncAt: Value(t.millisecondsSinceEpoch)),
    );
  }

  Future<int> _countPendingSyncOps() async {
    return _db.syncOpDao.countPending();
  }

  String get deviceId => _deviceId;
}

enum MergeOutcome { useRemote, useLocal }

MergeOutcome lwwDecide({
  required int remoteUpdatedAt,
  required String remoteDeviceId,
  required int localUpdatedAt,
  required String localDeviceId,
}) {
  if (remoteUpdatedAt > localUpdatedAt) return MergeOutcome.useRemote;
  if (remoteUpdatedAt < localUpdatedAt) return MergeOutcome.useLocal;
  final cmp = remoteDeviceId.compareTo(localDeviceId);
  if (cmp > 0) return MergeOutcome.useRemote;
  return MergeOutcome.useLocal;
}
