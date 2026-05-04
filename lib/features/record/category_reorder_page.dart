import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/category.dart';
import 'category_manage_page.dart';
import 'record_providers.dart';

/// 二级分类编辑/删除/拖动排序页（跳转逻辑.md 中的 Q）。
///
/// 入口：[CategoryManagePage] 在 `parentKey != null` 模式下右上角「编辑」按钮。
/// 交互：
/// - 拖动右侧把手（≡）调整顺序
/// - 点击左侧 🗑 标记删除（再次点击恢复，仅保存时才真正软删）
/// - 右上角「保存」一并提交：先 softDelete 已删行，再按当前顺序回写
///   `sortOrder`（仅写动过的行，减少 sync_op 噪音）
class CategoryReorderPage extends ConsumerStatefulWidget {
  const CategoryReorderPage({super.key, required this.parentKey});

  final String parentKey;

  @override
  ConsumerState<CategoryReorderPage> createState() => _CategoryReorderPageState();
}

class _CategoryReorderPageState extends ConsumerState<CategoryReorderPage> {
  List<Category>? _items;
  final Set<String> _pendingDelete = <String>{};
  bool _saving = false;
  late Future<List<Category>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<List<Category>> _load() async {
    final repo = await ref.read(categoryRepositoryProvider.future);
    final list = await repo.listActiveByParentKey(widget.parentKey);
    final sorted = [...list]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  String get _parentLabel {
    for (final (label, key) in CategoryManagePage.parentTabs) {
      if (key == widget.parentKey) return label;
    }
    return '分类';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_parentLabel),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: FutureBuilder<List<Category>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }
          _items ??= [...?snapshot.data];
          final items = _items!;
          if (items.isEmpty) {
            return const Center(child: Text('暂无分类'));
          }
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final moved = items.removeAt(oldIndex);
                items.insert(newIndex, moved);
              });
            },
            itemBuilder: (context, index) {
              final c = items[index];
              final marked = _pendingDelete.contains(c.id);
              return ListTile(
                key: ValueKey(c.id),
                leading: IconButton(
                  tooltip: marked ? '取消删除' : '删除',
                  icon: Icon(
                    Icons.delete_outline,
                    color: marked
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: () {
                    setState(() {
                      if (marked) {
                        _pendingDelete.remove(c.id);
                      } else {
                        _pendingDelete.add(c.id);
                      }
                    });
                  },
                ),
                title: Row(
                  children: [
                    Text(c.icon ?? '📁', style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.name,
                        style: TextStyle(
                          decoration: marked ? TextDecoration.lineThrough : null,
                          color: marked
                              ? Theme.of(context).colorScheme.outline
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_items == null || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(categoryRepositoryProvider.future);
      // 先软删
      for (final id in _pendingDelete) {
        await repo.softDeleteById(id);
      }
      // 重写顺序：保留项按当前位置 0..n 顺序写入 sortOrder（只写有变化的）
      final remaining = _items!.where((c) => !_pendingDelete.contains(c.id)).toList();
      for (var i = 0; i < remaining.length; i++) {
        final c = remaining[i];
        if (c.sortOrder != i) {
          await repo.save(c.copyWith(sortOrder: i));
        }
      }
      if (!mounted) return;
      ref.invalidate(categoriesListProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
