import 'package:flutter/foundation.dart' show immutable;

/// 流水附件的元数据（Step 11.2）。
///
/// 历史背景：`transaction_entry.attachments_encrypted` BLOB 列的 v1 设计是
/// AES-GCM 加密的二进制 blob；Step 3.5 起以明文 `["&lt;docs&gt;/attachments/&lt;tx&gt;/x.jpg",
/// ...]` 路径数组承载本地附件路径；Step 11.2 起进一步升级为 [AttachmentMeta]
/// 对象数组，把"远端 key + 本地 path + 内容指纹"装在一起，让附件文件可以
/// 跟随账本快照同步到 4 个云端 backend。
///
/// 列名 `attachments_encrypted` **保留不变**——v1 历史遗留，迁移代价高于价值；
/// 文档与注释强调"列名是历史遗留，内容已不加密"即可。
///
/// ## 字段语义
///
/// - [remoteKey]：远端对象路径，命名约定 `users/<uid>/attachments/<txId>/<sha256><ext>`。
///   `null` = 还没上传过（首次保存或 v8→v9 升级遗留）；下次同步会触发上传管线
///   `AttachmentUploader.uploadPending` 自动回填。
/// - [sha256]：附件内容的 SHA256 指纹（hex 字符串）。`null` = 未计算（与 [remoteKey]
///   同生命周期，要么都填要么都没填）。`uploadPending` 会在上传时一并算出并写回。
/// - [size]：原始字节数，迁移时调 `File.lengthSync()` 算出；新建时 `picked.length()`。
/// - [originalName]：用户视角的文件名（如 `IMG_1234.HEIC`）；用于 share / 让用户感知
///   "这是相机里的某张图"。
/// - [mime]：HTTP Content-Type（`image/jpeg` 等），`uploadBinary` 直接透传给 backend，
///   方便 Cloud Console 直接预览。
/// - [localPath]：本地绝对路径（`<documents>/attachments/<txId>/...`）。命中即直接渲染；
///   `null` 时由 [AttachmentDownloader] 拉远端写到 cache 后回填。
/// - [missing]：v8→v9 迁移时若发现旧记录中本地文件已不存在，置 `true` 标记
///   "数据已丢失，UI 显示占位"。新建附件永远是 `false`。
@immutable
class AttachmentMeta {
  const AttachmentMeta({
    this.remoteKey,
    this.sha256,
    required this.size,
    required this.originalName,
    required this.mime,
    this.localPath,
    this.missing = false,
  });

  final String? remoteKey;
  final String? sha256;
  final int size;
  final String originalName;
  final String mime;
  final String? localPath;
  final bool missing;

  AttachmentMeta copyWith({
    String? Function()? remoteKey,
    String? Function()? sha256,
    int? size,
    String? originalName,
    String? mime,
    String? Function()? localPath,
    bool? missing,
  }) {
    return AttachmentMeta(
      remoteKey: remoteKey != null ? remoteKey() : this.remoteKey,
      sha256: sha256 != null ? sha256() : this.sha256,
      size: size ?? this.size,
      originalName: originalName ?? this.originalName,
      mime: mime ?? this.mime,
      localPath: localPath != null ? localPath() : this.localPath,
      missing: missing ?? this.missing,
    );
  }

  Map<String, dynamic> toJson() => {
        'remote_key': remoteKey,
        'sha256': sha256,
        'size': size,
        'original_name': originalName,
        'mime': mime,
        'local_path': localPath,
        if (missing) 'missing': true,
      };

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) => AttachmentMeta(
        remoteKey: json['remote_key'] as String?,
        sha256: json['sha256'] as String?,
        size: (json['size'] as num?)?.toInt() ?? 0,
        originalName: (json['original_name'] as String?) ?? '',
        mime: (json['mime'] as String?) ?? 'application/octet-stream',
        localPath: json['local_path'] as String?,
        missing: json['missing'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttachmentMeta &&
        other.remoteKey == remoteKey &&
        other.sha256 == sha256 &&
        other.size == size &&
        other.originalName == originalName &&
        other.mime == mime &&
        other.localPath == localPath &&
        other.missing == missing;
  }

  @override
  int get hashCode => Object.hash(
        remoteKey,
        sha256,
        size,
        originalName,
        mime,
        localPath,
        missing,
      );

  @override
  String toString() => 'AttachmentMeta(remoteKey: $remoteKey, '
      'sha256: ${sha256 == null ? 'null' : '${sha256!.substring(0, 8)}…'}, '
      'size: $size, originalName: $originalName, mime: $mime, '
      'localPath: $localPath, missing: $missing)';
}
