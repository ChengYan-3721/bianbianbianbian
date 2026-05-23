import 'package:drift/drift.dart';

import '../app_database.dart';

part 'sync_op_dao.g.dart';

class SyncOpDao extends DatabaseAccessor<AppDatabase> with _$SyncOpDaoMixin {
  SyncOpDao(super.db);

  Future<int> enqueue({
    required String entity,
    required String entityId,
    required String op,
    required String payload,
    required int enqueuedAt,
  }) {
    return into(syncOpTable).insert(
      SyncOpTableCompanion.insert(
        entity: entity,
        entityId: entityId,
        op: op,
        payload: payload,
        enqueuedAt: enqueuedAt,
      ),
    );
  }

  Future<void> batchEnqueue(List<SyncOpTableCompanion> companions) async {
    if (companions.isEmpty) return;
    await batch((b) {
      for (final c in companions) {
        b.insert(syncOpTable, c, mode: InsertMode.insert);
      }
    });
  }

  Future<void> clearAll() async {
    await delete(syncOpTable).go();
  }

  Future<List<SyncOpEntry>> listAll() {
    return (select(syncOpTable)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<List<SyncOpEntry>> listPendingBatch({
    int limit = 200,
    int maxTried = 5,
  }) {
    return (select(syncOpTable)
          ..where((t) => t.tried.isNull() | t.tried.isSmallerThanValue(maxTried))
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(limit))
        .get();
  }

  Future<void> markPushed(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(syncOpTable)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> incrementTried(int id, String? error) async {
    await customStatement(
      'UPDATE sync_op SET tried = COALESCE(tried, 0) + 1, last_error = ? '
      'WHERE id = ?',
      [error, id],
    );
  }

  Future<int> countPending({int maxTried = 5}) {
    return (select(syncOpTable)
          ..where((t) => t.tried.isNull() | t.tried.isSmallerThanValue(maxTried)))
        .get()
        .then((rows) => rows.length);
  }

  List<SyncOpEntry> coalesceByEntity(List<SyncOpEntry> raw) {
    if (raw.isEmpty) return const [];
    final byKey = <String, SyncOpEntry>{};
    for (final op in raw) {
      final key = '${op.entity}:${op.entityId}';
      final existing = byKey[key];
      if (existing == null || op.id > existing.id) {
        byKey[key] = op;
      }
    }
    final result = byKey.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return result;
  }
}
