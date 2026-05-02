import 'package:drift/drift.dart';

/// 对应 design-document §7.1 的 `account` 表——资产账户（钱包/银行卡/信用卡等）。
///
/// `type` 取值 `cash` | `debit` | `credit` | `third_party` | `other`。
/// `include_in_total = 1` 表示计入总资产面板（信用卡欠款通常计入为负)。
/// 账户不绑定账本，是全局资源——多个账本可共用同一张"招行卡"。
///
/// Step 7.3：信用卡专属的 `billing_day` / `repayment_day` 仅展示用，取值
/// 1-28（约束在 UI 层校验）。两列对所有账户都是 nullable——非信用卡填 null，
/// 信用卡新建时也允许暂时不填。
@DataClassName('AccountEntry')
class AccountTable extends Table {
  @override
  String get tableName => 'account';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get icon => text().nullable()();

  TextColumn get color => text().nullable()();

  RealColumn get initialBalance => real()
      .named('initial_balance')
      .nullable()
      .withDefault(const Constant(0))();

  IntColumn get includeInTotal => integer()
      .named('include_in_total')
      .nullable()
      .withDefault(const Constant(1))();

  TextColumn get currency =>
      text().nullable().withDefault(const Constant('CNY'))();

  /// 账单日（信用卡专属，1-28），nullable。Step 7.3。
  IntColumn get billingDay =>
      integer().named('billing_day').nullable()();

  /// 还款日（信用卡专属，1-28），nullable。Step 7.3。
  IntColumn get repaymentDay =>
      integer().named('repayment_day').nullable()();

  IntColumn get updatedAt => integer().named('updated_at')();

  IntColumn get deletedAt => integer().nullable().named('deleted_at')();

  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}
