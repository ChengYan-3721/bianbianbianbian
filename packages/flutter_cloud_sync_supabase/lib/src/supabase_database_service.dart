library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SupabaseDatabaseService implements CloudDatabaseService {
  final supabase.SupabaseClient _client;

  SupabaseDatabaseService(this._client);

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> data,
    bool autoInjectUserId = true,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      final insertData = Map<String, dynamic>.from(data);
      if (autoInjectUserId && !insertData.containsKey('user_id')) {
        insertData['user_id'] = user.id;
      }

      final response = await _client
          .from(table)
          .insert(insertData)
          .select()
          .single();

      return response as Map<String, dynamic>;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Insert failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Insert failed: $e', e);
    }
  }

  Future<List<Map<String, dynamic>>> insertBatch({
    required String table,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      final response = await _client
          .from(table)
          .insert(data)
          .select();

      return (response as List).cast<Map<String, dynamic>>();
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch insert failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch insert failed: $e', e);
    }
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required String id,
    required Map<String, dynamic> data,
    bool autoFilterByUser = true,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      var query = _client
          .from(table)
          .update(data)
          .eq('id', id);

      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      final response = await query.select().single();

      return response as Map<String, dynamic>;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Update failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Update failed: $e', e);
    }
  }

  @override
  Future<void> delete({
    required String table,
    required String id,
    bool autoFilterByUser = true,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      var query = _client
          .from(table)
          .delete()
          .eq('id', id);

      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      await query;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Delete failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Delete failed: $e', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query({
    required String table,
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
    int? offset,
    bool autoFilterByUser = true,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      dynamic query = _client.from(table).select();

      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }

      if (orderBy != null) {
        query = query.order(orderBy, ascending: !descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 1000) - 1);
      }

      final response = await query;

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Query failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Query failed: $e', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getById({
    required String table,
    required String id,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      final response = await _client
          .from(table)
          .select()
          .eq('id', id)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Get by ID failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Get by ID failed: $e', e);
    }
  }

  @override
  Stream<DatabaseEvent> subscribe({
    required String table,
    List<QueryFilter>? filters,
    String event = '*',
  }) {
    throw UnimplementedError(
      'Use SupabaseRealtimeService for realtime subscriptions',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> batchInsert({
    required String table,
    required List<Map<String, dynamic>> data,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      final response = await _client
          .from(table)
          .insert(data)
          .select();

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch insert failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch insert failed: $e', e);
    }
  }

  @override
  Future<void> batchUpdate({
    required String table,
    required List<Map<String, dynamic>> data,
    String idField = 'id',
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      for (final record in data) {
        final id = record[idField];
        if (id == null) {
          throw CloudStorageException('Record missing $idField field');
        }

        await _client
            .from(table)
            .update(record)
            .eq(idField, id);
      }
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch update failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch update failed: $e', e);
    }
  }

  @override
  Future<void> batchDelete({
    required String table,
    required List<QueryFilter> filters,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      var query = _client.from(table).delete();

      for (final filter in filters) {
        query = _applyFilter(query, filter);
      }

      await query;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch delete failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch delete failed: $e', e);
    }
  }

  Future<void> deleteAllUserData({required String table}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      await _client.from(table).delete().eq('user_id', user.id);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Delete all from $table failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Delete all from $table failed: $e', e);
    }
  }

  /// 稳定分页查询。在 [query] 基础上额外接受 [secondaryOrderBy]，让分页结果
  /// 在主排序列出现并列值时仍然全局有序——典型场景：增量同步按
  /// `(updated_at ASC, id ASC)` 排序，配合 offset 翻页。
  ///
  /// 单 `orderBy` 翻页在「同 updated_at 行数 > limit」时会卡死(下一页用
  /// `updated_at > cursor` 过滤,但 cursor 等于这一批的 updated_at,所以
  /// 后续同时间戳行被永久跳过)。CSV 批量导入是典型触发场景：4000+ 行共用
  /// 同一个 `_clock()` 毫秒。
  Future<List<Map<String, dynamic>>> queryStablePaginated({
    required String table,
    List<QueryFilter>? filters,
    required String primaryOrderBy,
    String secondaryOrderBy = 'id',
    bool descending = false,
    required int offset,
    required int limit,
    bool autoFilterByUser = true,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      dynamic query = _client.from(table).select();

      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }
      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }
      query = query.order(primaryOrderBy, ascending: !descending);
      query = query.order(secondaryOrderBy, ascending: !descending);
      query = query.range(offset, offset + limit - 1);

      final response = await query;
      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Stable query failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Stable query failed: $e', e);
    }
  }

  Future<List<Map<String, dynamic>>> upsertBatch({
    required String table,
    required List<Map<String, dynamic>> data,
    String onConflict = 'id',
    bool autoInjectUserId = true,
  }) async {
    if (data.isEmpty) return const [];
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      final List<Map<String, dynamic>> payload;
      if (autoInjectUserId) {
        payload = data.map((row) {
          if (row.containsKey('user_id') && row['user_id'] != null) {
            return row;
          }
          return {...row, 'user_id': user.id};
        }).toList(growable: false);
      } else {
        payload = data;
      }

      final response = await _client
          .from(table)
          .upsert(payload, onConflict: onConflict)
          .select();

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Upsert batch failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Upsert batch failed: $e', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String query) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      final response = await _client.rpc('execute_raw_query', params: {
        'query_text': query,
      });

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Raw query failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Raw query failed: $e', e);
    }
  }

  dynamic _applyFilter(dynamic query, QueryFilter filter) {
    switch (filter.operator) {
      case 'eq':
        return query.eq(filter.column, filter.value);
      case 'neq':
        return query.neq(filter.column, filter.value);
      case 'gt':
        return query.gt(filter.column, filter.value);
      case 'gte':
        return query.gte(filter.column, filter.value);
      case 'lt':
        return query.lt(filter.column, filter.value);
      case 'lte':
        return query.lte(filter.column, filter.value);
      case 'like':
        return query.like(filter.column, filter.value);
      case 'ilike':
        return query.ilike(filter.column, filter.value);
      case 'in':
        return query.inFilter(filter.column, filter.value as List);
      case 'not.in':
        return query.not(filter.column, 'in', '(${(filter.value as List).map((v) => "'${v.toString().replaceAll("'", "''")}'").join(',')})');
      case 'is':
        return query.isFilter(filter.column, filter.value);
      case 'contains':
        return query.contains(filter.column, filter.value);
      case 'containedBy':
        return query.containedBy(filter.column, filter.value);
      case 'overlaps':
        return query.overlaps(filter.column, filter.value as List);
      default:
        throw CloudStorageException('Unsupported filter operator: ${filter.operator}');
    }
  }
}
