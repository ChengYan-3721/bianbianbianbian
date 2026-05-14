import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n_ext.dart';

import '../../core/util/category_icon_packs.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/ledger.dart';
import '../../domain/entity/transaction_entry.dart';
import '../account/account_providers.dart';
import '../budget/budget_providers.dart' show activeBudgetsProvider;
import '../record/category_manage_page.dart' show CategoryManagePage;
import '../ledger/ledger_list_page.dart' show ledgerGroupsProvider;
import '../ledger/ledger_providers.dart';
import '../record/record_providers.dart';
import '../settings/settings_providers.dart';
import '../stats/stats_range_providers.dart';
import '../sync/sync_trigger.dart';
import 'trash_attachment_cleaner.dart';
import 'trash_providers.dart';

/// Phase 12 Step 12.1 / 12.2 垃圾桶页面。
///
/// 四个 Tab：流水 / 分类 / 账户 / 账本。每行展示软删项 + 剩余天数 + 恢复 / 永久删除
/// 按钮；AppBar 右侧一个"一键清空"按钮（按当前 Tab 类型清空）。
///
/// **不暴露预算 Tab**：预算几乎总是因账本级联删除而进垃圾桶，单独列出会让用户
/// 困惑——账本恢复时会一起回来，不需要在 UI 单独操作。
class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage>
    with SingleTickerProviderStateMixin {
  // Labels resolved at build time via l10n; stored as keys for late resolution.
  static const List<_TrashTab> _tabs = [
    _TrashTab(labelKey: 'records', icon: Icons.receipt_long_outlined),
    _TrashTab(labelKey: 'categories', icon: Icons.category_outlined),
    _TrashTab(labelKey: 'accounts', icon: Icons.account_balance_wallet_outlined),
    _TrashTab(labelKey: 'ledgers', icon: Icons.menu_book_outlined),
  ];

  late final TabController _tabCtrl =
      TabController(length: _tabs.length, vsync: this);

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.trashTitle),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            for (final t in _tabs) Tab(text: t.labelFor(context), icon: Icon(t.icon)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.trashClearCurrent,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmPurgeAll(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _TrashTransactionsTab(),
          _TrashCategoriesTab(),
          _TrashAccountsTab(),
          _TrashLedgersTab(),
        ],
      ),
    );
  }

  Future<void> _confirmPurgeAll(BuildContext outerContext) async {
    final tabIndex = _tabCtrl.index;
    final label = _tabs[tabIndex].labelFor(outerContext);
    final confirmed = await showDialog<bool>(
      context: outerContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.trashConfirmClear),
        content: Text(context.l10n.trashClearConfirmMsg(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.trashPermanentDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      switch (tabIndex) {
        case 0:
          await _purgeAllTransactions(ref);
          break;
        case 1:
          await _purgeAllCategories(ref);
          break;
        case 2:
          await _purgeAllAccounts(ref);
          break;
        case 3:
          await _purgeAllLedgers(ref);
          break;
      }
      invalidateTrashFromWidgetRef(ref);
      _refreshDownstream();
      ref.read(syncTriggerProvider.notifier).scheduleDebounced();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trashCleared(label))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trashClearFailed(e.toString()))),
        );
      }
    }
  }

  /// 永久删除流水 Tab——附件清理先于硬删。
  Future<void> _purgeAllTransactions(WidgetRef ref) async {
    final repo = await ref.read(transactionRepositoryProvider.future);
    final cleaner = ref.read(trashAttachmentCleanerProvider);
    final deleted = await repo.listDeleted();
    await cleaner.deleteForTransactions(deleted.map((t) => t.id));
    await repo.purgeAllDeleted();
  }

  Future<void> _purgeAllCategories(WidgetRef ref) async {
    final repo = await ref.read(categoryRepositoryProvider.future);
    await repo.purgeAllDeleted();
  }

  Future<void> _purgeAllAccounts(WidgetRef ref) async {
    final repo = await ref.read(accountRepositoryProvider.future);
    await repo.purgeAllDeleted();
  }

  /// 账本一键清空——逐个走 [LedgerRepository.purgeById]，让级联硬删生效。
  /// 顺便清属于这些账本的流水附件。
  Future<void> _purgeAllLedgers(WidgetRef ref) async {
    final ledgerRepo = await ref.read(ledgerRepositoryProvider.future);
    final txRepo = await ref.read(transactionRepositoryProvider.future);
    final cleaner = ref.read(trashAttachmentCleanerProvider);
    final deleted = await ledgerRepo.listDeleted();
    // 收集这些账本下所有（含活跃 + 软删）流水的 id 用于附件清理。
    final allTx = <String>{};
    for (final l in deleted) {
      final ids = (await txRepo.listActiveByLedger(l.id))
          .map((t) => t.id)
          .toList();
      allTx.addAll(ids);
    }
    // 软删的流水也要清附件——listDeleted 全账本统一查。
    final deletedTx = await txRepo.listDeleted();
    for (final tx in deletedTx) {
      // 不能区分 tx 属于哪个 ledger（实体不暴露 ledgerId 给 cleaner）——但 cleaner
      // 是按 txId 删目录的，可以直接全删；GC 路径同样这样处理。
      allTx.add(tx.id);
    }
    if (allTx.isNotEmpty) {
      await cleaner.deleteForTransactions(allTx);
    }
    for (final l in deleted) {
      await ledgerRepo.purgeById(l.id);
    }
  }

  void _refreshDownstream() {
    // 列表 / 统计 / 账本 Tab / 账本计数 / 预算 / 账户余额——全员刷新。
    ref.invalidate(recordMonthSummaryProvider);
    ref.invalidate(ledgerGroupsProvider);
    ref.invalidate(ledgerTxCountsProvider);
    ref.invalidate(activeBudgetsProvider);
    ref.invalidate(accountsListProvider);
    ref.invalidate(accountBalancesProvider);
    ref.invalidate(totalAssetsProvider);
    ref.invalidate(statsLinePointsProvider);
    ref.invalidate(statsPieSlicesProvider);
    ref.invalidate(statsRankItemsProvider);
    ref.invalidate(statsHeatmapCellsProvider);
  }
}

