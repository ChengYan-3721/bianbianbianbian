import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/attachment/attachment_cache_pruner.dart';
import '../sync/attachment/attachment_providers.dart';

/// Step 11.3：「我的 → 附件缓存」设置页。
///
/// 展示当前 `<cache>/attachments/` 占用 + 限额 [kAttachmentCacheLimitBytes]
/// + "清除缓存"按钮。清除只动 cache 目录，不影响 documents（用户原图）与
/// 远端对象。
class AttachmentCachePage extends ConsumerStatefulWidget {
  const AttachmentCachePage({super.key});

  @override
  ConsumerState<AttachmentCachePage> createState() =>
      _AttachmentCachePageState();
}

class _AttachmentCachePageState extends ConsumerState<AttachmentCachePage> {
  Future<int>? _sizeFuture;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  void _refreshSize() {
    setState(() {
      _sizeFuture = _loadSize();
    });
  }

  Future<int> _loadSize() async {
    final pruner = await ref.read(attachmentCachePrunerProvider.future);
    return pruner.currentSize();
  }

  Future<void> _confirmAndClear() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('清除附件缓存？'),
            content: const Text(
              '只删除本地缓存文件，不影响您原始保存的图片与云端备份。下次查看流水时会重新从云端下载。',
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('清除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    if (!mounted) return;
    setState(() => _clearing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pruner = await ref.read(attachmentCachePrunerProvider.future);
      final removed = await pruner.clear();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已清除约 ${_formatBytes(removed)}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('清除失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
        _refreshSize();
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('附件缓存')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('当前占用'),
            subtitle: FutureBuilder<int>(
              future: _sizeFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Text('计算中…');
                }
                return Text(
                  '${_formatBytes(snap.data!)} / ${_formatBytes(kAttachmentCacheLimitBytes)} 上限',
                );
              },
            ),
            trailing: IconButton(
              tooltip: '刷新',
              onPressed: _refreshSize,
              icon: const Icon(Icons.refresh),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined, color: colors.error),
            title: Text(
              '清除缓存',
              style: TextStyle(color: colors.error),
            ),
            subtitle: const Text(
              '删除本地缓存的附件文件，不影响原图与云端备份',
            ),
            onTap: _clearing ? null : _confirmAndClear,
            trailing: _clearing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '附件懒加载：仅当查看流水详情时才从云端下载图片，节省流量。'
              '系统在空间紧张时会自动清理缓存目录，下次查看会重新下载。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withAlpha(160),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
