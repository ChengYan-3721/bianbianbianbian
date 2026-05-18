import 'package:flutter/foundation.dart' show debugPrint, immutable;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import '../../data/local/app_database.dart';
import 'snapshot_serializer.dart';

/// 云端备份的可展示快照——`BackupListPage` 一行一条。
///
/// 与 [LedgerSnapshot] 的区别:[RemoteBackup] 只携带"列表 UI 需要的元信息"
/// (不含 transactions/budgets 数组),展示开销可控;选中后再走 download 取完整
/// snapshot 做 import。
///
/// `sourceDeviceId` 来自 snapshot 内部的 `device_id`(即"上传该备份的设备"),
/// **不是**路径里的 `<uid>` 段——后者对 Supabase 是 auth.uid,与上传方设备解耦。
@immutable
class RemoteBackup {
  final String ledgerId;
  final String ledgerName;
  final String sourceDeviceId;
  final String cloudPath;
  final DateTime exportedAt;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int? sizeBytes;

  const RemoteBackup({
    required this.ledgerId,
    required this.ledgerName,
    required this.sourceDeviceId,
    required this.cloudPath,
    required this.exportedAt,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    this.sizeBytes,
  });
}

/// 枚举云端 `users/.../ledgers/*.json`,逐个下载解析为 [RemoteBackup] 列表。
///
/// - `authUid != null`:鉴权后端(Supabase 等),只扫 `users/<authUid>/ledgers/`,
///   RLS 必须;
/// - `authUid == null`:非鉴权后端(S3 / WebDAV / iCloud),桶内任何 `users/<*>/`
///   都是用户自己的——先列 `users/` 拿到所有子目录,再逐个进 `ledgers/`。
///
/// 单个 JSON 解析失败(损坏 / 版本不兼容)的备份会被静默跳过,不会让整张列表
/// 失败——避免一份坏数据让用户无法恢复其他正常备份。
///
/// 结果按 `exportedAt` 降序排,最近一次备份排第一。
Future<List<RemoteBackup>> discoverBackups({
  required CloudStorageService storage,
  required String? authUid,
}) async {
  const serializer = LedgerSnapshotSerializer();
  final results = <RemoteBackup>[];

  // Step 1:收集候选 .json 文件。
  //
  // 鉴权后端(authUid != null):RLS 限制只能扫自己的 `users/<authUid>/ledgers/`。
  //
  // 非鉴权后端(S3 / WebDAV / iCloud):整桶都是当前用户的,扫整个 `users/`。
  // 但不同后端 `list` 语义不一致:
  //  - WebDAV / iCloud:返回当前目录的直接子条目(子目录 + 文件);
  //  - S3:无目录概念,`listObjects(prefix: 'users/')` 返回所有匹配前缀的**扁平 key**
  //    (例如 `users/cn1/ledgers/abc.json`)。
  // 所以这里要同时兼容两种形态:
  //  - 条目本身就是 .json 文件 → 直接当备份候选(命中 S3 扁平 key);
  //  - 条目不是 .json → 当成子目录,再 list 一次 `<dir>/ledgers/`(WebDAV/iCloud)。
  final candidates = <CloudFile>[];

  if (authUid != null) {
    try {
      final files = await storage.list(path: 'users/$authUid/ledgers/');
      candidates.addAll(files.where((f) => f.name.endsWith('.json')));
    } catch (e, st) {
      // 真鉴权后端的目录 list 失败往外抛——这是配置/权限错误,UI 需展示给用户
      // (例:Supabase RLS 没配 SELECT 权限)。静默吞掉只会让用户看见"无备份"
      // 假象,问题永远定位不到。
      debugPrint('discoverBackups: list(users/$authUid/ledgers/) failed — $e\n$st');
      rethrow;
    }
  } else {
    final List<CloudFile> topLevel;
    try {
      topLevel = await storage.list(path: 'users/');
    } catch (e, st) {
      // 同上——伪鉴权后端顶层 list 失败通常意味着 token 缺 bucket-list 权限
      // (R2 / S3 的常见坑:token 只给了 Object Read & Write,没勾 Bucket Read),
      // 必须把真实错误透传到 UI,不能让用户看到"空列表"误以为没数据。
      debugPrint('discoverBackups: list(users/) failed — $e\n$st');
      rethrow;
    }

    for (final entry in topLevel) {
      if (entry.path.endsWith('.json')) {
        // S3 扁平 key:已经是完整的 `users/<x>/ledgers/<y>.json`,直接收。
        candidates.add(entry);
      } else {
        // WebDAV/iCloud 风格的子目录:再下钻一层。二级 list 的失败仍然静默——
        // 桶里可能混着 `users/attachments/` 这种非 ledgers 的目录,跳过即可。
        final base = entry.path.endsWith('/') ? entry.path : '${entry.path}/';
        final dir = '${base}ledgers/';
        try {
          final files = await storage.list(path: dir);
          candidates.addAll(files.where((f) => f.name.endsWith('.json')));
        } catch (e, st) {
          debugPrint('discoverBackups: list($dir) failed — $e\n$st');
          continue;
        }
      }
    }
  }

  // Step 2:逐个下载解析。单条解析失败(损坏 / 不兼容版本)静默跳过,不让一份坏
  // 数据让整张列表 fail——避免用户彻底无法恢复其他正常备份。
  for (final file in candidates) {
    final String? raw;
    try {
      raw = await storage.download(path: file.path);
    } catch (e, st) {
      debugPrint('discoverBackups: download(${file.path}) failed — $e\n$st');
      continue;
    }
    if (raw == null) continue;
    try {
      final snap = await serializer.deserialize(raw);
      results.add(RemoteBackup(
        ledgerId: snap.ledger.id,
        ledgerName: snap.ledger.name,
        sourceDeviceId: snap.deviceId,
        cloudPath: file.path,
        exportedAt: snap.exportedAt,
        transactionCount: snap.transactions.length,
        accountCount: snap.accounts.length,
        categoryCount: snap.categories.length,
        sizeBytes: file.size,
      ));
    } catch (e, st) {
      debugPrint('discoverBackups: parse(${file.path}) failed — $e\n$st');
    }
  }

  results.sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
  return results;
}

/// 从指定 [backup] 下载云端 JSON,以"新账本"形式落到本地 DB。
///
/// 流程:`storage.download(backup.cloudPath)` → 反序列化为 [LedgerSnapshot]
/// → [importLedgerSnapshotAsNew]。云端文件已不存在时抛 [StateError]
/// (典型场景:列表打开后另一个设备删了备份)。
///
/// `uuidFactory` 透传到 [importLedgerSnapshotAsNew],测试时可注入计数器。
Future<String> restoreBackupAsNew({
  required CloudStorageService storage,
  required RemoteBackup backup,
  required AppDatabase db,
  String Function()? uuidFactory,
}) async {
  final raw = await storage.download(path: backup.cloudPath);
  if (raw == null) {
    throw StateError('Backup no longer exists in cloud: ${backup.cloudPath}');
  }
  final snap = await const LedgerSnapshotSerializer().deserialize(raw);
  return importLedgerSnapshotAsNew(
    snapshot: snap,
    db: db,
    uuidFactory: uuidFactory,
  );
}
