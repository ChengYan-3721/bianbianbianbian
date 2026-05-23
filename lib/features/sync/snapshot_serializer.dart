import 'dart:convert';
import 'dart:io' show GZipCodec;
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show DataSerializer;
import 'package:uuid/uuid.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/account_repository.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/category_repository.dart';
import '../../data/repository/entity_mappers.dart';
import '../../data/repository/ledger_repository.dart';
import '../../data/repository/transaction_repository.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/budget.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/ledger.dart';
import '../../domain/entity/transaction_entry.dart';

/// 整个账本的可序列化快照（V1）。
///
/// 范围：
/// - 账本本体（[Ledger]）
/// - 该账本下所有未软删流水（[TransactionEntry]）
/// - 该账本下所有未软删预算（[Budget]）
/// - 全局共享的所有未软删分类（[Category]）
/// - 全局共享的所有未软删账户（[Account]）
///
/// **不包含**：`fx_rate`（每端独立维护）、`user_pref`、`sync_op`、已软删条目。
@immutable
class LedgerSnapshot {
  static const int kVersion = 1;

  final int version;
  final DateTime exportedAt;
  final String deviceId;
  final Ledger ledger;
  final List<Category> categories;
  final List<Account> accounts;
  final List<TransactionEntry> transactions;
  final List<Budget> budgets;

  const LedgerSnapshot({
    required this.version,
    required this.exportedAt,
    required this.deviceId,
    required this.ledger,
    required this.categories,
    required this.accounts,
    required this.transactions,
    required this.budgets,
  });

  String get ledgerId => ledger.id;

