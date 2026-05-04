import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show DataSerializer;

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

/// 把 [LedgerSnapshot] 编解码为 String 并提供 SHA256 指纹。
///
/// 实现 `flutter_cloud_sync` 包的 [DataSerializer] 契约——传给
/// [CloudSyncManager]。
class LedgerSnapshotSerializer implements DataSerializer<LedgerSnapshot> {
  const LedgerSnapshotSerializer();

  @override
  Future<String> serialize(LedgerSnapshot data) async =>
      jsonEncode(data.toJson());

  @override
  Future<LedgerSnapshot> deserialize(String data) async =>
      LedgerSnapshot.fromJson(jsonDecode(data) as Map<String, dynamic>);

  /// 指纹**故意排除元数据字段** `exported_at` / `device_id`——它们每次 export
  /// 都会变化（exported_at = clock()，device_id 跟设备走），保留会导致：
  /// ① 上传后立即 getStatus 仍显示「本地较新」（因为 _exportLocal 又跑了一遍
  /// 时间戳已变）；② 多设备场景下永远不会判定为「已同步」。指纹只关心实际
  /// 业务数据是否一致——entity 内部的 `updated_at` / `device_id` 仍参与（那
  /// 些反映记录本身的变更）。
  @override
  String fingerprint(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
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
