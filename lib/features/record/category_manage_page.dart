import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/category.dart';

/// 分类管理页：
/// - 按固定一级分类分组展示二级分类
/// - 每个二级分类右侧提供 ☆ 收藏开关
/// - 预留基础管理入口（新增/编辑/删除）
class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({
    super.key,
    this.parentKey,
  });

  final String? parentKey;

  static const List<(String label, String key)> parentTabs = [
    ('收入', 'income'),
    ('饮食', 'food'),
    ('购物', 'shopping'),
    ('出行', 'transport'),
    ('教育', 'education'),
    ('娱乐', 'entertainment'),
    ('人情', 'social'),
    ('住房', 'housing'),
    ('医药', 'medical'),
    ('投资', 'investment'),
    ('其他', 'other'),
  ];

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  List<Category>? _categories;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(categoryRepositoryProvider).valueOrNull;
    if (repo == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.parentKey == null ? '分类管理' : parentLabelByKey(widget.parentKey!),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.parentKey == null ? '收藏排序功能待接入' : '编辑排序删除功能待接入'),
                ),
              );
            },
            child: Text(widget.parentKey == null ? '排序' : '编辑'),
          ),
        ],
      ),
      body: FutureBuilder<List<Category>>(
        future: _categories == null
            ? (widget.parentKey == null
                ? repo.listActiveAll()
                : repo.listActiveByParentKey(widget.parentKey!))
            : null,
        builder: (context, snapshot) {
          if (_categories == null && snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          _categories ??= snapshot.data ?? const <Category>[];
          final all = _categories!;

          final grouped = <String, List<Category>>{
            for (final (_, key) in CategoryManagePage.parentTabs) key: <Category>[],
          };
          for (final c in all) {
            final list = grouped[c.parentKey];
            if (list != null) list.add(c);
          }
          for (final entry in grouped.entries) {
            entry.value.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          }

          Future<void> onToggleFavorite(String id, bool toValue) async {
            await repo.toggleFavorite(id, toValue);
            if (!mounted) return;
            setState(() {
              _categories = all
                  .map((c) => c.id == id ? c.copyWith(isFavorite: toValue) : c)
                  .toList(growable: false);
            });
          }

          if (widget.parentKey == null) {
            return _GlobalCategoryManageLayout(
              grouped: grouped,
              onToggleFavorite: onToggleFavorite,
            );
          }

          return ListView(
            children: [
              _ParentSection(
                parentLabel: '',
                parentKey: widget.parentKey!,
                showHeaderAction: false,
                categories: grouped[widget.parentKey!] ?? const <Category>[],
                onToggleFavorite: onToggleFavorite,
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
      floatingActionButton: null,
    );
  }

  String parentLabelByKey(String parentKey) {
    for (final (label, key) in CategoryManagePage.parentTabs) {
      if (key == parentKey) return label;
    }
    return '分类';
  }
}

class _GlobalCategoryManageLayout extends StatefulWidget {
  const _GlobalCategoryManageLayout({
    required this.grouped,
    required this.onToggleFavorite,
  });

  final Map<String, List<Category>> grouped;
  final Future<void> Function(String id, bool toValue) onToggleFavorite;

  @override
  State<_GlobalCategoryManageLayout> createState() => _GlobalCategoryManageLayoutState();
}

class _GlobalCategoryManageLayoutState extends State<_GlobalCategoryManageLayout> {
  String _selectedParentKey = CategoryManagePage.parentTabs.first.$2;

  @override
  Widget build(BuildContext context) {
    final tabs = CategoryManagePage.parentTabs;
    final categories = widget.grouped[_selectedParentKey] ?? const <Category>[];
    final parentLabel = tabs
            .where((e) => e.$2 == _selectedParentKey)
            .map((e) => e.$1)
            .firstOrNull ??
        '分类';

    return Row(
      children: [
        Container(
          width: 92,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: ListView.builder(
            itemCount: tabs.length,
            itemBuilder: (context, index) {
              final (label, key) = tabs[index];
              final selected = key == _selectedParentKey;
              return InkWell(
                onTap: () => setState(() => _selectedParentKey = key),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  color: selected ? Theme.of(context).colorScheme.primary : null,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            children: [
              _ParentSection(
                parentLabel: parentLabel,
                parentKey: _selectedParentKey,
                showHeaderAction: true,
                categories: categories,
                onHeaderTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('添加分类功能将在后续步骤接入')),
                  );
                },
                onToggleFavorite: widget.onToggleFavorite,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParentSection extends StatelessWidget {
  const _ParentSection({
    required this.parentLabel,
    required this.parentKey,
    required this.categories,
    required this.onToggleFavorite,
    this.showHeaderAction = false,
    this.onHeaderTap,
  });

  final Future<void> Function(String id, bool toValue) onToggleFavorite;

  final String parentLabel;
  final String parentKey;
  final bool showHeaderAction;
  final VoidCallback? onHeaderTap;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parentLabel.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    parentLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (showHeaderAction)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: onHeaderTap,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  _CategoryRow(
                    category: categories[i],
                    onToggleFavorite: onToggleFavorite,
                  ),
                  if (i != categories.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onToggleFavorite,
  });

  final Category category;
  final Future<void> Function(String id, bool toValue) onToggleFavorite;

  @override
  Widget build(BuildContext context) {

    return ListTile(
      leading: Text(category.icon ?? '📁', style: const TextStyle(fontSize: 20)),
      title: Text(category.name),
      trailing: IconButton(
        tooltip: category.isFavorite ? '取消收藏' : '收藏',
        icon: Icon(
          category.isFavorite ? Icons.star : Icons.star_border,
          color: category.isFavorite
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        onPressed: () => onToggleFavorite(category.id, !category.isFavorite),
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('编辑分类功能将在后续步骤接入')),
        );
      },
      onLongPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除分类功能将在后续步骤接入')),
        );
      },
    );
  }
}