/// 资产账户领域实体——`account` 表的纯 Dart 镜像（设计文档 §7.1）。
///
/// **不依赖 drift**。与 `AccountEntry` 1:1 但收紧：
/// - `type`：`String`（取值 `cash` | `debit` | `credit` | `third_party` |
///   `other`）。同 [Category] 暂不用 enum，保留后续 Phase 可能新增类型的灵活度。
/// - `initialBalance`：drift 层 `double?`（默认 0.0）；实体层固定非空默认
///   `0.0`。信用卡场景可为负。
/// - `includeInTotal`：drift 层 `int?`（默认 1）；实体层固定 `bool` 非空，
///   默认 `true`。
/// - `currency`：drift 层 `String?`（默认 `'CNY'`）；实体层非空默认 `'CNY'`。
///
/// 账户不绑定账本——是全局资源（[ledgerId] 字段不存在）。
///
/// Step 7.3：信用卡专属字段 `billingDay` / `repaymentDay` 仅展示用，
/// 取值约束 1-28（在 UI 层校验）。非信用卡账户两字段为 null；信用卡账户也允许
/// 暂时不填（保持 null）。
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.initialBalance = 0.0,
    this.includeInTotal = true,
    this.currency = 'CNY',
    this.billingDay,
    this.repaymentDay,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });

  final String id;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final double initialBalance;
  final bool includeInTotal;
  final String currency;
  final int? billingDay;
  final int? repaymentDay;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;

  Account copyWith({
    String? id,
    String? name,
    String? type,
    String? icon,
    String? color,
    double? initialBalance,
    bool? includeInTotal,
    String? currency,
    int? billingDay,
    int? repaymentDay,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deviceId,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      initialBalance: initialBalance ?? this.initialBalance,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      currency: currency ?? this.currency,
      billingDay: billingDay ?? this.billingDay,
      repaymentDay: repaymentDay ?? this.repaymentDay,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'initial_balance': initialBalance,
        'include_in_total': includeInTotal,
        'currency': currency,
        'billing_day': billingDay,
        'repayment_day': repaymentDay,
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'device_id': deviceId,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
        initialBalance:
            (json['initial_balance'] as num?)?.toDouble() ?? 0.0,
        includeInTotal: (json['include_in_total'] as bool?) ?? true,
        currency: (json['currency'] as String?) ?? 'CNY',
        billingDay: (json['billing_day'] as num?)?.toInt(),
        repaymentDay: (json['repayment_day'] as num?)?.toInt(),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at'] as String),
        deviceId: json['device_id'] as String,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.icon == icon &&
        other.color == color &&
        other.initialBalance == initialBalance &&
        other.includeInTotal == includeInTotal &&
        other.currency == currency &&
        other.billingDay == billingDay &&
        other.repaymentDay == repaymentDay &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        icon,
        color,
        initialBalance,
        includeInTotal,
        currency,
        billingDay,
        repaymentDay,
        updatedAt,
        deletedAt,
        deviceId,
      );

  @override
  String toString() => 'Account(id: $id, name: $name, type: $type, '
      'initialBalance: $initialBalance, includeInTotal: $includeInTotal, '
      'currency: $currency, icon: $icon, color: $color, '
      'billingDay: $billingDay, repaymentDay: $repaymentDay, '
      'updatedAt: $updatedAt, deletedAt: $deletedAt, deviceId: $deviceId)';
}
