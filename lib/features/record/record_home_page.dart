import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'record_new_page.dart';
import 'record_new_providers.dart';
import 'record_providers.dart';

import '../../data/repository/ledger_repository.dart';
import '../../data/repository/providers.dart'
    show
        accountRepositoryProvider,
        categoryRepositoryProvider,
        currentLedgerIdProvider,
        ledgerRepositoryProvider,
        transactionRepositoryProvider;
import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/ledger.dart';
import '../../domain/entity/transaction_entry.dart';

final _fmt = NumberFormat('#,##0.00');

/// 记账首页骨架（Phase 3 Step 3.1）。
///
/// 结构（自上而下）：
/// - 顶栏：账本名 + emoji（只读）+ 月份切换（← →）+ 搜索图标（占位）
/// - 数据卡片：本月收入 / 支出 / 结余
/// - 快捷输入条：单行输入 + "✨ 识别"（占位）
/// - 流水列表：按日期倒序分组，空时显示引导文字
/// - FAB：`+` → 跳转新建记账页（Step 3.2）
///
/// Phase 3 Step 3.2 落地新建页后 FAB 会接入路由；Step 3.3 做详情/编辑/删
/// 除；Step 3.5 做图片附件。
class RecordHomePage extends ConsumerWidget {
  const RecordHomePage({super.key});

  static const List<String> _weekdays = [
    '周一', '周二', '周三', '周四', '周五', '周六', '周日',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(recordMonthSummaryProvider);
    final currentId = ref.watch(currentLedgerIdProvider).valueOrNull;
    final repo = ref.watch(ledgerRepositoryProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(currentId: currentId, repo: repo),
            _MonthBar(ref: ref),
            _DataCards(summary: summary),
            const _QuickInputBar(),
            Expanded(child: _TransactionList(summary: summary)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'record_home_fab',
        onPressed: () {
          ref.read(recordFormProvider.notifier).reset();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => FractionallySizedBox(
              heightFactor: 0.58,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: const _RecordBottomSheetPage(),
                ),
              ),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}

// ---- 顶栏：账本名 + emoji + 搜索占位 ----

class _TopBar extends ConsumerWidget {
  const _TopBar({this.currentId, this.repo});

  final String? currentId;
  final LedgerRepository? repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = currentId;
    final r = repo;
    if (id == null || r == null) {
      return const SizedBox(height: 48);
    }
    return FutureBuilder<Ledger?>(
      future: r.getById(id),
      builder: (context, snapshot) {
        final ledger = snapshot.data;
        final emoji = ledger?.coverEmoji ?? '📒';
        final name = ledger?.name ?? '账本';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 22),
                onPressed: () {
                  ref.read(recordFormProvider.notifier).reset();
                  ref.read(recordFormProvider.notifier).setTransferMode(true);
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) => FractionallySizedBox(
                      heightFactor: 0.58,
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: const _RecordTransferBottomSheetPage(),
                        ),
                      ),
                    ),
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.search, size: 22),
                onPressed: () {
                  // 搜索占位——Phase 5+ 接入
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---- 月份切换条 ----

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(recordMonthProvider);
    final monthLabel = '${month.year}年${month.month}月';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 24),
            onPressed: () =>
                ref.read(recordMonthProvider.notifier).previous(),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            monthLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 24),
            onPressed: () =>
                ref.read(recordMonthProvider.notifier).next(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ---- 数据卡片 ----

class _DataCards extends StatelessWidget {
  const _DataCards({required this.summary});

  final AsyncValue<RecordMonthSummary> summary;

  @override
  Widget build(BuildContext context) {
    final data = summary.valueOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _CardChip(label: '收入', amount: data?.income, colorKey: 'income'),
          const SizedBox(height: 6),
          _CardChip(label: '支出', amount: data?.expense, colorKey: 'expense'),
          const SizedBox(height: 6),
          _CardChip(label: '结余', amount: data?.balance, colorKey: 'balance'),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({required this.label, this.amount, required this.colorKey});

  final String label;
  final double? amount;
  final String colorKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Color chipColor;
    switch (colorKey) {
      case 'income':
        chipColor = const Color(0xFFA8D8B9); // 抹茶绿
        break;
      case 'expense':
        chipColor = const Color(0xFFE76F51); // 苹果红
        break;
      case 'balance':
      default:
        chipColor = colors.tertiary; // 可可棕，与 onSurface 同色系，对比度足够
    }

    final display = amount != null
        ? '¥${_fmt.format(amount!)}'
        : '¥--.--';

    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: chipColor.withAlpha(48),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chipColor.withAlpha(80), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(display, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                  ),
            ),
          ],
        ),
      );
  }
}

// ---- 快捷输入条 ----

