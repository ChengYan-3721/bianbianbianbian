import 'dart:io';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/local/providers.dart' as local;
import '../sync_provider.dart';
import 'attachment_cache_pruner.dart';
import 'attachment_downloader.dart';
import 'attachment_orphan_sweeper.dart';

/// Step 11.3：附件缓存根目录——`<cache>/attachments/`。
///
/// 走 [getApplicationCacheDirectory] 而非 documents：iOS 在空间紧张时会
/// 自动清理 cache 目录，下次访问触发重新懒下载即可，App 不需要主动管理。
/// Android 下同样使用系统 cache 目录（与 documents 区分），习惯一致。
final attachmentCacheRootProvider = FutureProvider<Directory>((ref) async {
  final base = await getApplicationCacheDirectory();
  final root = Directory(p.join(base.path, 'attachments'));
  // 不在此处 `create()` —— pruner / downloader 各自按需 mkdir，避免空目录。
  return root;
});

/// 当前激活的附件 [CloudStorageService]：直接复用 [cloudProviderInstanceProvider]
/// 拿到 backend 的 storage。未配置云服务返回 null（UI 走"附件仅本地"分支）。
final attachmentStorageServiceProvider =
    FutureProvider<CloudStorageService?>((ref) async {
  final provider = await ref.watch(cloudProviderInstanceProvider.future);
  return provider?.storage;
});

/// Step 11.3：[AttachmentDownloader]。未配置云服务返回 null —— UI 直接走
/// `meta.localPath` 渲染或破图占位，不发起下载。
///
/// keepAlive 不需要 explicit `keepAlive: true`：[FutureProvider] 默认就是
/// keepAlive；本 provider 在云配置切换时由上游
/// [cloudProviderInstanceProvider] 重建，自然失效，旧实例 [AttachmentDownloader]
/// 内部的 in-memory cache 也一并丢弃。
final attachmentDownloaderProvider =
    FutureProvider<AttachmentDownloader?>((ref) async {
  final storage = await ref.watch(attachmentStorageServiceProvider.future);
  if (storage == null) return null;
  final root = await ref.watch(attachmentCacheRootProvider.future);
  final db = ref.watch(local.appDatabaseProvider);
  return AttachmentDownloader(
    storage: storage,
    cacheRoot: root,
    writeback: ({required txId, required sha256, required localPath}) =>
        defaultAttachmentLocalPathWriteback(
      db,
      txId: txId,
      sha256: sha256,
      localPath: localPath,
    ),
  );
});

/// Step 11.3：[AttachmentCachePruner]。即便没有云服务也能创建——本地缓存
/// 来自老版本下载或将来配置后填充，"清除缓存"始终是合理操作。
final attachmentCachePrunerProvider =
    FutureProvider<AttachmentCachePruner>((ref) async {
  final root = await ref.watch(attachmentCacheRootProvider.future);
  return AttachmentCachePruner(cacheRoot: root);
});

/// Step 11.4：[AttachmentOrphanSweeper] —— 远端孤儿对象 sweeper。
///
/// 未配置云服务时返回 null —— sweep 是云端专属操作。auth 解析的 uid 走
/// `currentUser?.id ?? deviceId`，与 `SnapshotSyncService._path()` 同语义，
/// 保证 list 出来的 prefix 与 upload 时的 prefix 一致。
///
/// 上游 `cloudProviderInstanceProvider` 在 cloud config 切换时重建 →
/// 本 provider 也重建 → 旧 sweeper 实例被丢弃；新 sweeper 用新 backend 的
/// storage，列出新 backend 上的对象集合，行为正确。
final attachmentOrphanSweeperProvider =
    FutureProvider<AttachmentOrphanSweeper?>((ref) async {
  final storage = await ref.watch(attachmentStorageServiceProvider.future);
  if (storage == null) return null;
  final auth = await ref.watch(authServiceProvider.future);
  final user = await auth.currentUser;
  final deviceId = await ref.watch(local.deviceIdProvider.future);
  final uid = user?.id ?? deviceId;
  final db = ref.watch(local.appDatabaseProvider);
  return AttachmentOrphanSweeper(db: db, storage: storage, uid: uid);
});
