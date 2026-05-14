import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../core/util/category_icon_packs.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/category.dart';
import '../settings/settings_providers.dart';

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

  static const List<String> parentKeys = [
    'income',
    'food',
    'shopping',
    'transport',
    'education',
    'entertainment',
    'social',
    'housing',
    'medical',
    'investment',
    'other',
  ];

  /// 一级分类 key → l10n 标签。在 build 时从 context.l10n 取值。
  static String parentLabelFor(BuildContext context, String key) {
    final l = context.l10n;
    return switch (key) {
      'income' => l.parentKeyIncome,
      'food' => l.parentKeyFood,
      'shopping' => l.parentKeyShopping,
      'transport' => l.parentKeyTransport,
      'education' => l.parentKeyEducation,
      'entertainment' => l.parentKeyEntertainment,
      'social' => l.parentKeySocial,
      'housing' => l.parentKeyHousing,
      'medical' => l.parentKeyMedical,
      'investment' => l.parentKeyInvestment,
      _ => l.parentKeyOther,
    };
  }

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  List<Category>? _categories;
  String _selectedParentKey = CategoryManagePage.parentKeys.first;

  Future<void> _openAddCategory(String parentKey) async {
    final saved = await context.push<bool>(
      '/record/categories/edit?parentKey=$parentKey',
    );
    if (saved == true && mounted) {
      setState(() => _categories = null);
    }
  }

  Future<void> _openReorderOrEdit() async {
    final route = widget.parentKey == null
        ? '/record/categories/favorites/reorder'
        : '/record/categories/reorder?parentKey=${widget.parentKey}';
    final changed = await context.push<bool>(route);
    if (changed == true && mounted) {
      setState(() => _categories = null);
    }
  }

  Future<void> _refreshCategories() async {
    final repo = await ref.read(categoryRepositoryProvider.future);
    final fresh = widget.parentKey == null
        ? await repo.listActiveAll()
        : await repo.listActiveByParentKey(widget.parentKey!);
    if (!mounted) return;
    setState(() => _categories = fresh);
  }

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
          widget.parentKey == null ? context.l10n.categoryManageTitle : CategoryManagePage.parentLabelFor(context, widget.parentKey!),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: _openReorderOrEdit,
            child: Text(widget.parentKey == null ? context.l10n.categoryReorderTitle : context.l10n.edit),
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
            for (final key in CategoryManagePage.parentKeys) key: <Category>[],
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
              selectedParentKey: _selectedParentKey,
              onSelectedParentKeyChanged: (key) =>
                  setState(() => _selectedParentKey = key),
              grouped: grouped,
              onToggleFavorite: onToggleFavorite,
              onAddCategory: _openAddCategory,
              onEditCategory: _refreshCategories,
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
                onEditCategory: _refreshCategories,
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
      bottomNavigationBar: widget.parentKey == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => _openAddCategory(widget.parentKey!),
                    child: Text(context.l10n.categoryAddNew),
                  ),
                ),
              ),
            ),
      floatingActionButton: null,
    );
  }

}

class _GlobalCategoryManageLayout extends StatelessWidget {
  const _GlobalCategoryManageLayout({
    required this.grouped,
    required this.onToggleFavorite,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.selectedParentKey,
    required this.onSelectedParentKeyChanged,
  });

  final Map<String, List<Category>> grouped;
  final String selectedParentKey;
  final ValueChanged<String> onSelectedParentKeyChanged;
  final Future<void> Function(String id, bool toValue) onToggleFavorite;
  final Future<void> Function(String parentKey) onAddCategory;
  final Future<void> Function() onEditCategory;

  @override
  Widget build(BuildContext context) {
    final tabs = CategoryManagePage.parentKeys;
    final categories = grouped[selectedParentKey] ?? const <Category>[];
    final parentLabel = CategoryManagePage.parentLabelFor(context, selectedParentKey);

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
              final key = tabs[index];
              final label = CategoryManagePage.parentLabelFor(context, key);
              final selected = key == selectedParentKey;
              return InkWell(
                onTap: () => onSelectedParentKeyChanged(key),
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
                parentKey: selectedParentKey,
                showHeaderAction: true,
                categories: categories,
                onHeaderTap: () => onAddCategory(selectedParentKey),
                onToggleFavorite: onToggleFavorite,
                onEditCategory: onEditCategory,
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
    this.onEditCategory,
  });

  final Future<void> Function(String id, bool toValue) onToggleFavorite;

  final String parentLabel;
  final String parentKey;
  final bool showHeaderAction;
  final VoidCallback? onHeaderTap;
  final List<Category> categories;
  final Future<void> Function()? onEditCategory;

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
                    label: Text(context.l10n.add),
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
                    onEdit: onEditCategory,
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

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.category,
    required this.onToggleFavorite,
    this.onEdit,
  });

  final Category category;
  final Future<void> Function(String id, bool toValue) onToggleFavorite;
  final Future<void> Function()? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconPack = ref.watch(currentIconPackProvider);
    final icon = resolveCategoryIcon(
        category.icon, category.parentKey, category.name, iconPack);
    return ListTile(
      leading: Text(icon, style: const TextStyle(fontSize: 20)),
      title: Text(category.name),
      trailing: IconButton(
        tooltip: category.isFavorite ? context.l10n.categoryUncollect : context.l10n.categoryCollect,
        icon: Icon(
          category.isFavorite ? Icons.star : Icons.star_border,
          color: category.isFavorite
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        onPressed: () => onToggleFavorite(category.id, !category.isFavorite),
      ),
      onTap: () async {
        final saved = await context.push<bool>(
          '/record/categories/edit',
          extra: category,
        );
        if (saved == true) {
          await onEdit?.call();
        }
      },
    );
  }
}