class _QuickInputBar extends StatelessWidget {
  const _QuickInputBar();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.primary.withAlpha(120), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '写点什么，我来帮你记 🐰',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                      onSubmitted: (value) {
                        // Step 3.2 快捷输入条接线
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              // Step 3.2 接线
            },
            icon: const Text('✨', style: TextStyle(fontSize: 14)),
            label: const Text('识别'),
            style: TextButton.styleFrom(
              foregroundColor: colors.tertiary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 流水列表 ----

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.summary});

  final AsyncValue<RecordMonthSummary> summary;

  String _dayLabel(DateTime date) {
    final weekdays = RecordHomePage._weekdays;
    final wd = weekdays[date.weekday - 1];
    return '${date.month}月${date.day}日 $wd';
  }

  @override
  Widget build(BuildContext context) {
    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (data) {
        if (data.dailyGroups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.coffee_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withAlpha(128)),
                const SizedBox(height: 12),
                Text(
                  '开始记第一笔吧 🐰',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: data.dailyGroups.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, groupIndex) {
            final group = data.dailyGroups[groupIndex];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    _dayLabel(group.date),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                        ),
                  ),
                ),
                for (final tx in group.transactions)
                  _TxTile(
                    key: ValueKey('tx_tile_${tx.id}'),
                    tx: tx,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TxTile extends ConsumerStatefulWidget {
  const _TxTile({super.key, required this.tx});

  final TransactionEntry tx;

  @override
  ConsumerState<_TxTile> createState() => _TxTileState();
}

class _TxTileState extends ConsumerState<_TxTile> {
  bool _isDismissed = false;

  String _inferParentKey(Category? category, TransactionEntry tx) {
    if (category != null) return category.parentKey;
    if (tx.type == 'income') return 'income';
    return 'other';
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    if (_isDismissed) {
      return const SizedBox.shrink();
    }
    final isTransfer = tx.type == 'transfer';
    final isExpense = tx.type == 'expense';
    final sign = isTransfer ? '' : (isExpense ? '-' : '+');
    final amountColor = isTransfer
        ? const Color(0xFF6C8CC8)
        : (isExpense ? const Color(0xFFE76F51) : const Color(0xFFA8D8B9));
    final repo = ref.watch(categoryRepositoryProvider).valueOrNull;
    final accountRepo = ref.watch(accountRepositoryProvider).valueOrNull;

    return FutureBuilder<List<Category>>(
      future: repo?.listActiveAll(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
        Category? matched;
        final id = tx.categoryId;
        if (id != null) {
          for (final c in categories) {
            if (c.id == id) {
              matched = c;
              break;
            }
          }
        }

        final iconText = isTransfer
            ? '🔁'
            : (matched?.icon ??
                (tx.type == 'expense' ? '💸' : (tx.type == 'income' ? '💰' : '🔁')));
        final nameText = isTransfer ? '转账' : (matched?.name ?? '未分类');
        final parentKey = _inferParentKey(matched, tx);

        return FutureBuilder<List<Account>>(
          future: accountRepo?.listActive(),
          builder: (context, accountSnap) {
            final accounts = accountSnap.data ?? const <Account>[];
            String accountName(String? id) {
              if (id == null) return '账户';
              for (final a in accounts) {
                if (a.id == id) return a.name;
              }
              return '账户';
            }

            final transferSubTitle = isTransfer
                ? '${accountName(tx.accountId)} → ${accountName(tx.toAccountId)}'
                : null;

            return Dismissible(
              key: Key('tx_${tx.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                return _confirmDelete(context);
              },
              onDismissed: (_) async {
                if (mounted) {
                  setState(() => _isDismissed = true);
                }
                final txRepo = await ref.read(transactionRepositoryProvider.future);
                await txRepo.softDeleteById(tx.id);
                ref.invalidate(recordMonthSummaryProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除')),
                );
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE76F51).withAlpha(36),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline),
              ),
              child: InkWell(
                onTap: () async {
                  final action = await showModalBottomSheet<_DetailAction>(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) => _RecordDetailSheet(
                      tx: tx,
                      category: matched,
                      accountName: accountName(tx.accountId),
                      toAccountName: tx.type == 'transfer'
                          ? accountName(tx.toAccountId)
                          : null,
                    ),
                  );
                  if (!context.mounted || action == null) return;

                  switch (action) {
                    case _DetailAction.edit:
                      await ref.read(recordFormProvider.notifier).preloadFromEntry(
                            tx,
                            parentKey: parentKey,
                            asEdit: true,
                          );
                      if (!context.mounted) return;
                       await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (sheetContext) => FractionallySizedBox(
                          heightFactor: 0.58,
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              child: _RecordBottomSheetPage(
                                isTransfer: tx.type == 'transfer',
                                startAtKeyboard: true,
                              ),
                            ),
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      ref.invalidate(recordMonthSummaryProvider);
                      break;
                    case _DetailAction.copy:
                      await ref.read(recordFormProvider.notifier).preloadFromEntry(
                            tx,
                            parentKey: parentKey,
                            asEdit: false,
                          );
                      if (!context.mounted) return;
                       await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (sheetContext) => FractionallySizedBox(
                          heightFactor: 0.58,
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              child: _RecordBottomSheetPage(
                                isTransfer: tx.type == 'transfer',
                                startAtKeyboard: true,
                              ),
                            ),
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      ref.invalidate(recordMonthSummaryProvider);
                      break;
                    case _DetailAction.delete:
                      final ok = await _confirmDelete(context);
                      if (!ok) return;
                      final txRepo = await ref.read(transactionRepositoryProvider.future);
                      await txRepo.softDeleteById(tx.id);
                      if (!context.mounted) return;
                      ref.invalidate(recordMonthSummaryProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已删除')),
                      );
                      break;
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: amountColor.withAlpha(36),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          iconText,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameText,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (transferSubTitle != null)
                              Text(
                                transferSubTitle,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(150),
                                    ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '$sign¥${_fmt.format(tx.amount)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: amountColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除这条记录？'),
            content: const Text('删除后可在后续垃圾桶中恢复。'),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    return ok;
  }
}

enum _DetailAction { edit, copy, delete }

class _RecordDetailSheet extends StatelessWidget {
  const _RecordDetailSheet({
    required this.tx,
    this.category,
    required this.accountName,
    this.toAccountName,
  });

  final TransactionEntry tx;
  final Category? category;
  final String accountName;
  final String? toAccountName;

  String get _typeLabel {
    if (tx.type == 'income') return '收入';
    if (tx.type == 'expense') return '支出';
    return '转账';
  }

  List<String> _decodeAttachmentPaths() {
    final bytes = tx.attachmentsEncrypted;
    if (bytes == null || bytes.isEmpty) return const <String>[];
    try {
      final raw = utf8.decode(bytes);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
      return const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = category;
    final icon = tx.type == 'transfer'
        ? '🔁'
        : (c?.icon ?? (tx.type == 'income' ? '💰' : '💸'));
    final name = tx.type == 'transfer' ? '转账' : (c?.name ?? '未分类');
    final attachments = _decodeAttachmentPaths();
    final date =
        '${tx.occurredAt.year}-${tx.occurredAt.month.toString().padLeft(2, '0')}-${tx.occurredAt.day.toString().padLeft(2, '0')} '
        '${tx.occurredAt.hour.toString().padLeft(2, '0')}:${tx.occurredAt.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  '${tx.type == 'expense' ? '-' : '+'}¥${_fmt.format(tx.amount)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tx.type == 'expense'
                            ? const Color(0xFFE76F51)
                            : const Color(0xFFA8D8B9),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailKV(label: '类型', value: _typeLabel),
            _DetailKV(
              label: tx.type == 'transfer' ? '转出' : '钱包',
              value: accountName,
            ),
            if (tx.type == 'transfer')
              _DetailKV(label: '转入', value: toAccountName ?? '账户'),
            _DetailKV(label: '时间', value: date),
            _DetailKV(label: '备注', value: (tx.tags == null || tx.tags!.isEmpty) ? '—' : tx.tags!),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '图片',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                        ),
                  ),
                ),
              ),
            if (attachments.isNotEmpty) const SizedBox(height: 6),
            if (attachments.isNotEmpty)
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = attachments[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) {
                          return Dialog.fullscreen(
                            backgroundColor: Colors.black,
                            child: Stack(
                              children: [
                                Center(
                                  child: InteractiveViewer(
                                    minScale: 0.8,
                                    maxScale: 5,
                                    child: Image.file(
                                      File(path),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white70,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: IconButton(
                                    tooltip: '关闭',
                                    color: Colors.white,
                                    onPressed: () => Navigator.of(dialogContext).pop(),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(path),
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 84,
                            height: 84,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_DetailAction.copy),
                    child: const Text('复制'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_DetailAction.edit),
                    child: const Text('编辑'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_DetailAction.delete),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailKV extends StatelessWidget {
  const _DetailKV({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordBottomSheetPage extends ConsumerWidget {
  const _RecordBottomSheetPage({
    this.isTransfer = false,
    this.startAtKeyboard = false,
  });

  final bool isTransfer;
  final bool startAtKeyboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: RecordNewPage(
        isTransfer: isTransfer,
        startAtKeyboard: startAtKeyboard,
      ),
    );
  }
}

class _RecordTransferBottomSheetPage extends ConsumerWidget {
  const _RecordTransferBottomSheetPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SafeArea(
      top: false,
      child: RecordNewPage(isTransfer: true),
    );
  }
}