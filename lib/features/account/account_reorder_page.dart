import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../core/util/svg_or_emoji_icon.dart';
import '../../domain/entity/account.dart';
import 'account_providers.dart';

/// 账户拖动排序页。
///
/// 入口：账户列表页 AppBar 右上角排序图标。
/// 交互：拖动右侧把手（≡）调整顺序，右上角「保存」提交。
class AccountReorderPage extends ConsumerStatefulWidget {
  const AccountReorderPage({super.key});

  @override
  ConsumerState<AccountReorderPage> createState() =>
      _AccountReorderPageState();
}

class _AccountReorderPageState extends ConsumerState<AccountReorderPage> {
  List<Account>? _items;
  bool _saving = false;
  late Future<List<Account>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<List<Account>> _load() async {
    return ref.read(accountsListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accountReorderTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.l10n.save),
          ),
        ],
      ),
      body: FutureBuilder<List<Account>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                context.l10n.loadFailedWithError(snapshot.error.toString()),
              ),
            );
          }
          _items ??= [...?snapshot.data];
          final items = _items!;
          if (items.isEmpty) {
            return Center(child: Text(context.l10n.accountEmptyHint));
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
              final acc = items[index];
              return ListTile(
                key: ValueKey(acc.id),
                leading: SvgOrEmojiIcon(
                  svgString: acc.iconSvg,
                  emoji: acc.icon ?? '💳',
                  size: 24,
                ),
                title: Text(acc.name),
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
      await saveAccountOrder(ref, _items!.map((a) => a.id).toList());
      if (!mounted) return;
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
