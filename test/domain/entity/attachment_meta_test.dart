import 'dart:convert';
import 'dart:typed_data';

import 'package:bianbianbianbian/data/local/attachment_meta_codec.dart';
import 'package:bianbianbianbian/domain/entity/attachment_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttachmentMeta · toJson/fromJson', () {
    test('完整字段往返保留所有信息', () {
      final meta = AttachmentMeta(
        remoteKey: 'users/u1/attachments/tx1/abc.jpg',
        sha256: 'a' * 64,
        size: 12345,
        originalName: 'IMG_1.jpg',
        mime: 'image/jpeg',
        localPath: '/docs/attachments/tx1/IMG_1.jpg',
      );
      final json = meta.toJson();
      final restored = AttachmentMeta.fromJson(json);
      expect(restored, equals(meta));
    });

    test('null 字段（remoteKey/sha256/localPath）正确保留', () {
      const meta = AttachmentMeta(
        size: 100,
        originalName: 'x.png',
        mime: 'image/png',
      );
      final json = meta.toJson();
      expect(json['remote_key'], isNull);
      expect(json['sha256'], isNull);
      expect(json['local_path'], isNull);
      final restored = AttachmentMeta.fromJson(json);
      expect(restored, equals(meta));
    });

    test('missing=true 序列化进 JSON、false 不出现', () {
      const missing = AttachmentMeta(
        size: 0,
        originalName: 'lost.jpg',
        mime: 'image/jpeg',
        missing: true,
      );
      expect(missing.toJson()['missing'], isTrue);

      const present = AttachmentMeta(
        size: 1,
        originalName: 'ok.jpg',
        mime: 'image/jpeg',
      );
      expect(present.toJson().containsKey('missing'), isFalse);
    });

    test('fromJson 容忍空字段 / 缺失字段', () {
      final m = AttachmentMeta.fromJson(const <String, dynamic>{});
      expect(m.size, 0);
      expect(m.originalName, '');
      expect(m.mime, 'application/octet-stream');
      expect(m.remoteKey, isNull);
      expect(m.sha256, isNull);
      expect(m.localPath, isNull);
      expect(m.missing, isFalse);
    });
  });

  group('AttachmentMeta · copyWith', () {
    test('copyWith 把 remoteKey 从 null 改为非 null', () {
      const m = AttachmentMeta(
        size: 1,
        originalName: 'a.jpg',
        mime: 'image/jpeg',
      );
      final updated = m.copyWith(
        remoteKey: () => 'remote/key',
        sha256: () => 'h' * 64,
      );
      expect(updated.remoteKey, 'remote/key');
      expect(updated.sha256, 'h' * 64);
      // 其他字段不变
      expect(updated.size, m.size);
      expect(updated.originalName, m.originalName);
    });

    test('copyWith 不传参时与原对象相等', () {
      const m = AttachmentMeta(
        size: 1,
        originalName: 'a.jpg',
        mime: 'image/jpeg',
        remoteKey: 'r',
        sha256: 'h',
      );
      expect(m.copyWith(), equals(m));
    });
  });

  group('AttachmentMetaCodec · encode/decode', () {
    test('空列表 encode 返回 null', () {
      expect(AttachmentMetaCodec.encode(const []), isNull);
    });

    test('encode → decode 往返保留字段', () {
      final metas = [
        const AttachmentMeta(
          size: 100,
          originalName: '1.jpg',
          mime: 'image/jpeg',
          localPath: '/a/1.jpg',
        ),
        AttachmentMeta(
          size: 200,
          originalName: '2.png',
          mime: 'image/png',
          localPath: '/a/2.png',
          remoteKey: 'users/u/attachments/t/h.png',
          sha256: 'h' * 64,
        ),
      ];
      final bytes = AttachmentMetaCodec.encode(metas);
      expect(bytes, isNotNull);
      final restored = AttachmentMetaCodec.decode(bytes);
      expect(restored, equals(metas));
    });

    test('decode 兼容旧 shape（字符串数组）', () {
      // v8 shape: ["path1", "path2"]
      final paths = ['/a/1.jpg', '/a/2.jpg'];
      final legacy = jsonEncode(paths);
      final bytes = Uint8List.fromList(utf8.encode(legacy));
      final metas = AttachmentMetaCodec.decode(bytes);
      expect(metas, hasLength(2));
      expect(metas[0].originalName, '1.jpg');
      expect(metas[0].localPath, '/a/1.jpg');
      expect(metas[0].mime, 'image/jpeg');
      expect(metas[0].remoteKey, isNull);
      expect(metas[0].sha256, isNull);
      // 文件不存在 → missing
      expect(metas[0].missing, isTrue);
    });

    test('decode null/空/非法 JSON 都返回空列表', () {
      expect(AttachmentMetaCodec.decode(null), isEmpty);
      expect(AttachmentMetaCodec.decode(Uint8List(0)), isEmpty);
      expect(
        AttachmentMetaCodec.decode(Uint8List.fromList(utf8.encode('not json'))),
        isEmpty,
      );
      expect(
        AttachmentMetaCodec.decode(
            Uint8List.fromList(utf8.encode('{"not":"a list"}'))),
        isEmpty,
      );
    });
  });

  group('migrateAttachmentsBlobV8ToV9', () {
    test('旧 string 数组升级为 v9 对象数组（带 size 推断 + missing 标记）', () {
      final input = <({String id, Uint8List blob})>[
        (
          id: 'tx-1',
          blob: Uint8List.fromList(
              utf8.encode(jsonEncode(['/a/exists.jpg', '/a/missing.png']))),
        ),
      ];
      final results = migrateAttachmentsBlobV8ToV9(
        input,
        readFileLength: (path) => path == '/a/exists.jpg' ? 5000 : null,
      );
      expect(results, hasLength(1));
      final decoded = AttachmentMetaCodec.decode(results.first.newBlob);
      expect(decoded, hasLength(2));
      expect(decoded[0].size, 5000);
      expect(decoded[0].missing, isFalse);
      expect(decoded[0].mime, 'image/jpeg');
      expect(decoded[1].size, 0);
      expect(decoded[1].missing, isTrue);
      expect(decoded[1].mime, 'image/png');
    });

    test('已是 v9 对象数组的行被跳过（幂等）', () {
      final v9 = jsonEncode([
        const AttachmentMeta(
          size: 100,
          originalName: 'x.jpg',
          mime: 'image/jpeg',
        ).toJson()
      ]);
      final input = <({String id, Uint8List blob})>[
        (id: 'tx-2', blob: Uint8List.fromList(utf8.encode(v9))),
      ];
      final results = migrateAttachmentsBlobV8ToV9(
        input,
        readFileLength: (_) => null,
      );
      expect(results, isEmpty,
          reason: '已是 v9 形态的行不应产生新 BLOB（幂等）');
    });

    test('空数组的行被跳过', () {
      final input = <({String id, Uint8List blob})>[
        (id: 'tx-3', blob: Uint8List.fromList(utf8.encode('[]'))),
      ];
      final results = migrateAttachmentsBlobV8ToV9(
        input,
        readFileLength: (_) => null,
      );
      expect(results, isEmpty);
    });
  });
}
