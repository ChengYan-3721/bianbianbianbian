import 'package:drift/drift.dart';

import 'ledger_table.dart';

/// 对应 design-document §7.1 的 `transaction_entry` 表——流水（核心表）。
///
/// `type` 取值 `income` | `expense` | `transfer`；`amount` 始终为正数，方向由 `type`
/// 决定（便于统计聚合）。`fx_rate` 记录"该币种 → 账本默认币种"的换算率，便于
/// 未来统计页做跨币种汇总。`note_encrypted` / `attachments_encrypted` 在 Phase 11
/// 接入字段级加密后写入密文，目前先以明文 / JSON 写入（Step 3.5）。
///
/// DataClass 刻意命名 [TransactionEntryRow] 而非 `TransactionEntry`——后者预留给
/// Step 2.1 的领域实体。
///
/// 索引（§7.1）：
/// - `idx_tx_ledger_time (ledger_id, occurred_at DESC)`：首页流水按账本 + 时间倒序。
/// - `idx_tx_updated (updated_at)`：同步 pull 按 `updated_at > last_sync_at` 过滤。
///
/// 两个索引在 [AppDatabase.migration] 里用 `customStatement` 创建（drift 的
/// `@TableIndex` 注解不支持 `DESC` 方向，故走手写 SQL 保持与 §7.1 一致）。
@DataClassName('TransactionEntryRow')
class TransactionEntryTable extends Table {
  @override
  String get tableName => 'transaction_entry';

  TextColumn get id => text()();

  TextColumn get ledgerId =>
      text().named('ledger_id').references(LedgerTable, #id)();

  TextColumn get type => text()();

  RealColumn get amount => real()();

  TextColumn get currency => text()();

  RealColumn get fxRate =>
      real().named('fx_rate').nullable().withDefault(const Constant(1.0))();

  TextColumn get categoryId => text().nullable().named('category_id')();

  TextColumn get accountId => text().nullable().named('account_id')();

  TextColumn get toAccountId => text().nullable().named('to_account_id')();

  IntColumn get occurredAt => integer().named('occurred_at')();

  BlobColumn get noteEncrypted => blob().nullable().named('note_encrypted')();

  BlobColumn get attachmentsEncrypted =>
      blob().nullable().named('attachments_encrypted')();

  TextColumn get tags => text().nullable()();

  TextColumn get contentHash => text().nullable().named('content_hash')();

  IntColumn get updatedAt => integer().named('updated_at')();

  IntColumn get deletedAt => integer().nullable().named('deleted_at')();

  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}
