import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/ledger.dart';
import 'ledger_providers.dart';

part 'ledger_list_page.g.dart';

/// 账本 Tab 的正式列表页——替换 Step 1.7 的临时预览。
///
/// 展示所有未归档活跃账本卡片（封面 emoji + 名称 + 流水总数），点击切换
/// 当前账本；归档的账本折叠到"已归档"区域。
/// FAB 新建账本；长按卡片弹出菜单（编辑/归档/删除）。
class LedgerListPage extends ConsumerWidget {
  const LedgerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(ledgerRepositoryProvider);
    final currentId = ref.watch(currentLedgerIdProvider).valueOrNull;
    final txCounts = ref.watch(ledgerTxCountsProvider).valueOrNull ?? const {};

    return Scaffold(
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (_) => _LedgerListContent(
          currentId: currentId,
          txCounts: txCounts,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ledger_list_fab',
        onPressed: () => _onNewLedger(context),
        icon: const Icon(Icons.add),
        label: const Text('新建账本'),
      ),
    );
  }

  void _onNewLedger(BuildContext context) {
    context.push('/ledger/edit');
  }
}

class _LedgerListContent extends ConsumerWidget {
  const _LedgerListContent({
    required this.currentId,
    required this.txCounts,
  });

  final String? currentId;
  final Map<String, int> txCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(ledgerGroupsProvider);
    final theme = Theme.of(context);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (data) {
        final active = data.active;
        final archived = data.archived;

        if (active.isEmpty && archived.isEmpty) {
          return const Center(child: Text('还没有账本，去创建一个吧 🐰'));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: [
            ...active.map((l) => _LedgerCard(
                  ledger: l,
                  isCurrent: l.id == currentId,
                  txCount: txCounts[l.id] ?? 0,
                  onTap: () => _onSwitch(ref, l),
                  onLongPress: () => _showLedgerMenu(context, ref, l),
                )),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '已归档',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(128),
                ),
              ),
              const SizedBox(height: 8),
              ...archived.map((l) => _LedgerCard(
                    ledger: l,
                    isCurrent: false,
                    txCount: txCounts[l.id] ?? 0,
                    dimmed: true,
                    onTap: () {},
                    onLongPress: () => _showArchivedMenu(context, ref, l),
                  )),
            ],
          ],
        );
      },
    );
  }

  void _onSwitch(WidgetRef ref, Ledger ledger) {
    if (ledger.id == currentId) return;
    ref.read(currentLedgerIdProvider.notifier).switchTo(ledger.id);
    ref.invalidate(ledgerTxCountsProvider);
  }

  void _showLedgerMenu(BuildContext context, WidgetRef ref, Ledger ledger) {
    final isCurrent = ledger.id == currentId;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/ledger/edit?id=${ledger.id}');
              },
            ),
            ListTile(
              leading: Icon(ledger.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined),
              title: Text(ledger.archived ? '取消归档' : '归档'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleArchive(ref, ledger);
              },
            ),
            if (!isCurrent)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, ref, ledger);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showArchivedMenu(BuildContext context, WidgetRef ref, Ledger ledger) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.unarchive_outlined),
              title: const Text('取消归档'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleArchive(ref, ledger);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, ledger);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleArchive(WidgetRef ref, Ledger ledger) async {
    final repo = await ref.read(ledgerRepositoryProvider.future);
    try {
      await repo.setArchived(ledger.id, !ledger.archived);
      ref.invalidate(ledgerGroupsProvider);
      ref.invalidate(ledgerTxCountsProvider);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Ledger ledger,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除账本「${ledger.name}」吗？\n\n'
            '该账本下的所有流水和预算也将被删除。\n'
            '删除后可在垃圾桶中保留 30 天。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = await ref.read(ledgerRepositoryProvider.future);
    try {
      await repo.softDeleteById(ledger.id);
      ref.invalidate(ledgerGroupsProvider);
      ref.invalidate(ledgerTxCountsProvider);
      // 如果删除的是当前账本，需要重新选择
      if (ledger.id == currentId) {
        ref.invalidate(currentLedgerIdProvider);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${ledger.name}」已删除')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }
}

class LedgerGroups {
  const LedgerGroups({required this.active, required this.archived});
  final List<Ledger> active;
  final List<Ledger> archived;
}

/// 活跃 / 归档账本分组（纯本地查询，不走网络）。
@riverpod
Future<LedgerGroups> ledgerGroups(Ref ref) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  final all = await repo.listActive();
  final active = all.where((l) => !l.archived).toList();
  final archived = all.where((l) => l.archived).toList();
  return LedgerGroups(active: active, archived: archived);
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.ledger,
    required this.isCurrent,
    required this.txCount,
    required this.onTap,
    required this.onLongPress,
    this.dimmed = false,
  });

  final Ledger ledger;
  final bool isCurrent;
  final int txCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isCurrent ? theme.colorScheme.primary : theme.colorScheme.surface;
    final textAlpha = dimmed ? 128 : 255;
    // 当前选中卡片使用白色文字，否则使用主题的 onSurface（棕色）
    final textColor = isCurrent ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardColor.withAlpha(dimmed ? 160 : 255),
        borderRadius: BorderRadius.circular(16),
        elevation: isCurrent ? 2 : 0,
        shadowColor: theme.shadowColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  ledger.coverEmoji ?? '📒',
                  style: TextStyle(
                    fontSize: 36,
                    color: isCurrent ? theme.colorScheme.onPrimary : Color.fromARGB(textAlpha, 0, 0, 0),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ledger.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$txCount 笔流水  ·  ${ledger.defaultCurrency}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColor.withAlpha(dimmed ? 100 : 160),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Icon(
                    Icons.check_circle,
                    size: 22,
                    color: theme.colorScheme.onPrimary,
                  ),
                if (dimmed)
                  Icon(
                    Icons.archive_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}