/// 预算唯一性冲突——同一账本、同一周期、同一分类（含 `categoryId == null` 总
/// 预算）下只能存在一个未软删的预算（Step 6.1 验收）。
///
/// 仓库层抛出此异常，UI 层根据 [period] / [isTotal] 字段构造本地化提示。
class BudgetConflictException implements Exception {
  const BudgetConflictException({required this.period, required this.isTotal});

  /// 'monthly' or 'yearly' - the caller localizes this via
  /// `context.l10n.periodMonthly` / `context.l10n.periodYearly`.
  final String period;

  /// `true` = total budget conflict, `false` = category budget conflict.
  /// The caller uses `context.l10n.budgetConflictTotal(period)` or
  /// `context.l10n.budgetConflictCategory(period)`.
  final bool isTotal;

  @override
  String toString() => 'BudgetConflictException(period: $period, isTotal: $isTotal)';
}

/// 账本名称重复——同一个名字在未软删的账本中只能出现一次。
///
/// Why: 删除账本后即使云端有备份也找不回来（V1 同步是按 ledgerId 寻址的，
/// 普通用户也只能感知名字），允许重名会让用户在切换/恢复时分不清是谁。
/// 已软删的账本不视为冲突——名字可以被新账本立即复用。
///
/// 仓库层抛出此异常，UI 层根据 [name] 构造本地化提示。
class LedgerNameConflictException implements Exception {
  const LedgerNameConflictException(this.name);

  /// The conflicting ledger name - the caller localizes the message
  /// via `context.l10n.ledgerNameConflictMsg(name)`.
  final String name;

  @override
  String toString() => 'LedgerNameConflictException: $name';
}
