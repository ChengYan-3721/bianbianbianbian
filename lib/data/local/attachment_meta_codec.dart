import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../domain/entity/attachment_meta.dart';

/// `transaction_entry.attachments_encrypted` BLOB 列的明文 JSON 编解码器。
///
/// 列名是历史遗留（v1 设计为 AES-GCM 密文）；Step 11.2 起内容是
/// `List<AttachmentMeta>` 的明文 JSON 数组。详见 [AttachmentMeta]。
///
/// 兼容 Step 3.5 的旧 shape `["<path>", ...]`：[decode] 先尝试解析为对象
/// 数组，失败回退到旧 string 数组（数据库迁移与运行期都可能撞到）。
class AttachmentMetaCodec {
  const AttachmentMetaCodec._();

  /// 把元数据列表编码为 BLOB 字节。空列表返回 `null` —— 表示该流水无附件。
  static Uint8List? encode(List<AttachmentMeta> metas) {
    if (metas.isEmpty) return null;
    final list = metas.map((m) => m.toJson()).toList(growable: false);
    return Uint8List.fromList(utf8.encode(jsonEncode(list)));
  }

  /// 把 BLOB 字节解码为元数据列表。`null` / 空 / 解析失败均返回 `const []`。
  ///
  /// 兼容旧 shape：当顶层是字符串数组时，把每个 `path` 包成 `AttachmentMeta`，
  /// 用 [AttachmentMetaUpgradeOps.upgradeLegacyPath] 推断 size / mime / missing。
  static List<AttachmentMeta> decode(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return const <AttachmentMeta>[];
    try {
      final raw = utf8.decode(bytes);
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <AttachmentMeta>[];
      final list = <AttachmentMeta>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          list.add(AttachmentMeta.fromJson(item));
        } else if (item is String) {
          list.add(AttachmentMetaUpgradeOps.upgradeLegacyPath(item));
        }
      }
      return List<AttachmentMeta>.unmodifiable(list);
    } catch (_) {
      return const <AttachmentMeta>[];
    }
  }
}

/// v8 → v9 迁移用：把单条旧 shape 路径升级为 [AttachmentMeta]。
///
/// 行为：
/// - `original_name` = path basename；
/// - `mime` = 按扩展名查 `lookupMimeType`（命中不到回退到
///   `application/octet-stream`）；
/// - `size` = `File(path).lengthSync()`；文件不存在 → `size = 0` + `missing: true`；
/// - `remote_key` / `sha256` 一律 `null`，等下次同步触发回填。
///
/// 抽出独立类是为了既能在 [AppDatabase.migration] 同步执行（用 `lengthSync`），
/// 又能在迁移单测里 mock 文件系统（注入 `fileLength`）。
class AttachmentMetaUpgradeOps {
  AttachmentMetaUpgradeOps._();

  /// 升级单条旧字符串路径，[fileLength] 注入文件大小（`null` = 文件不存在 →
  /// 标记 missing）。生产路径走 [upgradeLegacyPath] 自动从磁盘读。
  static AttachmentMeta upgradeLegacyPathWithLength(
    String path, {
    required int? fileLength,
  }) {
    final mime = lookupMimeType(path) ?? 'application/octet-stream';
    final name = p.basename(path);
    if (fileLength == null) {
      return AttachmentMeta(
        size: 0,
        originalName: name,
        mime: mime,
        localPath: path,
        missing: true,
      );
    }
    return AttachmentMeta(
      size: fileLength,
      originalName: name,
      mime: mime,
      localPath: path,
    );
  }

  /// 生产路径：从磁盘读 size，文件不存在标记 missing。
  static AttachmentMeta upgradeLegacyPath(String path) {
    final file = File(path);
    int? len;
    try {
      len = file.existsSync() ? file.lengthSync() : null;
    } catch (_) {
      len = null;
    }
    return upgradeLegacyPathWithLength(path, fileLength: len);
  }
}

/// v8 → v9 迁移：扫表把每行 `attachments_encrypted` BLOB 从字符串数组升级为
/// [AttachmentMeta] 对象数组。pure-Dart 函数，便于单测注入文件系统。
///
/// [readFileLength] 接收本地路径返回字节数，文件不存在返回 `null`。生产路径
/// 注入 `File(path).lengthSync()`；测试路径注入 mock map。
List<({String id, Uint8List newBlob})> migrateAttachmentsBlobV8ToV9(
  List<({String id, Uint8List blob})> rows, {
  required int? Function(String path) readFileLength,
}) {
  final out = <({String id, Uint8List newBlob})>[];
  for (final row in rows) {
    final raw = utf8.decode(row.blob);
    final decoded = jsonDecode(raw);
    if (decoded is! List) continue;

    // 判定是否已是新 shape（对象数组）。已是新 shape 跳过——幂等。
    if (decoded.isEmpty) continue;
    final first = decoded.first;
    if (first is Map) continue;

    final metas = <AttachmentMeta>[];
    for (final item in decoded) {
      if (item is! String) continue;
      final len = readFileLength(item);
      metas.add(AttachmentMetaUpgradeOps.upgradeLegacyPathWithLength(
        item,
        fileLength: len,
      ));
    }
    final encoded = AttachmentMetaCodec.encode(metas);
    if (encoded != null) {
      out.add((id: row.id, newBlob: encoded));
    }
  }
  return out;
}
