import 'package:drift/drift.dart';

/// 分类二级项表（重构版）。
///
/// - 一级分类固定常量，不落库；
/// - 本表仅存"二级分类"；
/// - 全局共享（无 ledger_id）；
/// - `parent_key` 指向一级分类 key；
/// - `is_favorite` 表示是否收藏（全局共享）。
@DataClassName('CategoryEntry')
class CategoryTable extends Table {
  @override
  String get tableName => 'category';

  TextColumn get id => text()();

  /// 二级分类名称。
  TextColumn get name => text()();

  /// 图标（emoji 或资源 key）。
  TextColumn get icon => text().nullable()();

  /// 颜色（hex）。
  TextColumn get color => text().nullable()();

  /// 一级分类 key：
  /// income | food | shopping | transport | education | entertainment |
  /// social | housing | medical | investment | other
  TextColumn get parentKey => text().named('parent_key')();

  /// 同一级分类内排序值。
  IntColumn get sortOrder => integer().named('sort_order').withDefault(
        const Constant(0),
      )();

  /// 收藏（0/1）。
  IntColumn get isFavorite =>
      integer().named('is_favorite').withDefault(const Constant(0))();

  IntColumn get updatedAt => integer().named('updated_at')();

  IntColumn get deletedAt => integer().nullable().named('deleted_at')();

  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => const [];

  @override
  List<String> get customConstraints => const [
        "CHECK(parent_key IN ('income','food','shopping','transport','education','entertainment','social','housing','medical','investment','other'))",
      ];
}
