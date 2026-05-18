import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../data/repository/providers.dart' show currentLedgerIdProvider;
import '../account/account_providers.dart';
import '../budget/budget_providers.dart';
import '../ledger/ledger_list_page.dart';
import '../ledger/ledger_providers.dart';
import '../record/record_providers.dart';
import '../stats/stats_range_providers.dart';
import 'cloud_backup_discovery.dart';
import 'sync_provider.dart';
import 'sync_service.dart';

/// 浏览云端所有备份并选择恢复——重装/换机后找回数据的入口。
///
/// 与 `_SyncStatusBody` 的下载按钮的差异:后者下载"当前 ledgerId 对应的"
/// 单一备份,在新装设备上几乎必然 miss(因为本地 ledger 是新种子的 UUID);
/// 本页直接 list 整个 `users/` 前缀,按上传时间倒序列出全部备份,逐个或一键
/// 恢复为新账本(分配新 UUID,不覆盖本地)。
class BackupListPage extends ConsumerStatefulWidget {
  const BackupListPage({super.key});

  @override
  ConsumerState<BackupListPage> createState() => _BackupListPageState();
}

class _BackupListPageState extends ConsumerState<BackupListPage> {
  Future<List<RemoteBackup>>? _backupsFuture;

  /// 单条恢复 / 删除中的 cloudPath 集合——防止同行重复点击。
  final Set<String> _busyPaths = {};

