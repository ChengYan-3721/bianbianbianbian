/// 预算领域实体——`budget` 表的纯 Dart 镜像（设计文档 §7.1 + Step 6.4 扩展）。
///
/// **不依赖 drift**。与 `BudgetEntry` 1:1 但收紧：
/// - `period`：`String`（取值 `monthly` | `yearly`）。
/// - `carryOver`：drift 层 `int?`（默认 0）；实体层固定 `bool` 非空，默认
///   `false`。Phase 6 Step 6.4 真正使用。
/// - `categoryId`：可空——**null 表示"总预算"**（该账本该周期的总盘子，
///   而非任一分类）。
/// - `startDate`, `updatedAt`, `deletedAt`, `lastSettledAt`：drift 层是
///   `int` epoch ms，实体层是 `DateTime` / `DateTime?`。
/// - `carryBalance`：Step 6.4 引入。已结转累加余额，仅当 `carryOver = true`
///   时叠加到"本期可用"。默认 0。
/// - `lastSettledAt`：Step 6.4 引入。已结算到的周期 end 时间戳；`null` 表示
///   还未触发过结算。
///
/// 详见 [Ledger] 关于 copyWith 语义与 JSON 键的说明（本实体同规则）。
class Budget {
  const Budget({
    required this.id,
    required this.ledgerId,
    required this.period,
    this.categoryId,
    required this.amount,
    this.carryOver = false,
    this.carryBalance = 0,
    this.lastSettledAt,
    required this.startDate,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });

  final String id;
  final String ledgerId;
  final String period; // monthly | yearly
  final String? categoryId; // null = 总预算
  final double amount;
  final bool carryOver;
  final double carryBalance;
  final DateTime? lastSettledAt;
  final DateTime startDate;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;

  Budget copyWith({
    String? id,
    String? ledgerId,
    String? period,
    String? categoryId,
    double? amount,
    bool? carryOver,
    double? carryBalance,
    DateTime? lastSettledAt,
    DateTime? startDate,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deviceId,
  }) {
    return Budget(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      period: period ?? this.period,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      carryOver: carryOver ?? this.carryOver,
      carryBalance: carryBalance ?? this.carryBalance,
      lastSettledAt: lastSettledAt ?? this.lastSettledAt,
      startDate: startDate ?? this.startDate,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledger_id': ledgerId,
        'period': period,
        'category_id': categoryId,
        'amount': amount,
        'carry_over': carryOver,
        'carry_balance': carryBalance,
        'last_settled_at': lastSettledAt?.toIso8601String(),
        'start_date': startDate.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'device_id': deviceId,
      };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        ledgerId: json['ledger_id'] as String,
        period: json['period'] as String,
        categoryId: json['category_id'] as String?,
        amount: (json['amount'] as num).toDouble(),
        carryOver: (json['carry_over'] as bool?) ?? false,
        carryBalance: (json['carry_balance'] as num?)?.toDouble() ?? 0,
        lastSettledAt: json['last_settled_at'] == null
            ? null
            : DateTime.parse(json['last_settled_at'] as String),
        startDate: DateTime.parse(json['start_date'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at'] as String),
        deviceId: json['device_id'] as String,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Budget &&
        other.id == id &&
        other.ledgerId == ledgerId &&
        other.period == period &&
        other.categoryId == categoryId &&
        other.amount == amount &&
        other.carryOver == carryOver &&
        other.carryBalance == carryBalance &&
        other.lastSettledAt == lastSettledAt &&
        other.startDate == startDate &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        ledgerId,
        period,
        categoryId,
        amount,
        carryOver,
        carryBalance,
        lastSettledAt,
        startDate,
        updatedAt,
        deletedAt,
        deviceId,
      );

  @override
  String toString() => 'Budget(id: $id, ledgerId: $ledgerId, period: $period, '
      'categoryId: $categoryId, amount: $amount, carryOver: $carryOver, '
      'carryBalance: $carryBalance, lastSettledAt: $lastSettledAt, '
      'startDate: $startDate, updatedAt: $updatedAt, '
      'deletedAt: $deletedAt, deviceId: $deviceId)';
}
