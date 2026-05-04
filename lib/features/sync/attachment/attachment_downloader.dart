import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:path/path.dart' as p;

import '../../../data/local/app_database.dart';
import '../../../data/local/attachment_meta_codec.dart';
import '../../../domain/entity/attachment_meta.dart';

/// 附件懒下载与本地缓存（Step 11.3）。
///
/// `ensureLocal(meta, txId)` 三种返回路径：
/// 1. `meta.localPath != null` 且文件存在 → 直接返回 [File]，不调 storage；
/// 2. `meta.remoteKey != null` → 走 [CloudStorageService.downloadBinary] →
///    写到 `<cacheRoot>/<txId>/<sha256><ext>` → 通过 [writeback] 把新的
///    `local_path` 写回 DB → 返回 [File]；
/// 3. 网络异常 / 远端 404 / 双 null → 返回 null（不抛异常，UI 显示占位）。
///
/// **并发控制**：用一个内置 [_ConcurrencyLimiter]（默认 3 路）排队 storage
/// 调用，避免冷启动滚动时把网卡打满。命中本地缓存的快路径**不**走限流。
///
/// **错误隔离**：所有抛出（网络 / 文件系统 / writeback）都被吞掉并记 log，
/// `ensureLocal` 永远走"成功 File / 失败 null"的两态契约——UI 不需要 try/catch。
class AttachmentDownloader {
  AttachmentDownloader({
    required CloudStorageService storage,
    required Directory cacheRoot,
    AttachmentDownloadWriteback? writeback,
    int maxConcurrent = 3,
  })  : _storage = storage,
        _cacheRoot = cacheRoot,
        _writeback = writeback,
        _limiter = _ConcurrencyLimiter(maxConcurrent);

  final CloudStorageService _storage;
  final Directory _cacheRoot;
  final AttachmentDownloadWriteback? _writeback;
  final _ConcurrencyLimiter _limiter;

  /// 已下载完成的 (txId, sha256) 集合 —— 同 hash 在同一进程生命周期内不重复
  /// 下载（即使 DB writeback 还没落地）。下次调用直接走缓存路径。
  final Map<String, _CacheEntry> _inMemoryIndex = {};

  /// 当前正在下载中的同 (txId, sha256) future —— 避免 list 滚动连续触发
  /// 同 meta 的多个并发请求重复打 storage。
  final Map<String, Future<File?>> _inflight = {};

  /// 解析返回 [File]，按 [AttachmentDownloader] 类文档的三态契约执行。
  Future<File?> ensureLocal(
    AttachmentMeta meta, {
    required String txId,
  }) async {
    // 1. 本地优先：localPath 已填且文件真的存在 → 直接返回。
    final lp = meta.localPath;
    if (lp != null) {
      final f = File(lp);
      if (await f.exists()) return f;
    }

    final hash = meta.sha256;
    final remoteKey = meta.remoteKey;

    // 2. 既无 remoteKey 也无可用 localPath → 数据彻底丢失。
    if (remoteKey == null || hash == null) return null;

    // 3. 缓存命中（之前同进程下载过）→ 直接返回。
    final cached = _inMemoryIndex['$txId|$hash'];
    if (cached != null) {
      final f = File(cached.path);
      if (await f.exists()) return f;
      // 文件被外部清掉（用户清缓存 / iOS 内存压力）→ 回落到下载路径。
      _inMemoryIndex.remove('$txId|$hash');
    }

    // 4. 同 (txId, sha256) 已在下载中 → 复用 future。
    final inflightKey = '$txId|$hash';
    final existing = _inflight[inflightKey];
    if (existing != null) return existing;

    final future = _doDownload(meta: meta, txId: txId, sha256: hash, remoteKey: remoteKey);
    _inflight[inflightKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(inflightKey);
    }
  }

  Future<File?> _doDownload({
    required AttachmentMeta meta,
    required String txId,
    required String sha256,
    required String remoteKey,
  }) async {
    return _limiter.run(() async {
      try {
        final bytes = await _storage.downloadBinary(path: remoteKey);
        if (bytes == null) return null;
        final ext = _resolveExtension(meta);
        final file = await _writeToCache(
          txId: txId,
          sha256: sha256,
          ext: ext,
          bytes: bytes,
        );
        _inMemoryIndex['$txId|$sha256'] =
            _CacheEntry(path: file.path);
        // DB 回写——失败不影响本次返回，下次再调时走 in-memory index 兜底。
        if (_writeback != null) {
          try {
            await _writeback(
              txId: txId,
              sha256: sha256,
              localPath: file.path,
            );
          } catch (e, st) {
            debugPrint(
              'AttachmentDownloader: writeback failed for $txId/$sha256 — $e\n$st',
            );
          }
        }
        return file;
      } catch (e, st) {
        debugPrint(
          'AttachmentDownloader: download failed for $remoteKey — $e\n$st',
        );
        return null;
      }
    });
  }

