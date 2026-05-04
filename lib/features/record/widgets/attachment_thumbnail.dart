import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entity/attachment_meta.dart';
import '../../sync/attachment/attachment_downloader.dart';
import '../../sync/attachment/attachment_providers.dart';

/// Step 11.3：附件缩略图统一组件。
///
/// 接受 [AttachmentMeta] + 所属 [txId]，内部用 [AttachmentDownloader.ensureLocal]
/// 解析本地路径并渲染。三态：
/// - **loading**：骨架屏（浅灰矩形 + 微弱菊花）；
/// - **null**：本地缺失 + 远端无配置/失败 → 浅灰矩形 + 📎 + "未同步"提示；
/// - **success**：[Image.file]。
///
/// 命中本地时同步返回 File（不抖闪 loading），未命中时走 Future。
///
/// **prefetch 模式**：流水列表 prefetch 也可以用 [prefetchAttachment] 顶层
/// 函数（fire-and-forget），同样落到 [AttachmentDownloader]，触达 in-memory
/// cache 让后续 widget build 立即拿到结果。
class AttachmentThumbnail extends ConsumerStatefulWidget {
  const AttachmentThumbnail({
    super.key,
    required this.meta,
    required this.txId,
    this.size = 84,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.onTap,
    this.onLongPress,
  });

  /// 附件元数据。`localPath` 为非 null 且文件存在 → 同步走 [Image.file]；
  /// 否则按 `remoteKey` 触发懒下载。
  final AttachmentMeta meta;

  /// 所属流水 id —— 缓存路径 `<cache>/attachments/<txId>/<sha256><ext>` 需要。
  final String txId;

  /// 缩略图正方形边长。默认 84，与 [RecordDetailSheet] 内的横滑列表对齐。
  final double size;

  /// 圆角半径。默认 8。
  final double borderRadius;

  /// 图像填充模式。默认 [BoxFit.cover]。
  final BoxFit fit;

  /// 点击回调（用户视角的"打开大图"等）。null 时仅渲染图像，不响应点击。
  final VoidCallback? onTap;

  /// 长按回调（备注弹层删除附件等）。可空。
  final VoidCallback? onLongPress;

  @override
  ConsumerState<AttachmentThumbnail> createState() =>
      _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends ConsumerState<AttachmentThumbnail> {
  /// 当前正在解析的 [AttachmentDownloader.ensureLocal] future。仅在 (downloader,
  /// meta, txId) 真的变化时才重新发起，避免每次 rebuild 都重新下载。
  Future<File?>? _resolveFuture;
  AttachmentDownloader? _lastDownloader;
  AttachmentMeta? _lastMeta;
  String? _lastTxId;

  @override
  Widget build(BuildContext context) {
    final downloaderAsync = ref.watch(attachmentDownloaderProvider);

    // 同步快路径：localPath 已就绪——不依赖 downloader provider 状态，也不
    // 触发任何 future。loading 不会闪现。
    final lp = widget.meta.localPath;
    if (lp != null && File(lp).existsSync()) {
      return _wrapInteractive(_renderSuccess(File(lp)));
    }

    // 没 remoteKey 也没本地 → 直接 missing，不必等 provider。
    if (widget.meta.remoteKey == null) {
      return _wrapInteractive(_renderMissing());
    }

    // Provider 还在 loading（async override 期 / 启动初期）→ 骨架屏。
    if (downloaderAsync.isLoading) {
      return _wrapInteractive(_renderLoading());
    }

    final downloader = downloaderAsync.valueOrNull;
    // 配置无云服务 / 初始化失败 → 当前没有 downloader 可用，渲染 missing。
    if (downloader == null) {
      return _wrapInteractive(_renderMissing());
    }

    // (downloader, meta, txId) 任一变化都要重新触发 ensureLocal —— 否则缓存
    // 旧 future 让 UI 显示陈旧结果。downloader 切换是 cloud config 切换的
    // 标志，必须重拉。
    if (_lastDownloader != downloader ||
        _lastMeta != widget.meta ||
        _lastTxId != widget.txId ||
        _resolveFuture == null) {
      _lastDownloader = downloader;
      _lastMeta = widget.meta;
      _lastTxId = widget.txId;
      _resolveFuture = downloader.ensureLocal(widget.meta, txId: widget.txId);
    }

    return _wrapInteractive(
      FutureBuilder<File?>(
        future: _resolveFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _renderLoading();
          }
          final file = snapshot.data;
          if (file == null) return _renderMissing();
          return _renderSuccess(file);
        },
      ),
    );
  }

  Widget _wrapInteractive(Widget child) {
    if (widget.onTap == null && widget.onLongPress == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: child,
    );
  }

  Widget _renderLoading() => _AttachmentSkeleton(
        size: widget.size,
        borderRadius: widget.borderRadius,
      );

  Widget _renderMissing() => _AttachmentMissingTile(
        size: widget.size,
        borderRadius: widget.borderRadius,
      );

  Widget _renderSuccess(File file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.file(
        file,
        width: widget.size,
        height: widget.size,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _renderMissing(),
      ),
    );
  }
}

/// 骨架屏：浅灰矩形 + 微弱 CircularProgressIndicator。下载中也好，刚 mount
/// 也好，统一都靠这个组件占位。
class _AttachmentSkeleton extends StatelessWidget {
  const _AttachmentSkeleton({
    required this.size,
    required this.borderRadius,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('attachment_thumbnail_loading'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(colors.primary.withAlpha(120)),
        ),
      ),
    );
  }
}

/// 占位：未同步 / 远端 404 / 网络失败统一展示——浅灰底 + 📎 + "未同步"。
///
/// 故意不暴露详细错误（用户不关心是 404 还是 timeout）；下次列表滚动到这条
/// 流水时 [AttachmentThumbnail] 重新触发下载，错误自愈。
class _AttachmentMissingTile extends StatelessWidget {
  const _AttachmentMissingTile({
    required this.size,
    required this.borderRadius,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('attachment_thumbnail_missing'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attachment_outlined, size: 22),
          const SizedBox(height: 2),
          Text(
            '未同步',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withAlpha(140),
                ),
          ),
        ],
      ),
    );
  }
}

/// 顶层 helper：流水列表滚动 fire-and-forget 触发 prefetch。
///
/// - 命中本地缓存 → 立即返回，不打 storage；
/// - 远端有 → 排队（[AttachmentDownloader] 内部限并发 3）；
/// - 网络失败 → 静默吞掉，下次滚动到时再触发。
///
/// **不**等待结果，调用方 fire-and-forget 即可。失败不抛——`ensureLocal`
/// 自身已经是两态契约。
Future<void> prefetchAttachment(
  WidgetRef ref, {
  required AttachmentMeta meta,
  required String txId,
}) async {
  final downloaderAsync = ref.read(attachmentDownloaderProvider);
  final downloader = downloaderAsync.valueOrNull;
  if (downloader == null) return;
  if (meta.remoteKey == null) return; // nothing to prefetch
  // ensureLocal 内部已含命中本地缓存的快路径——重复触发同 (txId, sha256) 也
  // 会复用 inflight future，不会真的并发请求。
  await downloader.ensureLocal(meta, txId: txId);
}
