import '../../../data/local/app_database.dart';
import '../../../data/local/attachment_meta_codec.dart';
import '../../../domain/entity/attachment_meta.dart';

/// Step 11.4：跨 backend 切换的"附件迁移"工具集。
///
/// 用户从 backend A 切到 backend B 时，已上传到 A 的对象在 B 上找不到。
/// 把所有 `remoteKey != null` 的 meta `remoteKey` 清为 null（**保留**
/// `localPath`），下次 [SnapshotSyncService.upload] 内部走 `uploadPending`
/// 分支会自然把这些附件重新上传到 B。
///
/// 旧 backend A 上的对象**不**主动删——理由：① 用户可能切回 A，那些对象
/// 仍有用；② 切走后 sweep 不再触发 A，主动删风险大于价值；③ 可由用户
/// 手动从 backend 控制台清理。
///
/// **不**清 `sha256` —— 与 [AttachmentUploader.uploadPending] 内部行为
/// 一致：上传时 sha256 会按真实字节重算并覆盖原值，预留与否对结果无影响。
/// 而保留 sha256 让"重新上传 + 内容相同 → exists() 命中跳过"在迁移到
/// 同一 backend 副本（罕见但不阻止）的场景下仍能短路。
///
/// 注意：`localPath == null` 的 meta 在迁移后既无 `remoteKey` 也无本地
/// 文件 → UI 展示"未同步"占位；这是用户切 backend 同时本地附件丢失的
/// 极端情况，无解（旧 backend 上对象虽在但解关联），跳过即可。

/// 把 DB 中所有 `remoteKey != null` 的 meta 的 `remoteKey` 清为 null。
/// 返回受影响行数（每行至少一条 meta 被清算一次）。
///
/// **不**改 `updated_at` —— 与 `_uploadPendingAttachments` 一致：附件
/// metadata 微调不应触发同步状态变化。下次 upload 会自然走 `uploadPending`
/// 把这些清空的 remoteKey 重新填回。
Future<int> clearAllRemoteAttachmentKeys(AppDatabase db) async {
  final rows = await (db.select(db.transactionEntryTable)
        ..where((t) => t.attachmentsEncrypted.isNotNull()))
      .get();
  var changedRows = 0;
  for (final row in rows) {
    final blob = row.attachmentsEncrypted;
    if (blob == null || blob.isEmpty) continue;
    final metas = AttachmentMetaCodec.decode(blob);
    if (metas.isEmpty) continue;
    if (!metas.any((m) => m.remoteKey != null)) continue;

    final cleared = <AttachmentMeta>[
      for (final m in metas)
        if (m.remoteKey == null) m else m.copyWith(remoteKey: () => null),
    ];
    final encoded = AttachmentMetaCodec.encode(cleared);
    await db.customStatement(
      'UPDATE transaction_entry SET attachments_encrypted = ? WHERE id = ?',
      [encoded, row.id],
    );
    changedRows++;
  }
  return changedRows;
}

/// 统计当前 DB 中有多少条附件 meta 已上传（`remoteKey != null`）。用于跨
/// backend 切换确认对话框的"已上传到当前 backend 的附件数"提示。
///
/// 同 sha256 跨 tx 算两条——计数与"远端实际对象数"一致（Phase 11.2 决策：
/// 路径含 txId，同图跨 tx 不去重）。
Future<int> countAttachmentsWithRemoteKey(AppDatabase db) async {
  final rows = await (db.select(db.transactionEntryTable)
        ..where((t) => t.attachmentsEncrypted.isNotNull()))
      .get();
  var count = 0;
  for (final row in rows) {
    final blob = row.attachmentsEncrypted;
    if (blob == null || blob.isEmpty) continue;
    final metas = AttachmentMetaCodec.decode(blob);
    for (final m in metas) {
      if (m.remoteKey != null) count++;
    }
  }
  return count;
}
