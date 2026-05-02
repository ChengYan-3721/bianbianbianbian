import '../../domain/entity/account.dart';
import '../../domain/entity/budget.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/ledger.dart';
import '../../domain/entity/transaction_entry.dart';
import '../local/app_database.dart';

/// drift 行对象 ↔ 领域实体的映射函数集。
///
/// **这里是 `lib/data/` 与 `lib/domain/` 之间**唯一**允许的桥接点**——仓库
/// 实现（`local_*_repository.dart`）借此层完成两侧转换；领域层永远不进口
/// drift 类型（见 Step 2.1 的 `domain` 依赖隔离测试）。
///
/// 转换规则：
/// - `int epoch ms` ↔ `DateTime`（toLocal/utc 不做——仓库层不解释时区，纯透传）。
/// - `int? 0/1` ↔ `bool`（drift 的 `archived` / `include_in_total` / `carry_over`）。
/// - nullable 带默认值的列在 drift 侧允许为 null；映射到实体时统一应用默认
///   （`'CNY'` / `1.0` / `0` / `true` / `false`），避免默认值在 round-trip 丢失。
/// - 不做 tag / content_hash 计算——Phase 10 同步接入后由 sync engine 负责。

// ---------------- Ledger ----------------

Ledger rowToLedger(LedgerEntry row) {
  return Ledger(
    id: row.id,
    name: row.name,
    coverEmoji: row.coverEmoji,
    defaultCurrency: row.defaultCurrency ?? 'CNY',
    archived: (row.archived ?? 0) != 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    deletedAt: row.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!),
    deviceId: row.deviceId,
  );
}

LedgerTableCompanion ledgerToCompanion(Ledger entity) {
  return LedgerTableCompanion(
    id: Value(entity.id),
    name: Value(entity.name),
    coverEmoji: Value(entity.coverEmoji),
    defaultCurrency: Value(entity.defaultCurrency),
    archived: Value(entity.archived ? 1 : 0),
    createdAt: Value(entity.createdAt.millisecondsSinceEpoch),
    updatedAt: Value(entity.updatedAt.millisecondsSinceEpoch),
    deletedAt: Value(entity.deletedAt?.millisecondsSinceEpoch),
    deviceId: Value(entity.deviceId),
  );
}

// ---------------- Category ----------------

Category rowToCategory(CategoryEntry row) {
  return Category(
    id: row.id,
    name: row.name,
    icon: row.icon,
    color: row.color,
    parentKey: row.parentKey,
    sortOrder: row.sortOrder,
    isFavorite: row.isFavorite != 0,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    deletedAt: row.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!),
    deviceId: row.deviceId,
  );
}

CategoryTableCompanion categoryToCompanion(Category entity) {
  return CategoryTableCompanion(
    id: Value(entity.id),
    name: Value(entity.name),
    icon: Value(entity.icon),
    color: Value(entity.color),
    parentKey: Value(entity.parentKey),
    sortOrder: Value(entity.sortOrder),
    isFavorite: Value(entity.isFavorite ? 1 : 0),
    updatedAt: Value(entity.updatedAt.millisecondsSinceEpoch),
    deletedAt: Value(entity.deletedAt?.millisecondsSinceEpoch),
    deviceId: Value(entity.deviceId),
  );
}

// ---------------- Account ----------------

Account rowToAccount(AccountEntry row) {
  return Account(
    id: row.id,
    name: row.name,
    type: row.type,
    icon: row.icon,
    color: row.color,
    initialBalance: row.initialBalance ?? 0.0,
    includeInTotal: (row.includeInTotal ?? 1) != 0,
    currency: row.currency ?? 'CNY',
    billingDay: row.billingDay,
    repaymentDay: row.repaymentDay,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    deletedAt: row.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!),
    deviceId: row.deviceId,
  );
}

AccountTableCompanion accountToCompanion(Account entity) {
  return AccountTableCompanion(
    id: Value(entity.id),
    name: Value(entity.name),
    type: Value(entity.type),
    icon: Value(entity.icon),
    color: Value(entity.color),
    initialBalance: Value(entity.initialBalance),
    includeInTotal: Value(entity.includeInTotal ? 1 : 0),
    currency: Value(entity.currency),
    billingDay: Value(entity.billingDay),
    repaymentDay: Value(entity.repaymentDay),
    updatedAt: Value(entity.updatedAt.millisecondsSinceEpoch),
    deletedAt: Value(entity.deletedAt?.millisecondsSinceEpoch),
    deviceId: Value(entity.deviceId),
  );
}

// ---------------- TransactionEntry ----------------

TransactionEntry rowToTransactionEntry(TransactionEntryRow row) {
  return TransactionEntry(
    id: row.id,
    ledgerId: row.ledgerId,
    type: row.type,
    amount: row.amount,
    currency: row.currency,
    fxRate: row.fxRate ?? 1.0,
    categoryId: row.categoryId,
    accountId: row.accountId,
    toAccountId: row.toAccountId,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(row.occurredAt),
    noteEncrypted: row.noteEncrypted,
    attachmentsEncrypted: row.attachmentsEncrypted,
    tags: row.tags,
    contentHash: row.contentHash,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    deletedAt: row.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!),
    deviceId: row.deviceId,
  );
}

TransactionEntryTableCompanion transactionEntryToCompanion(
  TransactionEntry entity,
) {
  return TransactionEntryTableCompanion(
    id: Value(entity.id),
    ledgerId: Value(entity.ledgerId),
    type: Value(entity.type),
    amount: Value(entity.amount),
    currency: Value(entity.currency),
    fxRate: Value(entity.fxRate),
    categoryId: Value(entity.categoryId),
    accountId: Value(entity.accountId),
    toAccountId: Value(entity.toAccountId),
    occurredAt: Value(entity.occurredAt.millisecondsSinceEpoch),
    noteEncrypted: Value(entity.noteEncrypted),
    attachmentsEncrypted: Value(entity.attachmentsEncrypted),
    tags: Value(entity.tags),
    contentHash: Value(entity.contentHash),
    updatedAt: Value(entity.updatedAt.millisecondsSinceEpoch),
    deletedAt: Value(entity.deletedAt?.millisecondsSinceEpoch),
    deviceId: Value(entity.deviceId),
  );
}

// ---------------- Budget ----------------

Budget rowToBudget(BudgetEntry row) {
  return Budget(
    id: row.id,
    ledgerId: row.ledgerId,
    period: row.period,
    categoryId: row.categoryId,
    amount: row.amount,
    carryOver: (row.carryOver ?? 0) != 0,
    carryBalance: row.carryBalance,
    lastSettledAt: row.lastSettledAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.lastSettledAt!),
    startDate: DateTime.fromMillisecondsSinceEpoch(row.startDate),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    deletedAt: row.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!),
    deviceId: row.deviceId,
  );
}

BudgetTableCompanion budgetToCompanion(Budget entity) {
  return BudgetTableCompanion(
    id: Value(entity.id),
    ledgerId: Value(entity.ledgerId),
    period: Value(entity.period),
    categoryId: Value(entity.categoryId),
    amount: Value(entity.amount),
    carryOver: Value(entity.carryOver ? 1 : 0),
    carryBalance: Value(entity.carryBalance),
    lastSettledAt: Value(entity.lastSettledAt?.millisecondsSinceEpoch),
    startDate: Value(entity.startDate.millisecondsSinceEpoch),
    updatedAt: Value(entity.updatedAt.millisecondsSinceEpoch),
    deletedAt: Value(entity.deletedAt?.millisecondsSinceEpoch),
    deviceId: Value(entity.deviceId),
  );
}
