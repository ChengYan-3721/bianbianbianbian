import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/category.dart';
import 'category_manage_page.dart';
import 'record_providers.dart';

/// 分类新建/编辑页。
///
/// 当传入 [initialCategory] 时为编辑模式，否则为新建模式（必须提供 [parentKey]）。
/// 表单字段：
/// - 名称（必填，trim 后不为空）
/// - 图标 emoji（可选）
///
/// 新建模式：取 parentKey 下最大 sortOrder + 1。
/// 编辑模式：保持 id、parentKey、sortOrder、isFavorite 等字段不变，仅更新 name/icon。
class CategoryEditPage extends ConsumerStatefulWidget {
  const CategoryEditPage({
    super.key,
    this.parentKey,
    this.initialCategory,
  }) : assert(
          (parentKey != null) ^ (initialCategory != null),
          // i18n-exempt: assertion message (developer-facing, not UI)
          '新建模式需要 parentKey，编辑模式需要 initialCategory',
        );

  final String? parentKey;
  final Category? initialCategory;

  @override
  ConsumerState<CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends ConsumerState<CategoryEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _iconController;
  bool _saving = false;

  bool get _isEditing => widget.initialCategory != null;

  String _parentLabel(BuildContext context) {
    final key = _isEditing ? widget.initialCategory!.parentKey : widget.parentKey!;
    return CategoryManagePage.parentLabelFor(context, key);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _isEditing ? widget.initialCategory!.name : '',
    );
    _iconController = TextEditingController(
      text: _isEditing ? (widget.initialCategory!.icon ?? '') : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        leadingWidth: 64,
        title: Text(_isEditing ? context.l10n.categoryEditTitle : context.l10n.categoryAddTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.l10n.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: context.l10n.categoryName,
                  hintText: context.l10n.categoryNameHint(_parentLabel(context)),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return context.l10n.categoryNameRequired;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _iconController,
                maxLength: 2,
                decoration: InputDecoration(
                  labelText: context.l10n.categoryIconEmoji,
                  hintText: context.l10n.categoryIconEmojiHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final repo = await ref.read(categoryRepositoryProvider.future);
      final iconText = _iconController.text.trim();
      final newName = _nameController.text.trim();
      final parentKey =
          _isEditing ? widget.initialCategory!.parentKey : widget.parentKey!;

      // 同级重名检查
      final siblings = await repo.listActiveByParentKey(parentKey);
      final duplicate = siblings.any(
        (c) =>
            c.name == newName &&
            (_isEditing ? c.id != widget.initialCategory!.id : true),
      );
      if (duplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.categoryDuplicateName)),
        );
        setState(() => _saving = false);
        return;
      }

      if (_isEditing) {
        final updated = widget.initialCategory!.copyWith(
          name: newName,
          icon: iconText.isEmpty ? null : iconText,
          updatedAt: DateTime.now(),
        );
        await repo.save(updated);
      } else {
        final maxSort = siblings.fold<int>(
          0,
          (acc, c) => c.sortOrder > acc ? c.sortOrder : acc,
        );
        final entity = Category(
          id: const Uuid().v4(),
          name: newName,
          icon: iconText.isEmpty ? null : iconText,
          parentKey: parentKey,
          sortOrder: maxSort + 1,
          isFavorite: false,
          updatedAt: DateTime.now(),
          deviceId: '',
        );
        await repo.save(entity);
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