class _TrashTab {
  const _TrashTab({required this.labelKey, required this.icon});
  final String labelKey;
  final IconData icon;

  String labelFor(BuildContext context) {
    final l10n = context.l10n;
    return switch (labelKey) {
      'records' => l10n.trashTabRecords,
      'categories' => l10n.trashTabCategories,
      'accounts' => l10n.trashTabAccounts,
      'ledgers' => l10n.trashTabLedgers,
      _ => labelKey,
    };
  }
}

/// ----------------- 流水 Tab -----------------

class _TrashTransactionsTab extends ConsumerWidget {
  const _TrashTransactionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(trashedTransactionsProvider);
    return asyncList.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
      data: (items) {
        final visible = items
            .where((t) => t.deletedAt != null)
            .where((t) =>
                trashDaysLeft(deletedAt: t.deletedAt!, now: DateTime.now()) > 0)
            .toList();
        if (visible.isEmpty) {
          return _TrashEmptyState(label: context.l10n.trashNoDeletedRecords);
        }
        return ListView.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final tx = visible[i];
            return _TrashRow(
              icon: _txIcon(tx),
              title: _txTitle(tx),
              subtitle: _txSubtitle(context, tx),
              deletedAt: tx.deletedAt!,
              onRestore: () => _restoreTx(context, ref, tx),
              onPurge: () => _purgeTx(context, ref, tx),
            );
          },
        );
      },
    );
  }

  String _txIcon(TransactionEntry tx) {
    switch (tx.type) {
      case 'income':
        return '💰';
      case 'transfer':
        return '🔄';
      default:
        return '🧾';
    }
  }

  String _txTitle(TransactionEntry tx) {
    final amount = NumberFormat.currency(
      locale: 'zh_CN',
      symbol: '',
      decimalDigits: 2,
    ).format(tx.amount);
    final sign = tx.type == 'income' ? '+' : '-';
    final prefix = tx.type == 'transfer' ? '' : sign;
    return '$prefix${tx.currency} $amount';
  }

  String _txSubtitle(BuildContext context, TransactionEntry tx) {
    final date =
        DateFormat('yyyy-MM-dd HH:mm', 'zh_CN').format(tx.occurredAt);
    return tx.type == 'transfer' ? context.l10n.trashTxSubtitleTransfer(date) : date;
  }

  Future<void> _restoreTx(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry tx,
  ) async {
    try {
      final repo = await ref.read(transactionRepositoryProvider.future);
      await repo.restoreById(tx.id);
      _invalidateDownstream(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashRestored)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashRestoreFailed(e.toString()))));
      }
    }
  }

  Future<void> _purgeTx(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry tx,
  ) async {
    final ok = await _confirmPurge(context, context.l10n.trashPurgeConfirm);
    if (!ok) return;
    try {
      final cleaner = ref.read(trashAttachmentCleanerProvider);
      final repo = await ref.read(transactionRepositoryProvider.future);
      // 附件先于 DB 删——硬删后无法再用 txId 反推目录。
      await cleaner.deleteForTransaction(tx.id);
      await repo.purgeById(tx.id);
      _invalidateDownstream(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashPurged)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashPurgeFailed(e.toString()))));
      }
    }
  }
}

