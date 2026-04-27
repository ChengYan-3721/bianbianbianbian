/// 账本领域实体——`ledger` 表的纯 Dart 镜像（设计文档 §7.1）。
///
/// **不依赖 drift**——这是 `lib/domain/` 层的硬性约定。`Ledger` 与
/// `data/local/tables/ledger_table.dart` 生成的 `LedgerEntry` 字段对应
/// 1:1，但语义类型有三处收紧（Step 2.1 刻意决定，非机械镜像）：
/// - `archived`：drift 层是 `int?`（SQLite 默认 0）；实体层固定 `bool`
///   非空，默认 `false`。
/// - `defaultCurrency`：drift 层 `String?`（默认 `'CNY'`）；实体层固定
///   `String` 非空，默认 `'CNY'`。
/// - `createdAt` / `updatedAt` / `deletedAt`：drift 层是 `int`（epoch ms），
///   实体层是 `DateTime`。`deletedAt` 仍可空——null 即"未软删"。
///
/// 仓库层（Step 2.2）在 drift 行 ↔ 实体之间做类型转换。
///
/// ## copyWith 语义
/// 所有参数均为可选可空：**传 null 表示保持原值不变**，**无法通过 copyWith
/// 把一个已有值清成 null**（例如把 `deletedAt` 从 `DateTime` 清成 null
/// 以"反软删"）。Step 12.2（垃圾桶恢复）届时可加专用方法 `restore()`
/// 或直接构造新实体。
///
/// ## JSON 格式
/// 键名走 snake_case（与设计文档 §7.1 DDL + Supabase 列名一致）：
/// `id / name / cover_emoji / default_currency / archived / created_at /
/// updated_at / deleted_at / device_id`。时间戳统一用 ISO 8601 字符串，
/// 便于 Phase 10 Supabase 同步直接透传。
class Ledger {
  const Ledger({
    required this.id,
    required this.name,
    this.coverEmoji,
    this.defaultCurrency = 'CNY',
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });

  final String id;
  final String name;
  final String? coverEmoji;
  final String defaultCurrency;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;

  Ledger copyWith({
    String? id,
    String? name,
    String? coverEmoji,
    String? defaultCurrency,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deviceId,
  }) {
    return Ledger(
      id: id ?? this.id,
      name: name ?? this.name,
      coverEmoji: coverEmoji ?? this.coverEmoji,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cover_emoji': coverEmoji,
        'default_currency': defaultCurrency,
        'archived': archived,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'device_id': deviceId,
      };

  factory Ledger.fromJson(Map<String, dynamic> json) => Ledger(
        id: json['id'] as String,
        name: json['name'] as String,
        coverEmoji: json['cover_emoji'] as String?,
        defaultCurrency: (json['default_currency'] as String?) ?? 'CNY',
        archived: (json['archived'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at'] as String),
        deviceId: json['device_id'] as String,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ledger &&
        other.id == id &&
        other.name == name &&
        other.coverEmoji == coverEmoji &&
        other.defaultCurrency == defaultCurrency &&
        other.archived == archived &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        coverEmoji,
        defaultCurrency,
        archived,
        createdAt,
        updatedAt,
        deletedAt,
        deviceId,
      );

  @override
  String toString() => 'Ledger(id: $id, name: $name, '
      'coverEmoji: $coverEmoji, defaultCurrency: $defaultCurrency, '
      'archived: $archived, createdAt: $createdAt, updatedAt: $updatedAt, '
      'deletedAt: $deletedAt, deviceId: $deviceId)';
}
