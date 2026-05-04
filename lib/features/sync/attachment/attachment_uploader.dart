import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:path/path.dart' as p;

import '../../../domain/entity/attachment_meta.dart';

/// 附件上传管线（Step 11.2）。
///
/// 输入一组 [AttachmentMeta]，把所有 `remoteKey == null` 的项读字节、计算
/// SHA256、上传到云端，回填 `remoteKey` / `sha256`；其余项原样透传。
///
/// 路径约定与 `lib/features/sync/sync_service.dart::_path()` 对齐：
/// `users/<uid>/attachments/<txId>/<sha256><ext>`。
///
/// **故意是顶层服务而不是 Riverpod provider**——上传流程完全无状态，依赖
/// 项作为构造参数注入即可；且需要在 [SnapshotSyncService.upload] 内部直接
/// 实例化使用，不走 ref.read（避免循环依赖）。
class AttachmentUploader {
  AttachmentUploader({
    required CloudStorageService storage,
    Future<Uint8List> Function(String path) readBytes = _defaultReadBytes,
  })  : _storage = storage,
        _readBytes = readBytes;

  final CloudStorageService _storage;
  final Future<Uint8List> Function(String path) _readBytes;

  /// 上传所有 `remoteKey == null` 的元数据，返回更新后的列表。
  ///
  /// **幂等保证**：上传前先查 [CloudStorageService.exists]，命中则跳过。
  /// 同 sha256（同内容）→ 同 path → 走同一对象。
  ///
  /// **错误隔离**：单条失败（网络中断 / 配额超限 / 文件丢失）→ 跳过该条
  /// + 把失败的 meta 留 `remoteKey = null`（下次同步重试），其他项继续上传。
  /// 整体不抛异常——调用方据返回值判断成功率。
  Future<List<AttachmentMeta>> uploadPending(
    List<AttachmentMeta> metas, {
    required String txId,
    required String uid,
  }) async {
    final out = <AttachmentMeta>[];
    for (final meta in metas) {
      if (meta.remoteKey != null) {
        out.add(meta);
        continue;
      }
      final localPath = meta.localPath;
      if (localPath == null) {
        // 既无 remoteKey 又无 localPath = 数据丢失，跳过保留原样。
        out.add(meta);
        continue;
      }

      try {
        final bytes = await _readBytes(localPath);
        final hash = sha256.convert(bytes).toString();
        final ext = p.extension(meta.originalName.isEmpty
            ? localPath
            : meta.originalName);
        final remotePath =
            'users/$uid/attachments/$txId/$hash$ext';

        // 幂等：远端已存在视为成功，仅回填 meta 不再重传。
        final exists = await _storage.exists(path: remotePath);
        if (!exists) {
          await _storage.uploadBinary(
            path: remotePath,
            bytes: bytes,
            contentType: meta.mime,
          );
        }

        out.add(meta.copyWith(
          remoteKey: () => remotePath,
          sha256: () => hash,
          size: bytes.length,
        ));
      } catch (e, st) {
        // 单文件失败不阻塞队列；让下次同步重试。
        debugPrint('AttachmentUploader: failed for $localPath — $e\n$st');
        out.add(meta);
      }
    }
    return List.unmodifiable(out);
  }
}

Future<Uint8List> _defaultReadBytes(String path) async {
  return File(path).readAsBytes();
}