  Map<String, dynamic> toJson() => {
        'version': version,
        'exported_at': exportedAt.toIso8601String(),
        'device_id': deviceId,
        'ledger': ledger.toJson(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'budgets': budgets.map((b) => b.toJson()).toList(),
      };

  factory LedgerSnapshot.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version > kVersion) {
      throw FormatException('Unsupported snapshot version: $version');
    }
    return LedgerSnapshot(
      version: version,
      exportedAt: DateTime.parse(json['exported_at'] as String),
      deviceId: json['device_id'] as String,
      ledger: Ledger.fromJson(json['ledger'] as Map<String, dynamic>),
      categories: (json['categories'] as List<dynamic>)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      accounts: (json['accounts'] as List<dynamic>)
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      transactions: (json['transactions'] as List<dynamic>)
          .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      budgets: (json['budgets'] as List<dynamic>)
          .map((e) => Budget.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
/// 多账本备份快照——JSON 输出的顶层信封。
///
/// 之所以再包一层而不直接导出 `List<LedgerSnapshot>`：① 给版本号留位置；
/// ② 导入时可由顶层 version 决定走哪条解析路径；③ device_id +
/// exported_at 让用户能从备份文件本身判断来源。
///
/// **不持久化任何数据库**——仅用于导出/导入/同步的内存表达。
@immutable
class MultiLedgerSnapshot {
  static const int kVersion = 1;

  const MultiLedgerSnapshot({
    required this.version,
    required this.exportedAt,
    required this.deviceId,
    required this.ledgers,
  });

  final int version;
  final DateTime exportedAt;
  final String deviceId;
  final List<LedgerSnapshot> ledgers;

  Map<String, dynamic> toJson() => {
        'version': version,
        'exported_at': exportedAt.toIso8601String(),
        'device_id': deviceId,
        'ledgers': ledgers.map((l) => l.toJson()).toList(),
      };

  factory MultiLedgerSnapshot.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version > kVersion) {
      throw FormatException('Unsupported backup version: $version');
    }
    return MultiLedgerSnapshot(
      version: version,
      exportedAt: DateTime.parse(json['exported_at'] as String),
      deviceId: json['device_id'] as String,
      ledgers: (json['ledgers'] as List<dynamic>)
          .map((e) => LedgerSnapshot.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
class LedgerSnapshotSerializer implements DataSerializer<LedgerSnapshot> {
  const LedgerSnapshotSerializer();

  /// 新格式 magic prefix。**改动需同时审计所有持久化路径**(云端备份文件、
  /// 本地 cache 等),不可贸然 rename。
  static const String _gzipPrefix = 'gz:';

  /// gzip 压缩级别 9(max)。snapshot 是写多读少 + 网络传输,多耗点 CPU 换体
  /// 积值得。实测 5 万行 JSON 压缩耗时 < 100ms,可接受。
  static const int _gzipLevel = 9;

  String _encodeGzipBase64(String json) {
    final bytes = utf8.encode(json);
    final compressed = GZipCodec(level: _gzipLevel).encode(bytes);
    return '$_gzipPrefix${base64Encode(compressed)}';
  }

  String _decodeIfGzipped(String data) {
    if (!data.startsWith(_gzipPrefix)) return data;
    final compressed = base64Decode(data.substring(_gzipPrefix.length));
    return utf8.decode(GZipCodec().decode(compressed));
  }

  @override
  Future<String> serialize(LedgerSnapshot data) async =>
      _encodeGzipBase64(jsonEncode(data.toJson()));

  @override
  Future<LedgerSnapshot> deserialize(String data) async =>
      LedgerSnapshot.fromJson(
        jsonDecode(_decodeIfGzipped(data)) as Map<String, dynamic>,
      );

  /// 指纹**故意排除元数据字段** `exported_at` / `device_id`——它们每次 export
  /// 都会变化（exported_at = clock()，device_id 跟设备走），保留会导致：
  /// ① 上传后立即 getStatus 仍显示「本地较新」（因为 _exportLocal 又跑了一遍
  /// 时间戳已变）；② 多设备场景下永远不会判定为「已同步」。指纹只关心实际
  /// 业务数据是否一致——entity 内部的 `updated_at` / `device_id` 仍参与（那
  /// 些反映记录本身的变更）。
  ///
  /// 跨压缩格式稳定:[_decodeIfGzipped] 先 unwrap,再走原本 stable map 算法,
  /// 因此 gzip 数据与对应 JSON 数据 fingerprint 必然相同。
  @override
  String fingerprint(String data) {
    final raw = _decodeIfGzipped(data);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final stable = <String, dynamic>{
      'version': json['version'],
      'ledger': json['ledger'],
      'categories': json['categories'],
      'accounts': json['accounts'],
      'transactions': json['transactions'],
      'budgets': json['budgets'],
    };
    return sha256.convert(utf8.encode(jsonEncode(stable))).toString();
  }
}

/// 把 [MultiLedgerSnapshot] 编解码为 String 并提供 SHA256 指纹。
///
/// 与 [LedgerSnapshotSerializer] 共享同一套 gzip+base64 压缩管线。
/// 指纹排除 `exported_at` / `device_id` 元数据字段，仅对业务数据做 hash。
class MultiLedgerSnapshotSerializer
    implements DataSerializer<MultiLedgerSnapshot> {
  const MultiLedgerSnapshotSerializer();

  static const String _gzipPrefix = 'gz:';
  static const int _gzipLevel = 9;

  String _encodeGzipBase64(String json) {
    final bytes = utf8.encode(json);
    final compressed = GZipCodec(level: _gzipLevel).encode(bytes);
    return '$_gzipPrefix${base64Encode(compressed)}';
  }

  String _decodeIfGzipped(String data) {
    if (!data.startsWith(_gzipPrefix)) return data;
    final compressed = base64Decode(data.substring(_gzipPrefix.length));
    return utf8.decode(GZipCodec().decode(compressed));
  }

  @override
  Future<String> serialize(MultiLedgerSnapshot data) async =>
      _encodeGzipBase64(jsonEncode(data.toJson()));

  @override
  Future<MultiLedgerSnapshot> deserialize(String data) async =>
      MultiLedgerSnapshot.fromJson(
        jsonDecode(_decodeIfGzipped(data)) as Map<String, dynamic>,
      );

  @override
  String fingerprint(String data) {
    final raw = _decodeIfGzipped(data);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final stable = <String, dynamic>{
      'version': json['version'],
      'ledgers': json['ledgers'],
    };
    return sha256.convert(utf8.encode(jsonEncode(stable))).toString();
  }
}
/// 从本地数据库导出所有活跃账本的快照，打包为 [MultiLedgerSnapshot]。
///
/// 不读取任何 sync_op / user_pref / fx_rate；不写入 sync_op；纯读路径。
Future<MultiLedgerSnapshot> exportMultiLedgerSnapshot({
  required String deviceId,
  required LedgerRepository ledgerRepo,
  required CategoryRepository categoryRepo,
  required AccountRepository accountRepo,
  required TransactionRepository transactionRepo,
  required BudgetRepository budgetRepo,
  DateTime Function() clock = DateTime.now,
}) async {
  final activeLedgers = await ledgerRepo.listActive();
  final categories = await categoryRepo.listActiveAll();
  final accounts = await accountRepo.listActive();

  final snapshots = <LedgerSnapshot>[];
  for (final ledger in activeLedgers) {
    final transactions = await transactionRepo.listActiveByLedger(ledger.id);
    final budgets = await budgetRepo.listActiveByLedger(ledger.id);
    snapshots.add(LedgerSnapshot(
      version: LedgerSnapshot.kVersion,
      exportedAt: clock(),
      deviceId: deviceId,
      ledger: ledger,
      categories: categories,
      accounts: accounts,
      transactions: transactions,
      budgets: budgets,
    ));
  }

  return MultiLedgerSnapshot(
    version: MultiLedgerSnapshot.kVersion,
    exportedAt: clock(),
    deviceId: deviceId,
    ledgers: snapshots,
  );
}

/// 把 [MultiLedgerSnapshot] 中的所有账本应用到本地数据库（覆盖式恢复）。
///
/// 对每个 ledger snapshot 依次调用 [importLedgerSnapshot]，全部在同一事务内完成。
/// 返回总共写入的流水条数。
///
/// [clearAllFirst] 为 true 时，在导入前先物理删除本地所有账本、流水、预算、
/// 分类和账户数据（不含 user_pref 和 fx_rate），使本地与快照完全一致。
/// 清库与导入在同一 SQLite 事务内，任何一步失败自动回滚，本地原有数据不丢失。
Future<int> importMultiLedgerSnapshot({
  required MultiLedgerSnapshot snapshot,
  required AppDatabase db,
  bool clearAllFirst = false,
}) async {
  return db.transaction(() async {
    if (clearAllFirst) {
      // 先删子表再删主表，避免外键约束警告。
      await db.delete(db.transactionEntryTable).go();
      await db.delete(db.budgetTable).go();
      await db.delete(db.ledgerTable).go();
      await db.delete(db.categoryTable).go();
      await db.delete(db.accountTable).go();
    }
    var total = 0;
    for (final ledgerSnap in snapshot.ledgers) {
      total += await importLedgerSnapshot(snapshot: ledgerSnap, db: db);
    }
    return total;
  });
}
/// 从本地数据库导出指定账本的活跃快照。
///
/// 不读取任何 sync_op / user_pref / fx_rate；不写入 sync_op；纯读路径。
Future<LedgerSnapshot> exportLedgerSnapshot({
  required String ledgerId,
  required String deviceId,
  required LedgerRepository ledgerRepo,
  required CategoryRepository categoryRepo,
  required AccountRepository accountRepo,
  required TransactionRepository transactionRepo,
  required BudgetRepository budgetRepo,
  DateTime Function() clock = DateTime.now,
}) async {
  final ledger = await ledgerRepo.getById(ledgerId);
  if (ledger == null) {
    throw StateError('Ledger not found: $ledgerId');
  }

  final categories = await categoryRepo.listActiveAll();
  final accounts = await accountRepo.listActive();
  final transactions = await transactionRepo.listActiveByLedger(ledgerId);
  final budgets = await budgetRepo.listActiveByLedger(ledgerId);

  return LedgerSnapshot(
    version: LedgerSnapshot.kVersion,
    exportedAt: clock(),
    deviceId: deviceId,
    ledger: ledger,
    categories: categories,
    accounts: accounts,
    transactions: transactions,
    budgets: budgets,
  );
}

/// 把快照应用到本地数据库（覆盖式恢复）。
///
/// 步骤（事务内）：
/// 1. 物理删除该账本下所有 transactions / budgets（含已软删）；
/// 2. upsert ledger 本体；
/// 3. upsert 全部 categories（按 id；不删既有，避免破坏其他账本依赖）；
/// 4. upsert 全部 accounts（同上）；
/// 5. insertOrReplace 所有 snapshot 中的 transactions / budgets。
///
/// 故意**不**走 repository 层 [save]——避免 import 触发 sync_op 队列累积，
/// 形成"刚下载的数据立刻又被排队上传"的循环。直接走 batch DAO/db。
///
/// 返回写入的流水条数。
Future<int> importLedgerSnapshot({
  required LedgerSnapshot snapshot,
  required AppDatabase db,
}) async {
  return db.transaction(() async {
    final ledgerId = snapshot.ledger.id;

    // 1. 清空当前账本现有的流水与预算（含软删）
    await (db.delete(db.transactionEntryTable)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .go();
    await (db.delete(db.budgetTable)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .go();

    // 2-5. 批量 upsert
    await db.batch((batch) {
      batch.insert(
        db.ledgerTable,
        ledgerToCompanion(snapshot.ledger),
        mode: InsertMode.insertOrReplace,
      );
      for (final c in snapshot.categories) {
        batch.insert(
          db.categoryTable,
          categoryToCompanion(c),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final a in snapshot.accounts) {
        batch.insert(
          db.accountTable,
          accountToCompanion(a),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final tx in snapshot.transactions) {
        batch.insert(
          db.transactionEntryTable,
          transactionEntryToCompanion(tx),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final b in snapshot.budgets) {
        batch.insert(
          db.budgetTable,
          budgetToCompanion(b),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    return snapshot.transactions.length;
  });
}

/// 同名账本冲突时的处理策略。
///
/// - [merge]:保留本地账本,把云端快照的流水/预算追加到本地同名账本中
///   (tx/budget 分配新 UUID,ledgerId 重映射到本地账本 id)。
/// - [overwrite]:用云端快照**替换**本地同名账本的全部流水与预算
///   (先清空再写入,保留本地账本 id 和元数据)。
/// - [rename]:以新名称创建独立账本(新 UUID),本地同名账本保持不动。
enum LedgerNameConflictStrategy {
  /// 合并到本地同名账本——流水/预算追加,不删本地已有数据。
  merge,

  /// 覆盖本地同名账本——先清空流水/预算,再写入云端数据。
  overwrite,

  /// 重命名为新账本——生成新 UUID + 新名称,本地同名账本不动。
  rename,
}

/// 同名账本冲突检测结果。
///
/// 由 [checkLedgerNameConflict] 返回,供 UI 层在恢复前展示冲突对话框。
@immutable
class LedgerNameConflict {
  final String cloudLedgerName;
  final String localLedgerId;
  final String localLedgerName;

  const LedgerNameConflict({
    required this.cloudLedgerName,
    required this.localLedgerId,
    required this.localLedgerName,
  });
}

/// 检查云端备份的账本名是否与本地已有活跃账本重名。
///
/// 返回 null 表示无冲突;非 null 表示存在同名活跃账本,UI 应展示冲突解决对话框。
Future<LedgerNameConflict?> checkLedgerNameConflict({
  required String cloudLedgerName,
  required AppDatabase db,
}) async {
  final rows = await (db.select(db.ledgerTable)
        ..where((t) => t.name.equals(cloudLedgerName))
        ..where((t) => t.deletedAt.isNull()))
      .get();
  if (rows.isEmpty) return null;
  final local = rows.first;
  return LedgerNameConflict(
    cloudLedgerName: cloudLedgerName,
    localLedgerId: local.id,
    localLedgerName: local.name,
  );
}

/// "追加为新账本"导入路径——把云端 snapshot 注入本地 DB,不与已有任何 ledger
/// 冲突。
///
/// 与 [importLedgerSnapshot] 的对比:
/// - 后者按 `snapshot.ledger.id` upsert,适合"重新覆盖同一本账本"(老 V1 路径);
/// - 本函数为 `BackupListPage` 的"恢复"按钮服务——新装的设备本地 ledgerId
///   不可能与云端老备份匹配,这时强行 upsert 反而会覆盖本地新数据。把云端备份
///   当成"全新账本插入"是更安全的语义。
///
/// 重映射规则:
/// - ledger.id:**优先保留原始 id**——仅当本地已存在同名活跃账本时才生成新 UUID。
///   保留原始 id 的意义:非鉴权后端(S3/WebDAV/iCloud)用 ledgerId 构建云端路径,
///   多设备恢复同一备份后 ledgerId 相同 → 自然共享同一份云端备份,实现真正的
///   多设备自动同步。
/// - 每条 transaction:id = uuidFactory(),ledgerId = 最终 ledger.id;
/// - 每条 budget:同上;
/// - categories / accounts:**保持原 id**——它们是全局共享资源,upsert 后
///   不同 ledger 自然复用,新建 UUID 反而会复制出冗余分类/账户。
///
/// 附件 remoteKey 保持快照里的原值(指向老 deviceId 目录);Phase 11 的
/// lazy download 走绝对路径,对 S3/WebDAV/iCloud 没有访问障碍。
///
/// [conflictStrategy] 控制同名账本冲突时的行为:
/// - [LedgerNameConflictStrategy.merge]:合并到本地同名账本;
/// - [LedgerNameConflictStrategy.overwrite]:覆盖本地同名账本;
/// - [LedgerNameConflictStrategy.rename]:以 [renameTo] 新建账本(必须提供新名称);
/// - null(默认):自动生成新 UUID 保留原名(旧行为,可能导致重名)。
///
/// `uuidFactory` 默认走 [Uuid.v4],测试时注入计数器即可断言确定结果。
///
/// 返回最终使用的 ledger.id。
Future<String> importLedgerSnapshotAsNew({
  required LedgerSnapshot snapshot,
  required AppDatabase db,
  String Function()? uuidFactory,
  LedgerNameConflictStrategy? conflictStrategy,
  String? renameTo,
}) async {
  final uuid = uuidFactory ?? _defaultUuid;

  // 先在事务外算好新 id 映射——避免 batch 期间多次调用 uuid() 产生交错。
  // ledgerId:优先保留原始 id,仅当本地已存在同名活跃账本时才生成新 UUID。
  // 保留原始 id 让多设备恢复同一备份后 ledgerId 相同,自然共享同一云端路径。
  final originalLedgerId = snapshot.ledger.id;
  final txIdMap = {
    for (final t in snapshot.transactions) t.id: uuid(),
  };
  final budgetIdMap = {
    for (final b in snapshot.budgets) b.id: uuid(),
  };

  return db.transaction(() async {
    // 查询本地已有的分类和账户，按 (name, parentKey) / (name, type) 去重。
    // 不同设备 seeder 生成的 UUID 不同，但同名同父级分类 / 同名同类型账户
    // 应视为同一资源——直接按 UUID insertOrReplace 会导致重复行。
    final existingCatRows = await (db.select(db.categoryTable)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final existingCatKeys = <(String, String), String>{};
    for (final r in existingCatRows) {
      existingCatKeys[(r.name, r.parentKey)] = r.id;
    }

    final existingAcctRows = await (db.select(db.accountTable)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final existingAcctKeys = <(String, String), String>{};
    for (final r in existingAcctRows) {
      existingAcctKeys[(r.name, r.type)] = r.id;
    }

    // 检查原始 ledgerId 是否与本地已有活跃账本冲突。
    // 冲突条件:本地已存在同名活跃账本(非软删)且 id 不同。
    // 不冲突(本地无此 id 或同名账本已软删) → 保留原始 id,多设备共享同一云端路径。
    final existingLedger = await (db.select(db.ledgerTable)
          ..where((t) => t.id.equals(originalLedgerId)))
        .getSingleOrNull();
    final hasConflict = existingLedger != null &&
        existingLedger.deletedAt == null &&
        existingLedger.name == snapshot.ledger.name;

    // 同时检查按名称的冲突(不同 id 但同名)——这是 S3 云同步恢复的常见场景。
    final nameConflictRows = await (db.select(db.ledgerTable)
          ..where((t) => t.name.equals(snapshot.ledger.name))
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final nameConflict = nameConflictRows
        .where((r) => r.id != originalLedgerId)
        .toList();
    final hasNameConflict = nameConflict.isNotEmpty;

    final String finalLedgerId;
    final String finalLedgerName;

    if (hasNameConflict && conflictStrategy != null) {
      // 有同名冲突且用户已选择策略
      final localLedger = nameConflict.first;
      switch (conflictStrategy) {
        case LedgerNameConflictStrategy.merge:
          // 合并:使用本地账本 id,流水/预算追加到本地账本
          finalLedgerId = localLedger.id;
          finalLedgerName = localLedger.name;
          break;
        case LedgerNameConflictStrategy.overwrite:
          // 覆盖:使用本地账本 id,但先清空其流水/预算再写入
          finalLedgerId = localLedger.id;
          finalLedgerName = localLedger.name;
          // 清空本地同名账本的流水与预算
          await (db.delete(db.transactionEntryTable)
                ..where((t) => t.ledgerId.equals(localLedger.id)))
              .go();
          await (db.delete(db.budgetTable)
                ..where((t) => t.ledgerId.equals(localLedger.id)))
              .go();
          break;
        case LedgerNameConflictStrategy.rename:
          // 重命名:新 UUID + 新名称
          finalLedgerId = uuid();
          finalLedgerName = renameTo ?? '${snapshot.ledger.name}(恢复)';
          break;
      }
    } else if (hasConflict) {
      // 旧行为:ID 冲突 → 生成新 UUID,保留原名
      finalLedgerId = uuid();
      finalLedgerName = snapshot.ledger.name;
    } else {
      // 无冲突 → 保留原始 id 和名称
      finalLedgerId = originalLedgerId;
      finalLedgerName = snapshot.ledger.name;
    }

    final remappedLedger = snapshot.ledger.copyWith(
      id: finalLedgerId,
      name: finalLedgerName,
    );
    await db.into(db.ledgerTable).insert(
          ledgerToCompanion(remappedLedger),
          mode: InsertMode.insertOrReplace,
        );

    await db.batch((batch) {
      for (final c in snapshot.categories) {
        final key = (c.name, c.parentKey);
        if (existingCatKeys.containsKey(key)) continue; // 本地已有同名同父级分类，跳过
        batch.insert(
          db.categoryTable,
          categoryToCompanion(c),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final a in snapshot.accounts) {
        final key = (a.name, a.type);
        if (existingAcctKeys.containsKey(key)) continue; // 本地已有同名同类型账户，跳过
        batch.insert(
          db.accountTable,
          accountToCompanion(a),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final tx in snapshot.transactions) {
        final remapped = tx.copyWith(
          id: txIdMap[tx.id],
          ledgerId: finalLedgerId,
        );
        batch.insert(
          db.transactionEntryTable,
          transactionEntryToCompanion(remapped),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final b in snapshot.budgets) {
        final remapped = b.copyWith(
          id: budgetIdMap[b.id],
          ledgerId: finalLedgerId,
        );
        batch.insert(
          db.budgetTable,
          budgetToCompanion(remapped),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    return finalLedgerId;
  });
}

String _defaultUuid() => const Uuid().v4();
