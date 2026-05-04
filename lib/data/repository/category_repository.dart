import 'dart:convert';

import '../../domain/entity/category.dart';
import '../local/app_database.dart';
import '../local/dao/category_dao.dart';
import '../local/dao/sync_op_dao.dart';
import 'entity_mappers.dart';
import 'repo_clock.dart';

/// 分类仓库（重构版）：全局二级分类，不再按账本隔离。
abstract class CategoryRepository {
  Future<List<Category>> listActiveByParentKey(String parentKey);
  Future<List<Category>> listFavorites();
  Future<List<Category>> listActiveAll();
  Future<Category> save(Category entity);
  Future<void> toggleFavorite(String id, bool isFavorite);
  Future<void> softDeleteById(String id);

  /// **垃圾桶专用**（Phase 12 Step 12.1）。
  Future<List<Category>> listDeleted();
  Future<void> restoreById(String id);
  Future<int> purgeById(String id);
  Future<int> purgeAllDeleted();
  Future<List<Category>> listExpired(DateTime cutoff);
}

class LocalCategoryRepository implements CategoryRepository {
  LocalCategoryRepository({
    required AppDatabase db,
    required String deviceId,
    RepoClock clock = DateTime.now,
  })  : _db = db,
        _dao = db.categoryDao,
        _syncOp = db.syncOpDao,
        _deviceId = deviceId,
        _clock = clock;

  final AppDatabase _db;
  final CategoryDao _dao;
  final SyncOpDao _syncOp;
  final String _deviceId;
  final RepoClock _clock;

  @override
  Future<List<Category>> listActiveByParentKey(String parentKey) async {
    final rows = await _dao.listActiveByParentKey(parentKey);
    return rows.map(rowToCategory).toList(growable: false);
  }

  @override
  Future<List<Category>> listFavorites() async {
    final rows = await _dao.listFavorites();
    return rows.map(rowToCategory).toList(growable: false);
  }

  @override
  Future<List<Category>> listActiveAll() async {
    final rows = await _dao.listActiveAll();
    return rows.map(rowToCategory).toList(growable: false);
  }

  @override
  Future<Category> save(Category entity) async {
    final now = _clock();
    final stamped = entity.copyWith(updatedAt: now, deviceId: _deviceId);
    await _db.transaction(() async {
      await _dao.upsert(categoryToCompanion(stamped));
      await _syncOp.enqueue(
        entity: 'category',
        entityId: stamped.id,
        op: 'upsert',
        payload: jsonEncode(stamped.toJson()),
        enqueuedAt: now.millisecondsSinceEpoch,
      );
    });
    return stamped;
  }

  @override
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final now = _clock();
    await _db.transaction(() async {
      final row = await (_db.select(_db.categoryTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      final updated = rowToCategory(row).copyWith(
        isFavorite: isFavorite,
        updatedAt: now,
        deviceId: _deviceId,
      );
      await _dao.updateFavoriteById(
        id,
        isFavorite: isFavorite,
        updatedAt: now.millisecondsSinceEpoch,
      );
      await _syncOp.enqueue(
        entity: 'category',
        entityId: id,
        op: 'upsert',
        payload: jsonEncode(updated.toJson()),
        enqueuedAt: now.millisecondsSinceEpoch,
      );
    });
  }

  @override
  Future<void> softDeleteById(String id) async {
    final now = _clock();
    await _db.transaction(() async {
      final row = await (_db.select(_db.categoryTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      final updated = rowToCategory(row).copyWith(
        updatedAt: now,
        deletedAt: now,
        deviceId: _deviceId,
      );
      await (_db.update(_db.categoryTable)..where((t) => t.id.equals(id)))
          .write(
        CategoryTableCompanion(
          updatedAt: Value(now.millisecondsSinceEpoch),
          deletedAt: Value(now.millisecondsSinceEpoch),
          deviceId: Value(_deviceId),
        ),
      );
      await _syncOp.enqueue(
        entity: 'category',
        entityId: id,
        op: 'delete',
        payload: jsonEncode(updated.toJson()),
        enqueuedAt: now.millisecondsSinceEpoch,
      );
    });
  }

  @override
  Future<List<Category>> listDeleted() async {
    final rows = await _dao.listDeleted();
    return rows.map(rowToCategory).toList(growable: false);
  }

  @override
  Future<void> restoreById(String id) async {
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;
    await _dao.restoreById(id, updatedAt: nowMs);
  }

  @override
  Future<int> purgeById(String id) {
    return _dao.hardDeleteById(id);
  }

  @override
  Future<int> purgeAllDeleted() {
    return (_db.delete(_db.categoryTable)
          ..where((t) => t.deletedAt.isNotNull()))
        .go();
  }

  @override
  Future<List<Category>> listExpired(DateTime cutoff) async {
    final rows = await _dao.listExpired(cutoff.millisecondsSinceEpoch);
    return rows.map(rowToCategory).toList(growable: false);
  }
}