/// ----------------- 分类 Tab -----------------

class _TrashCategoriesTab extends ConsumerWidget {
  const _TrashCategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(trashedCategoriesProvider);
    return asyncList.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
      data: (items) {
        final visible = items
            .where((c) => c.deletedAt != null)
            .where((c) =>
                trashDaysLeft(deletedAt: c.deletedAt!, now: DateTime.now()) > 0)
            .toList();
        if (visible.isEmpty) {
          return _TrashEmptyState(label: context.l10n.trashNoDeletedCategories);
        }
        return ListView.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = visible[i];
            return _TrashRow(
              icon: resolveCategoryIcon(
                  c.icon, c.parentKey, c.name, ref.watch(currentIconPackProvider), '🏷️'),
              title: c.name,
              subtitle: CategoryManagePage.parentLabelFor(context, c.parentKey),
              deletedAt: c.deletedAt!,
              onRestore: () => _restore(context, ref, c),
              onPurge: () => _purge(context, ref, c),
            );
          },
        );
      },
    );
  }

  Future<void> _restore(
      BuildContext context, WidgetRef ref, Category c) async {
    try {
      final repo = await ref.read(categoryRepositoryProvider.future);
      await repo.restoreById(c.id);
      _invalidateDownstream(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trashRestoredCategory(c.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashRestoreFailed(e.toString()))));
      }
    }
  }

  Future<void> _purge(BuildContext context, WidgetRef ref, Category c) async {
    final ok = await _confirmPurge(context, context.l10n.trashPurgeCategoryConfirm(c.name));
    if (!ok) return;
    try {
      final repo = await ref.read(categoryRepositoryProvider.future);
      await repo.purgeById(c.id);
      _invalidateDownstream(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashPurged)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashPurgeFailed(e.toString()))));
      }
    }
  }
}

/// ----------------- 账户 Tab -----------------

class _TrashAccountsTab extends ConsumerWidget {
  const _TrashAccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(trashedAccountsProvider);
    return asyncList.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
      data: (items) {
        final visible = items
            .where((a) => a.deletedAt != null)
            .where((a) =>
                trashDaysLeft(deletedAt: a.deletedAt!, now: DateTime.now()) > 0)
            .toList();
        if (visible.isEmpty) {
          return _TrashEmptyState(label: context.l10n.trashNoDeletedAccounts);
        }
        return ListView.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final a = visible[i];
            return _TrashRow(
              icon: a.icon ?? '💳',
              title: a.name,
              subtitle: _accountTypeLabel(context, a.type),
              deletedAt: a.deletedAt!,
              onRestore: () => _restore(context, ref, a),
              onPurge: () => _purge(context, ref, a),
            );
          },
        );
      },
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, Account a) async {
    try {
      final repo = await ref.read(accountRepositoryProvider.future);
      await repo.restoreById(a.id);
      _invalidateDownstream(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trashRestoredAccount(a.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashRestoreFailed(e.toString()))));
      }
    }
  }

  Future<void> _purge(BuildContext context, WidgetRef ref, Account a) async {
    final ok = await _confirmPurge(context, context.l10n.trashPurgeAccountConfirm(a.name));
    if (!ok) return;
    try {
      final repo = await ref.read(accountRepositoryProvider.future);
      await repo.purgeById(a.id);
      _invalidateDownstream(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashPurged)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashPurgeFailed(e.toString()))));
      }
    }
  }

  String _accountTypeLabel(BuildContext context, String type) {
    switch (type) {
      case 'cash':
        return context.l10n.accountTypeCash;
      case 'debit':
        return context.l10n.accountTypeDebit;
      case 'credit':
        return context.l10n.accountTypeCredit;
      case 'third_party':
        return context.l10n.accountTypeThirdParty;
      default:
        return context.l10n.accountTypeOther;
    }
  }
}

/// ----------------- 账本 Tab -----------------

