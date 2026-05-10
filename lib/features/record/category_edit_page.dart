import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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

  String get _parentLabel {
    final key = _isEditing ? widget.initialCategory!.parentKey : widget.parentKey!;
    for (final (label, k) in CategoryManagePage.parentTabs) {
      if (k == key) return label;
    }
    return '分类';
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
          child: const Text('取消'),
        ),
        leadingWidth: 64,
        title: Text(_isEditing ? '编辑分类' : '添加分类'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
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
                  labelText: '名称',
                  hintText: '设置分类名称（一级：$_parentLabel）',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入分类名称';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _iconController,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: '图标 Emoji（可选）',
                  hintText: '例如 🍔、🚗、🎁',
                  border: OutlineInputBorder(),
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
          const SnackBar(content: Text('该一级分类下已存在同名分类')),
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
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}