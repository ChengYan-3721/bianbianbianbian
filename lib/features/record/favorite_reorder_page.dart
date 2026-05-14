import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../core/util/category_icon_packs.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/category.dart';
import '../settings/settings_providers.dart';
import 'record_providers.dart';

/// 收藏排序页（跳转逻辑.md 中的 R）。
///
/// 入口：[CategoryManagePage] 在 `parentKey == null` 模式下右上角「排序」按钮。
/// 数据来源：`CategoryRepository.listFavorites()`（跨一级分类的所有收藏）。
/// 交互：拖动右侧把手（≡）调整顺序，右上角「保存」回写 `sortOrder`。
///
/// **取舍**：当前 schema 没有独立的"收藏排序"字段，复用 `sortOrder`
/// （它同时承担"该 parentKey 下分类排序"职责）。后续若发现两种排序需求冲突，
/// 再加一个 `favorite_sort_order` 列。
class FavoriteReorderPage extends ConsumerStatefulWidget {
  const FavoriteReorderPage({super.key});

  @override
  ConsumerState<FavoriteReorderPage> createState() => _FavoriteReorderPageState();
}

class _FavoriteReorderPageState extends ConsumerState<FavoriteReorderPage> {
  List<Category>? _items;
  bool _saving = false;
  late Future<List<Category>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<List<Category>> _load() async {
    final repo = await ref.read(categoryRepositoryProvider.future);
    final list = await repo.listFavorites();
    final sorted = [...list]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.categoryFavoriteReorderTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.l10n.save),
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
            return Center(child: Text(context.l10n.loadFailedWithError(snapshot.error.toString())));
          }
          _items ??= [...?snapshot.data];
          final items = _items!;
          if (items.isEmpty) {
            return Center(child: Text(context.l10n.categoryNoFavorite));
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
              final iconPack = ref.watch(currentIconPackProvider);
              final icon = resolveCategoryIcon(
                  c.icon, c.parentKey, c.name, iconPack);
              return ListTile(
                key: ValueKey(c.id),
                leading: Text(icon, style: const TextStyle(fontSize: 20)),
                title: Text(c.name),
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
      for (var i = 0; i < _items!.length; i++) {
        final c = _items![i];
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
        SnackBar(content: Text(context.l10n.saveFailedWithError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