  /// "全部恢复"运行中——会禁用其它单行操作。
  bool _bulkRunning = false;
  int _bulkDone = 0;
  int _bulkTotal = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final svcAsync = ref.read(syncServiceProvider);
    final svc = svcAsync.maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );
    if (svc == null) {
      // syncService 异步未就绪——再 await 一次。
      final resolved = await ref.read(syncServiceProvider.future);
      setState(() {
        _backupsFuture = resolved.listBackups();
      });
      return;
    }
    setState(() {
      _backupsFuture = svc.listBackups();
    });
  }

  Future<SyncService> _service() => ref.read(syncServiceProvider.future);

  Future<void> _restoreOne(RemoteBackup backup) async {
    if (_busyPaths.contains(backup.cloudPath) || _bulkRunning) return;

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupRestoreConfirmTitle),
        content: Text(l10n.backupRestoreConfirmMsg(backup.ledgerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyPaths.add(backup.cloudPath));
    try {
      final svc = await _service();
      await svc.restoreFromBackup(backup);
      _invalidateDataProviders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupRestoreSuccess(backup.ledgerName))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupRestoreFailed(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPaths.remove(backup.cloudPath));
      }
    }
  }

  Future<void> _deleteOne(RemoteBackup backup) async {
    if (_busyPaths.contains(backup.cloudPath) || _bulkRunning) return;

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncDeleteCloudBackup),
        content: Text(l10n.backupDeleteConfirmMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyPaths.add(backup.cloudPath));
    try {
      final svc = await _service();
      await svc.deleteBackupAt(backup.cloudPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.syncCloudDeleted)),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupDeleteFailed(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPaths.remove(backup.cloudPath));
      }
    }
  }

  Future<void> _restoreAll(List<RemoteBackup> backups) async {
    if (_bulkRunning) return;
    if (backups.isEmpty) return;

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupRestoreAllConfirmTitle),
        content: Text(l10n.backupRestoreAllConfirmMsg(backups.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _bulkRunning = true;
      _bulkDone = 0;
      _bulkTotal = backups.length;
    });
    var success = 0;
    try {
      final svc = await _service();
      for (final b in backups) {
        try {
          await svc.restoreFromBackup(b);
          success++;
        } catch (e) {
          // 单条失败不中断整体流程,继续下一个;最终 snackbar 给"已恢复 N/总数"
          debugPrintRestoreError(b, e);
        }
        if (!mounted) return;
        setState(() => _bulkDone++);
      }
      _invalidateDataProviders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupRestoreAllDone(success))),
      );
    } finally {
      if (mounted) {
        setState(() => _bulkRunning = false);
      }
    }
  }

  /// 恢复路径会改 ledger / tx / budget / category / account——保持与
  /// `cloud_service_page._invalidateDataProviders` 一致(那边对应"下载覆盖"
  /// 路径),否则新账本在列表里看不见。
  void _invalidateDataProviders() {
    ref.invalidate(recordMonthSummaryProvider);
    ref.invalidate(statsLinePointsProvider);
    ref.invalidate(statsPieSlicesProvider);
    ref.invalidate(statsRankItemsProvider);
    ref.invalidate(statsHeatmapCellsProvider);
    ref.invalidate(accountsListProvider);
    ref.invalidate(accountBalancesProvider);
    ref.invalidate(totalAssetsProvider);
    ref.invalidate(activeBudgetsProvider);
    ref.invalidate(budgetableCategoriesProvider);
    ref.invalidate(budgetProgressForProvider);
    ref.invalidate(ledgerTxCountsProvider);
    // 恢复后新增了账本，必须刷新账本列表和当前账本选择
    ref.invalidate(ledgerGroupsProvider);
    ref.invalidate(currentLedgerIdProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupListTitle),
        actions: [
          IconButton(
            onPressed: _bulkRunning ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.syncRefreshStatus,
          ),
        ],
      ),
      body: FutureBuilder<List<RemoteBackup>>(
        future: _backupsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.backupListLoadFailed(snap.error.toString()),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final list = snap.data ?? const <RemoteBackup>[];
          if (list.isEmpty) {
            return Center(
              child: Text(l10n.backupListEmpty),
            );
          }
          return Column(
            children: [
              if (_bulkRunning)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.backupRestoreAllProgress(
                          _bulkDone, _bulkTotal)),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(list[i]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<RemoteBackup>>(
        future: _backupsFuture,
        builder: (context, snap) {
          final list = snap.data;
          if (list == null || list.isEmpty) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _bulkRunning ? null : () => _restoreAll(list),
                icon: const Icon(Icons.cloud_download_outlined),
                label: Text(l10n.backupRestoreAll),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(RemoteBackup b) {
    final l10n = context.l10n;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final busy = _busyPaths.contains(b.cloudPath);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.book_outlined, size: 36),
        title: Text(
          b.ledgerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(l10n.backupRowTxCount(b.transactionCount)),
            Text(l10n.backupRowExportedAt(fmt.format(b.exportedAt.toLocal()))),
            Text(l10n.backupRowFromDevice(_shortId(b.sourceDeviceId))),
          ],
        ),
        trailing: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<_RowAction>(
                onSelected: (action) {
                  switch (action) {
                    case _RowAction.restore:
                      _restoreOne(b);
                      break;
                    case _RowAction.delete:
                      _deleteOne(b);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: _RowAction.restore,
                    child: Row(children: [
                      const Icon(Icons.restore),
                      const SizedBox(width: 8),
                      Text(l10n.syncRestore),
                    ]),
                  ),
                  PopupMenuItem(
                    value: _RowAction.delete,
                    child: Row(children: [
                      const Icon(Icons.delete_outline),
                      const SizedBox(width: 8),
                      Text(l10n.delete),
                    ]),
                  ),
                ],
              ),
        isThreeLine: true,
      ),
    );
  }
}

enum _RowAction { restore, delete }

/// 设备 UUID 太长——取前 6 位足以让用户分辨"老设备 vs 新设备"。
String _shortId(String id) {
  if (id.length <= 8) return id;
  return id.substring(0, 6);
}

/// 单独抽出来,便于未来切换日志通道——目前直接 debugPrint。
void debugPrintRestoreError(RemoteBackup backup, Object err) {
  // ignore: avoid_print
  print('[BackupListPage] restoreFromBackup(${backup.cloudPath}) failed — $err');
}
