/// 分类领域实体（全局二级分类）。
///
/// 一级分类固定常量，不落库；二级分类通过 [parentKey] 归属到一级分类。
/// 收藏状态由 [isFavorite] 表示，且全局共享（不区分账本）。
class Category {
  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.parentKey,
    this.sortOrder = 0,
    this.isFavorite = false,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });

  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String parentKey;
  final int sortOrder;
  final bool isFavorite;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    String? parentKey,
    int? sortOrder,
    bool? isFavorite,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deviceId,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      parentKey: parentKey ?? this.parentKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'parent_key': parentKey,
        'sort_order': sortOrder,
        'is_favorite': isFavorite,
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'device_id': deviceId,
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
        parentKey: json['parent_key'] as String,
        sortOrder: (json['sort_order'] as int?) ?? 0,
        isFavorite: (json['is_favorite'] as bool?) ?? false,
        updatedAt: DateTime.parse(json['updated_at'] as String),
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at'] as String),
        deviceId: json['device_id'] as String,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.color == color &&
        other.parentKey == parentKey &&
        other.sortOrder == sortOrder &&
        other.isFavorite == isFavorite &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        icon,
        color,
        parentKey,
        sortOrder,
        isFavorite,
        updatedAt,
        deletedAt,
        deviceId,
      );

  @override
  String toString() => 'Category(id: $id, name: $name, '
      'parentKey: $parentKey, sortOrder: $sortOrder, isFavorite: $isFavorite, '
      'icon: $icon, color: $color, updatedAt: $updatedAt, '
      'deletedAt: $deletedAt, deviceId: $deviceId)';
}
