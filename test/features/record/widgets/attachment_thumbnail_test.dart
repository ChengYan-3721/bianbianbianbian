import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bianbianbianbian/domain/entity/attachment_meta.dart';
import 'package:bianbianbianbian/features/record/widgets/attachment_thumbnail.dart';
import 'package:bianbianbianbian/features/sync/attachment/attachment_downloader.dart';
import 'package:bianbianbianbian/features/sync/attachment/attachment_providers.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 极简 storage mock —— 支持手动控制 download 何时 resolve（loading 态测试用）。
class _ControllableStorage implements CloudStorageService {
  final Map<String, Uint8List> store = {};
  Completer<void>? gate;
  bool throwOnDownload = false;

  @override
  Future<Uint8List?> downloadBinary({required String path}) async {
    if (gate != null) {
      await gate!.future;
    }
    if (throwOnDownload) {
      throw CloudStorageException('mock');
    }
    return store[path];
  }

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {}

  @override
  Future<String?> download({required String path}) async => null;

  @override
  Future<void> uploadBinary({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  }) async {}

  @override
  Future<void> delete({required String path}) async {}

  @override
  Future<bool> exists({required String path}) async => false;

  @override
  Future<List<CloudFile>> list({required String path}) async => const [];

  @override
  Future<List<CloudFile>> listBinary({required String prefix}) async =>
      const [];

  @override
  Future<CloudFile?> getMetadata({required String path}) async => null;
}

/// **关于本测试的设计取舍**：Image.file 在 widget 测试环境中渲染会启动一个
/// 异步解码 pipeline，即便用 [tester.runAsync] 也很难干净地让它在 tearDown
/// 之前完全释放本地文件句柄。Windows 上这会让临时目录删除失败，整个测试套件
/// 挂在 tearDown 直到默认 10 分钟超时。
///
/// 因此本文件只测**非渲染分支**：loading / missing / onTap。成功路径
/// （`Image.file` 真的画出来）由整 App 集成测试与手工验收覆盖。
void main() {
  late Directory tempDir;
  late Directory cacheRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('att_thumb_test_');
    cacheRoot = Directory(p.join(tempDir.path, 'cache'));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      // Windows 下 IO 句柄可能短暂未释放——重试几次。
      for (var i = 0; i < 3; i++) {
        try {
          await tempDir.delete(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  });

  Widget wrap({
    required AttachmentDownloader? downloader,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        attachmentDownloaderProvider.overrideWith((ref) async => downloader),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('downloader == null + remoteKey != null 渲染未同步占位', (tester) async {
    const meta = AttachmentMeta(
      remoteKey: 'users/u/attachments/tx-1/x.jpg',
      sha256: 'x',
      size: 1,
      originalName: 'x.jpg',
      mime: 'image/jpeg',
    );

    await tester.pumpWidget(
      wrap(
        downloader: null,
        child: const AttachmentThumbnail(meta: meta, txId: 'tx-1', size: 60),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('attachment_thumbnail_missing')), findsOneWidget);
  });

  testWidgets('remoteKey == null + localPath == null 渲染未同步占位', (tester) async {
    const meta = AttachmentMeta(
      size: 0,
      originalName: 'lost.jpg',
      mime: 'image/jpeg',
      missing: true,
    );
    final downloader = AttachmentDownloader(
      storage: _ControllableStorage(),
      cacheRoot: cacheRoot,
    );

    await tester.pumpWidget(
      wrap(
        downloader: downloader,
        child: const AttachmentThumbnail(meta: meta, txId: 'tx-1', size: 60),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('attachment_thumbnail_missing')), findsOneWidget);
  });

  testWidgets('storage 抛网络错误时渲染未同步占位', (tester) async {
    final storage = _ControllableStorage()..throwOnDownload = true;
    final downloader = AttachmentDownloader(
      storage: storage,
      cacheRoot: cacheRoot,
    );

    const meta = AttachmentMeta(
      remoteKey: 'users/u/attachments/tx-1/x.jpg',
      sha256: 'x',
      size: 1,
      originalName: 'x.jpg',
      mime: 'image/jpeg',
    );

    await tester.pumpWidget(
      wrap(
        downloader: downloader,
        child: const AttachmentThumbnail(meta: meta, txId: 'tx-1', size: 60),
      ),
    );
    // 等 async override → ensureLocal → throw → null 完成
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('attachment_thumbnail_missing')), findsOneWidget);
  });

  testWidgets('Provider 仍在 loading 时显示骨架屏', (tester) async {
    // 永远不 resolve 的 downloader provider —— 模拟 Riverpod 链路启动初期的
    // AsyncLoading 态。
    final neverDownloader = Completer<AttachmentDownloader?>();
    const meta = AttachmentMeta(
      remoteKey: 'users/u/attachments/tx-1/x.jpg',
      sha256: 'x',
      size: 1,
      originalName: 'x.jpg',
      mime: 'image/jpeg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentDownloaderProvider.overrideWith(
            (ref) => neverDownloader.future,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: AttachmentThumbnail(meta: meta, txId: 'tx-1', size: 60),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('attachment_thumbnail_loading')),
      findsOneWidget,
    );

    // 收尾：解锁 future 让 testWidgets 干净退出，避免 pending Completer。
    neverDownloader.complete(null);
    await tester.pump();
  });

  testWidgets('onTap 回调触发 InkWell tap', (tester) async {
    const meta = AttachmentMeta(
      remoteKey: 'users/u/attachments/tx-1/x.jpg',
      sha256: 'x',
      size: 1,
      originalName: 'x.jpg',
      mime: 'image/jpeg',
    );

    var taps = 0;
    await tester.pumpWidget(
      wrap(
        downloader: null,
        child: AttachmentThumbnail(
          meta: meta,
          txId: 'tx-1',
          size: 60,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // missing 占位下 InkWell 仍可点
    await tester.tap(find.byType(AttachmentThumbnail));
    await tester.pump();
    expect(taps, 1);
  });
}