  Future<File> _writeToCache({
    required String txId,
    required String sha256,
    required String ext,
    required Uint8List bytes,
  }) async {
    final dir = Directory(p.join(_cacheRoot.path, txId));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$sha256$ext'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// 优先用 originalName 的扩展名（用户视角）；兜底用 mime → 已知扩展名
  /// （应付 originalName 缺扩展或全为 emoji 的边缘情况）。
  String _resolveExtension(AttachmentMeta meta) {
    final fromName = p.extension(meta.originalName);
    if (fromName.isNotEmpty) return fromName;
    // 已知 mime 兜底；否则空字符串（让缓存文件无扩展名，仍可读）。
    switch (meta.mime) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/heic':
        return '.heic';
      case 'image/webp':
        return '.webp';
      case 'application/pdf':
        return '.pdf';
      default:
        return '';
    }
  }
}

/// DB writeback 钩子：下载完成后回写 `attachments_encrypted` BLOB 内对应
/// meta 的 `local_path` 字段。
///
/// 单独抽 typedef 是为了让 [AttachmentDownloader] 不依赖 [AppDatabase]——
/// 测试直接传 mock，生产由 provider 注入 [defaultAttachmentLocalPathWriteback]。
typedef AttachmentDownloadWriteback = Future<void> Function({
  required String txId,
  required String sha256,
  required String localPath,
});

/// 生产路径 writeback：在 [AppDatabase] 中查找 `txId` 对应行，定位 `sha256`
/// 匹配的 meta，更新其 `localPath` 后整体重新编码写回。
///
/// 行不存在 / BLOB 空 / 没找到匹配 sha256 → 静默 noop（属于"竞态"——比如
/// download 进行中流水被软删了）。**不**改 `updated_at`，与上传管线
/// `_uploadPendingAttachments` 的语义一致：附件 metadata 微调不应触发同步状态
/// 变化。
Future<void> defaultAttachmentLocalPathWriteback(
  AppDatabase db, {
  required String txId,
  required String sha256,
  required String localPath,
}) async {
  final row = await (db.select(db.transactionEntryTable)
        ..where((t) => t.id.equals(txId)))
      .getSingleOrNull();
  if (row == null) return;
  final blob = row.attachmentsEncrypted;
  if (blob == null || blob.isEmpty) return;
  final metas = AttachmentMetaCodec.decode(blob);
  if (metas.isEmpty) return;

  var changed = false;
  final updated = <AttachmentMeta>[];
  for (final m in metas) {
    if (m.sha256 == sha256 && m.localPath != localPath) {
      updated.add(m.copyWith(localPath: () => localPath));
      changed = true;
    } else {
      updated.add(m);
    }
  }
  if (!changed) return;

  final encoded = AttachmentMetaCodec.encode(updated);
  await db.customStatement(
    'UPDATE transaction_entry SET attachments_encrypted = ? WHERE id = ?',
    [encoded, txId],
  );
}

/// 内部缓存索引项——只记 path（mtime / size 由文件系统自带，prune 时再读）。
class _CacheEntry {
  const _CacheEntry({required this.path});
  final String path;
}

/// 简单的并发限流器——maxConcurrent 个 task 同时跑，其余排队。
///
/// 故意不引入 `package:pool` 依赖：当前需求只是「不打满网卡」，简单 Completer
/// 队列足够。
class _ConcurrencyLimiter {
  _ConcurrencyLimiter(this.maxConcurrent);

  final int maxConcurrent;
  int _running = 0;
  final List<Completer<void>> _waitQueue = [];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_running >= maxConcurrent) {
      final c = Completer<void>();
      _waitQueue.add(c);
      await c.future;
    }
    _running++;
    try {
      return await task();
    } finally {
      _running--;
      if (_waitQueue.isNotEmpty) {
        _waitQueue.removeAt(0).complete();
      }
    }
  }
}