class _TrashLedgersTab extends ConsumerWidget {
  const _TrashLedgersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(trashedLedgersProvider);
    return asyncList.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
      data: (items) {
        final visible = items
            .where((l) => l.deletedAt != null)
            .where((l) =>
                trashDaysLeft(deletedAt: l.deletedAt!, now: DateTime.now()) > 0)
            .toList();
        if (visible.isEmpty) {
          return _TrashEmptyState(label: context.l10n.trashNoDeletedLedgers);
        }
        return ListView.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final l = visible[i];
            return _TrashRow(
              icon: l.coverEmoji ?? '📒',
              title: l.name,
              subtitle: context.l10n.trashLedgerSubtitle,
              deletedAt: l.deletedAt!,
              onRestore: () => _restore(context, ref, l),
              onPurge: () => _purge(context, ref, l),
            );
          },
        );
      },
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, Ledger l) async {
    try {
      final repo = await ref.read(ledgerRepositoryProvider.future);
      await repo.restoreById(l.id);
      _invalidateDownstream(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trashRestoredLedger(l.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashRestoreFailed(e.toString()))));
      }
    }
  }

  Future<void> _purge(BuildContext context, WidgetRef ref, Ledger l) async {
    final ok = await _confirmPurge(
      context,
      context.l10n.trashPurgeLedgerConfirm(l.name),
    );
    if (!ok) return;
    try {
      final ledgerRepo = await ref.read(ledgerRepositoryProvider.future);
      final txRepo = await ref.read(transactionRepositoryProvider.future);
      final cleaner = ref.read(trashAttachmentCleanerProvider);
      // 拉所有该账本下流水（活跃 + 软删）的 id，用于清附件——硬删账本前一步处理。
      final activeTx = await txRepo.listActiveByLedger(l.id);
      // listDeleted 是全账本的——以 ledgerId 过滤。
      final deletedTx = (await txRepo.listDeleted())
          .where((t) => t.ledgerId == l.id)
          .toList();
      final ids = <String>{
        ...activeTx.map((t) => t.id),
        ...deletedTx.map((t) => t.id),
      };
      if (ids.isNotEmpty) {
        await cleaner.deleteForTransactions(ids);
      }
      await ledgerRepo.purgeById(l.id);
      _invalidateDownstream(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashPurgedLedger)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.trashPurgeFailed(e.toString()))));
      }
    }
  }
}

/// ----------------- 通用组件 -----------------

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.deletedAt,
    required this.onRestore,
    required this.onPurge,
  });

  final String icon;
  final String title;
  final String subtitle;
  final DateTime deletedAt;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final daysLeft =
        trashDaysLeft(deletedAt: deletedAt, now: DateTime.now());
    final color = Theme.of(context).colorScheme;
    return ListTile(
      leading: Text(icon, style: const TextStyle(fontSize: 28)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            context.l10n.trashRemainingDays(daysLeft, DateFormat('MM-dd HH:mm', 'zh_CN').format(deletedAt)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color.onSurfaceVariant,
                ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.l10n.trashRestore,
            icon: const Icon(Icons.restore_outlined),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: context.l10n.trashPermanentDelete,
            icon: Icon(Icons.delete_forever_outlined, color: color.error),
            onPressed: onPurge,
          ),
        ],
      ),
    );
  }
}

class _TrashEmptyState extends StatelessWidget {
  const _TrashEmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🗑️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            context.l10n.trashAutoCleanHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmPurge(BuildContext outerContext, String message) async {
  final result = await showDialog<bool>(
    context: outerContext,
    builder: (dialogContext) => AlertDialog(
      title: Text(outerContext.l10n.trashConfirmPermanentDelete),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(outerContext.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(outerContext.l10n.trashPermanentDelete),
        ),
      ],
    ),
  );
  return result == true;
}

/// 单条恢复 / 永久删除完成后的统一收尾——4 个 Tab 共用：刷新 trash 列表、
/// refresh 下游受影响 provider、触发同步防抖。
/// **不**直接 show SnackBar——SnackBar 需要 context.mounted 检查，由调用方
/// 在 await 后守门后再显示，避免 use_build_context_synchronously 警告。
void _invalidateDownstream(WidgetRef ref) {
  invalidateTrashFromWidgetRef(ref);
  ref.invalidate(recordMonthSummaryProvider);
  ref.invalidate(ledgerGroupsProvider);
  ref.invalidate(ledgerTxCountsProvider);
  ref.invalidate(activeBudgetsProvider);
  ref.invalidate(accountsListProvider);
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(totalAssetsProvider);
  ref.invalidate(statsLinePointsProvider);
  ref.invalidate(statsPieSlicesProvider);
  ref.invalidate(statsRankItemsProvider);
  ref.invalidate(statsHeatmapCellsProvider);
  ref.read(syncTriggerProvider.notifier).scheduleDebounced();
}
