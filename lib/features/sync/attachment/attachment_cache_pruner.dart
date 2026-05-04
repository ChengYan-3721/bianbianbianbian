import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// 附件缓存上限：500 MiB。超过即触发 LRU 淘汰。
///
/// V1 选择 500 MiB 平衡"覆盖几百张图"与"不显著占用 iOS 严格的 cache 空间"。
/// 设置项暂不暴露（plan 设计如此）；如需调整改这个常量即可，全局生效。
const int kAttachmentCacheLimitBytes = 500 * 1024 * 1024;

/// 至少保留多少天内访问过的文件（不被 prune 淘汰）。
///
/// 即便 cache 总量超过上限，最近 7 天用过的图也不会被清——保证短期内重新
/// 打开同一笔流水的体验是即时的。
const Duration kAttachmentCacheMinRetention = Duration(days: 7);

/// 附件缓存的体积统计 + LRU 淘汰服务（Step 11.3）。
///
/// 不在 schema 里追踪缓存大小——`Directory.list` 算总和的成本对 500 MiB
/// 上限（数百个文件级别）完全可接受。
///
/// **触发时机**：`main.dart` bootstrap 链 fire-and-forget 触发一次；用户在
/// 设置页"清除缓存"也走 [clear]。下载完一个新文件不主动 prune——容量是
/// 软上限，超 1～2 个文件无关大碍，等下次启动统一收。
class AttachmentCachePruner {
  AttachmentCachePruner({
    required Directory cacheRoot,
    int limitBytes = kAttachmentCacheLimitBytes,
    Duration minRetention = kAttachmentCacheMinRetention,
  })  : _root = cacheRoot,
        _limit = limitBytes,
        _minRetention = minRetention;

  final Directory _root;
  final int _limit;
  final Duration _minRetention;

  /// 当前缓存占用字节数。目录不存在返回 0。
  Future<int> currentSize() async {
    if (!await _root.exists()) return 0;
    var total = 0;
    await for (final ent in _root.list(recursive: true, followLinks: false)) {
      if (ent is File) {
        try {
          total += await ent.length();
        } catch (_) {
          // 文件被并发删除——跳过即可。
        }
      }
    }
    return total;
  }

  /// 淘汰过老文件，使总占用 ≤ [_limit]；返回被删除的字节数。
  ///
  /// 算法：
  /// 1. 列出所有缓存文件的 (path, size, mtime)；
  /// 2. 按 mtime 升序（最旧的在前）排序；
  /// 3. 从前往后删，但 `mtime > now - _minRetention` 的文件**永不删**——
  ///    哪怕总量仍超上限，也得停手。容量是软上限，最近 7 天的体验更重要。
  ///
  /// 返回的字节数是真实删除量；若所有候选都在保留期内，可能返回 0 + 总量
  /// 仍超限。这是合规行为，调用方不需要重试。
  Future<int> prune({DateTime? now}) async {
    if (!await _root.exists()) return 0;
    final clock = now ?? DateTime.now();
    final cutoff = clock.subtract(_minRetention);

    final entries = <_PruneCandidate>[];
    var total = 0;
    await for (final ent in _root.list(recursive: true, followLinks: false)) {
      if (ent is! File) continue;
      try {
        final stat = await ent.stat();
        entries.add(_PruneCandidate(
          file: ent,
          size: stat.size,
          mtime: stat.modified,
        ));
        total += stat.size;
      } catch (_) {
        continue;
      }
    }
    if (total <= _limit) return 0;

    entries.sort((a, b) => a.mtime.compareTo(b.mtime));

    var deleted = 0;
    for (final ent in entries) {
      if (total <= _limit) break;
      if (ent.mtime.isAfter(cutoff)) {
        // 后面的更新——直接收手，避免误删保留期内的文件。
        break;
      }
      try {
        await ent.file.delete();
        deleted += ent.size;
        total -= ent.size;
      } catch (e, st) {
        debugPrint(
          'AttachmentCachePruner: failed to delete ${ent.file.path} — $e\n$st',
        );
      }
    }

    // 顺手清空目录——cache 目录里只剩空 <txId>/ 子目录时也删掉。
    await _removeEmptyChildDirs();

    return deleted;
  }

  /// 一键清空整个缓存。设置页"清除缓存"调用。返回删除的字节数。
  Future<int> clear() async {
    if (!await _root.exists()) return 0;
    final size = await currentSize();
    try {
      await _root.delete(recursive: true);
    } catch (e, st) {
      debugPrint('AttachmentCachePruner.clear failed — $e\n$st');
      return 0;
    }
    return size;
  }

  /// Step 11.4：流水软删时联动清 cache 子目录 `<cacheRoot>/<txId>/`。
  ///
  /// **不**动 documents（用户原图——30 天垃圾桶恢复路径需要）+ **不**动远端
  /// 对象（30 天后 GC 硬删时再删）。这是软删与硬删的边界：
  ///
  /// - 软删 → 只清 cache（本步）：用户从垃圾桶恢复时，附件原图在 documents
  ///   仍可读，下次同步会重新填充 cache。
  /// - 硬删 → 删 documents + 远端对象（[TrashGcService.gcExpired] 内）。
  ///
  /// 目录不存在时返回 false（幂等）。删除失败 `debugPrint` log 后返回 false——
  /// cache 残留比"清理失败硬终止"更可控；下次 prune 走 LRU 路径会兜底。
  Future<bool> removeForTransaction(String txId) async {
    if (txId.isEmpty) return false;
    final dir = Directory(p.join(_root.path, txId));
    if (!await dir.exists()) return false;
    try {
      await dir.delete(recursive: true);
      return true;
    } catch (e, st) {
      debugPrint(
        'AttachmentCachePruner.removeForTransaction $txId failed — $e\n$st',
      );
      return false;
    }
  }

  Future<void> _removeEmptyChildDirs() async {
    if (!await _root.exists()) return;
    await for (final ent in _root.list(followLinks: false)) {
      if (ent is! Directory) continue;
      try {
        final hasChild = await ent.list(followLinks: false).isEmpty == false;
        if (!hasChild) {
          await ent.delete();
        }
      } catch (_) {
        // 目录在并发删除中，跳过即可。
      }
    }
  }
}

class _PruneCandidate {
  const _PruneCandidate({
    required this.file,
    required this.size,
    required this.mtime,
  });
  final File file;
  final int size;
  final DateTime mtime;
}
