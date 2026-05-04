import 'package:flutter/foundation.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/attachment_meta_codec.dart';

/// Step 11.4：远端附件孤儿对象 sweeper。
///
/// 调用 [CloudStorageService.listBinary] 取出 `users/<uid>/attachments/`
/// 前缀下全部对象，与 DB 中所有 `attachments_encrypted` BLOB 解码后的
/// `remoteKey` 集合做差分；远端有但 DB 无的视为孤儿候选。
///
/// **30 天宽限期**：孤儿候选 `lastModified` 在 `now - graceDuration` 之后
/// 的暂不删——理由：① 用户可能在另一设备上还没同步快照下来，此刻判定
/// 为孤儿可能误删别人正用的对象；② 与垃圾桶 30 天保留策略对齐。
///
/// **触发时机**：`main.dart` bootstrap 链冷启动 + 5 分钟延迟 fire-and-forget；
/// 7 天节流（用 SharedPreferences `kLastOrphanSweepAtPrefKey` 记 epoch ms，
/// 见 main.dart 实施）。失败静默——sweep 是 best-effort 后台任务。
class AttachmentOrphanSweeper {
  AttachmentOrphanSweeper({
    required AppDatabase db,
    required CloudStorageService storage,
    required String uid,
    Duration grace = kAttachmentOrphanGrace,
  })  : _db = db,
        _storage = storage,
        _uid = uid,
        _grace = grace;

  final AppDatabase _db;
  final CloudStorageService _storage;
  final String _uid;
  final Duration _grace;

  /// 一次性扫描——返回 [AttachmentOrphanSweepReport]：扫描数 / 真删除数 /
  /// 跳过数（命中 DB / 在宽限期内 / 删除失败）。
  ///
  /// 任何顶层异常（list 失败 / DB 查询失败）都被吞掉并返回空报告——这是
  /// best-effort 后台任务，不应影响调用方。单条对象 delete 失败也只是计入
  /// `skipped`，下一轮 sweep 再尝试。
  Future<AttachmentOrphanSweepReport> sweep({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final cutoff = clock.subtract(_grace);

    final List<CloudFile> remote;
    try {
      remote = await _storage.listBinary(prefix: 'users/$_uid/attachments/');
    } catch (e, st) {
      debugPrint('AttachmentOrphanSweeper: listBinary failed — $e\n$st');
      return const AttachmentOrphanSweepReport(
        scanned: 0,
        deleted: 0,
        skipped: 0,
      );
    }

    if (remote.isEmpty) {
      return const AttachmentOrphanSweepReport(
        scanned: 0,
        deleted: 0,
        skipped: 0,
      );
    }

    final Set<String> dbKeys;
    try {
      dbKeys = await _collectDbRemoteKeys();
    } catch (e, st) {
      debugPrint('AttachmentOrphanSweeper: db query failed — $e\n$st');
      return AttachmentOrphanSweepReport(
        scanned: remote.length,
        deleted: 0,
        skipped: remote.length,
      );
    }

    var deleted = 0;
    var skipped = 0;
    for (final obj in remote) {
      if (dbKeys.contains(obj.path)) {
        // 仍被某条流水的 meta 引用 → 不是孤儿
        continue;
      }
      // 宽限期内（含 lastModified 缺失的"未知龄期"）暂不清——下一轮再判定。
      // **lastModified == null 时保守跳过**：iCloud / WebDAV 个别 backend
      // 可能不返回时间戳，宁可漏删也不误删。
      final lm = obj.lastModified;
      if (lm == null || lm.isAfter(cutoff)) {
        skipped++;
        continue;
      }
      try {
        await _storage.delete(path: obj.path);
        deleted++;
      } catch (e, st) {
        debugPrint(
          'AttachmentOrphanSweeper: delete ${obj.path} failed — $e\n$st',
        );
        skipped++;
      }
    }
    return AttachmentOrphanSweepReport(
      scanned: remote.length,
      deleted: deleted,
      skipped: skipped,
    );
  }

  /// 扫表收集所有 `attachments_encrypted` 解码后非空的 `remoteKey`。
  /// 同 sha256 跨 tx 不去重——DB 内同 path 出现多次也只记一次（Set 语义）。
  Future<Set<String>> _collectDbRemoteKeys() async {
    final rows = await (_db.select(_db.transactionEntryTable)
          ..where((t) => t.attachmentsEncrypted.isNotNull()))
        .get();
    final out = <String>{};
    for (final row in rows) {
      final blob = row.attachmentsEncrypted;
      if (blob == null || blob.isEmpty) continue;
      final metas = AttachmentMetaCodec.decode(blob);
      for (final m in metas) {
        final key = m.remoteKey;
        if (key != null) out.add(key);
      }
    }
    return out;
  }
}

/// sweep 完成报告——便于 UI / log 调试。
@immutable
class AttachmentOrphanSweepReport {
  const AttachmentOrphanSweepReport({
    required this.scanned,
    required this.deleted,
    required this.skipped,
  });

  /// 远端列表中扫到的对象总数。
  final int scanned;

  /// 真实被 `delete` 删除的孤儿数。
  final int deleted;

  /// 跳过未删数：命中 DB（仍被引用）/ 在宽限期内 / 单条 delete 异常 三类合并。
  /// 当前不细分——sweep 报告主要给 log，不给 UI 做诊断。
  final int skipped;

  bool get isEmpty => scanned == 0 && deleted == 0 && skipped == 0;

  @override
  String toString() =>
      'AttachmentOrphanSweepReport(scanned=$scanned, deleted=$deleted, '
      'skipped=$skipped)';
}

/// 远端孤儿宽限期：30 天。与 design-document.md 垃圾桶保留策略对齐——
/// 同一道时间轴：本机软删 30 天后由 trash GC 硬删，远端孤儿 30 天后由
/// sweep 清理；前后两道防线兜住"网络中断 / 跨设备时序错乱"等异常情形。
const Duration kAttachmentOrphanGrace = Duration(days: 30);

/// SharedPreferences 用的节流键：上次孤儿 sweep 完成时刻（epoch ms）。
/// `main.dart` bootstrap 触发前读取，超过 7 天才真跑——避免每次冷启动
/// 都打 listBinary。
const String kLastOrphanSweepAtPrefKey = 'attachment.last_orphan_sweep_at_ms';

/// sweep 节流间隔：7 天。与 implementation-plan §11.4 约定一致。
const Duration kOrphanSweepInterval = Duration(days: 7);
