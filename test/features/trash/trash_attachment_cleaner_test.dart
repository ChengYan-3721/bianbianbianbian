import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:bianbianbianbian/features/trash/trash_attachment_cleaner.dart';

void main() {
  late Directory tmpDocs;
  late TrashAttachmentCleaner cleaner;

  setUp(() async {
    tmpDocs = await Directory.systemTemp.createTemp('trash_att_test_');
    cleaner = TrashAttachmentCleaner(docsProvider: () async => tmpDocs);
  });

  tearDown(() async {
    if (await tmpDocs.exists()) {
      await tmpDocs.delete(recursive: true);
    }
  });

  group('TrashAttachmentCleaner', () {
    test('目录不存在时返回 false（幂等）', () async {
      final ok = await cleaner.deleteForTransaction('tx-non-exist');
      expect(ok, isFalse);
    });

    test('空 txId 返回 false 不操作', () async {
      // 即便有 attachments/ 父目录也不会触碰它。
      final attachments = Directory(p.join(tmpDocs.path, 'attachments'));
      await attachments.create(recursive: true);
      final ok = await cleaner.deleteForTransaction('');
      expect(ok, isFalse);
      expect(await attachments.exists(), isTrue);
    });

    test('递归删除整个 <docs>/attachments/<txId>/ 目录及内容', () async {
      final txDir = Directory(p.join(tmpDocs.path, 'attachments', 'tx-1'));
      await txDir.create(recursive: true);
      await File(p.join(txDir.path, 'a.jpg')).writeAsBytes([1, 2, 3]);
      await File(p.join(txDir.path, 'b.png')).writeAsBytes([4, 5, 6]);

      final ok = await cleaner.deleteForTransaction('tx-1');
      expect(ok, isTrue);
      expect(await txDir.exists(), isFalse);
      // 父目录 attachments/ 仍保留——下次新流水可继续用。
      expect(
        await Directory(p.join(tmpDocs.path, 'attachments')).exists(),
        isTrue,
      );
    });

    test('批量清理：返回成功删除的目录数', () async {
      // tx-1 有目录、tx-2 有目录、tx-3 无目录（不存在）。
      for (final id in ['tx-1', 'tx-2']) {
        final dir = Directory(p.join(tmpDocs.path, 'attachments', id));
        await dir.create(recursive: true);
        await File(p.join(dir.path, 'x.dat')).writeAsBytes([0]);
      }

      final count =
          await cleaner.deleteForTransactions(['tx-1', 'tx-2', 'tx-3']);
      expect(count, 2);
      expect(
        await Directory(p.join(tmpDocs.path, 'attachments', 'tx-1')).exists(),
        isFalse,
      );
      expect(
        await Directory(p.join(tmpDocs.path, 'attachments', 'tx-2')).exists(),
        isFalse,
      );
    });
  });
}
