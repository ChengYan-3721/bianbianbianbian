import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Phase 12 Step 12.2 / 12.3：永久删除流水时，附件目录
/// `<documents>/attachments/<txId>/` 也要随之物理移除——`record_new_providers.dart`
/// 把附件 copy 到该目录，DB 行被硬删后这些文件就成了孤儿，会随时间累积。
///
/// 提供一个抽象层与可注入的 [DocumentsDirProvider]：
/// - 生产路径走 [getApplicationDocumentsDirectory]；
/// - 单元测试注入临时目录，验证目录是否被真的删掉。
typedef DocumentsDirProvider = Future<Directory> Function();

class TrashAttachmentCleaner {
  TrashAttachmentCleaner({DocumentsDirProvider? docsProvider})
      : _docs = docsProvider ?? getApplicationDocumentsDirectory;

  final DocumentsDirProvider _docs;

  /// 递归删除 `<documents>/attachments/<txId>/` 整个目录。
  /// 目录不存在时静默返回 false——幂等，调用方不需要先判存。
  Future<bool> deleteForTransaction(String txId) async {
    if (txId.isEmpty) return false;
    final docs = await _docs();
    final dir = Directory(p.join(docs.path, 'attachments', txId));
    if (!await dir.exists()) return false;
    try {
      await dir.delete(recursive: true);
      return true;
    } catch (_) {
      // 删除失败（权限 / 文件被占用）静默吞掉——附件残留比"清理失败硬终止"
      // 更可控；下一次 GC 重试。
      return false;
    }
  }

  /// 批量清理。返回成功删除的目录数量。
  Future<int> deleteForTransactions(Iterable<String> txIds) async {
    var ok = 0;
    for (final id in txIds) {
      if (await deleteForTransaction(id)) ok++;
    }
    return ok;
  }
}

/// keepAlive 单例——附件清理是无状态的，整个 App 共享一个实例即可。
final trashAttachmentCleanerProvider = Provider<TrashAttachmentCleaner>(
  (ref) => TrashAttachmentCleaner(),
);
