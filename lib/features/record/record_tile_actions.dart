import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/attachment_meta_codec.dart';
import '../../data/repository/providers.dart' show transactionRepositoryProvider;
import '../../domain/entity/attachment_meta.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';
import '../budget/budget_providers.dart';
import '../settings/settings_providers.dart';
import '../stats/stats_range_providers.dart';
import 'record_home_page.dart' show formatTxAmountForDetail;
import 'record_new_page.dart';
import 'record_new_providers.dart';
import 'record_providers.dart';

/// Step 3.6 续：流水点击后弹出的详情底部表单可触发的三种动作。
///
/// 之前是 `record_home_page.dart` 内的 `_DetailAction` 私有 enum；为了让
/// 搜索页 `record_search_page.dart` 也能复用同一交互，提升为公开 API 并
/// 搬到本文件。语义不变。
enum RecordDetailAction { edit, copy, delete }

/// 流水详情只读底部表单——展示完整字段 + 底部三个动作按钮。
///
/// 关闭返回 null（用户外部点击或下滑收起）；按钮返回对应 [RecordDetailAction]。
/// 调用方接收返回值后由 [openRecordTileActions] 统一调度后续操作（编辑 / 复制 /
/// 软删 + provider invalidate）。
class RecordDetailSheet extends ConsumerWidget {
  const RecordDetailSheet({
    super.key,
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

  List<AttachmentMeta> _decodeAttachmentMetas() =>
      AttachmentMetaCodec.decode(tx.attachmentsEncrypted);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = category;
    final icon = tx.type == 'transfer'
        ? '🔁'
        : (c?.icon ?? (tx.type == 'income' ? '💰' : '💸'));
    final name = tx.type == 'transfer' ? '转账' : (c?.name ?? '未分类');
    final attachments = _decodeAttachmentMetas();
    final date =
        '${tx.occurredAt.year}-${tx.occurredAt.month.toString().padLeft(2, '0')}-${tx.occurredAt.day.toString().padLeft(2, '0')} '
        '${tx.occurredAt.hour.toString().padLeft(2, '0')}:${tx.occurredAt.minute.toString().padLeft(2, '0')}';
    final ledgerCurrency =
        ref.watch(currentLedgerDefaultCurrencyProvider).valueOrNull ?? 'CNY';
    final amountText = formatTxAmountForDetail(tx, ledgerCurrency);
    final amountColor = tx.type == 'expense'
        ? const Color(0xFFE76F51)
        : tx.type == 'income'
            ? const Color(0xFFA8D8B9)
            : const Color(0xFF6C8CC8);

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
                  amountText,
                  key: const Key('detail_amount'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: amountColor,
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
            _DetailKV(
              label: '备注',
              value: (tx.tags == null || tx.tags!.isEmpty) ? '—' : tx.tags!,
            ),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '图片',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(160),
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
                    final meta = attachments[index];
                    final localPath = meta.localPath;
                    if (localPath == null) {
                      return _BrokenAttachmentTile(size: 84);
                    }
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
                                      File(localPath),
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
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
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
                          File(localPath),
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _BrokenAttachmentTile(
                            size: 84,
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
                    onPressed: () => _popWithAction(
                      context,
                      RecordDetailAction.copy,
                    ),
                    child: const Text('复制'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _popWithAction(
                      context,
                      RecordDetailAction.edit,
                    ),
                    child: const Text('编辑'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _popWithAction(
                      context,
                      RecordDetailAction.delete,
                    ),
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

/// 详情底部表单的"按下按钮"统一收尾：先 unfocus 再 pop。
///
/// 之所以把 unfocus 放在 pop 之前同步执行：搜索页里点击结果项时已经 unfocus 过
/// 一次，但 `showModalBottomSheet` 关闭时焦点会被还原到打开 sheet 之前的
/// primaryFocus（搜索页的关键词 / 金额 TextField），导致紧接着打开的编辑表单 /
/// 删除对话框还会让键盘弹一帧再被覆盖。同时：如果焦点切换发生在 sheet 还在做
/// dismiss 动画时（异步 unfocus），可能撞上"deactivated InkWell ancestor"框架
/// 警告——硬件键事件触达即将销毁的按钮 InkWell。两个问题在 pop 前同步 unfocus
/// 一起解决。
void _popWithAction(BuildContext context, RecordDetailAction action) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.of(context).pop(action);
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
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(160),
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

/// 把 [RecordNewPage] 包成模态底部表单——首页 FAB / 详情编辑 / 详情复制
/// 三处复用同一展示形式：圆角、半屏、奶油色背景、内嵌 SafeArea。
Future<void> _showRecordEditSheet({
  required BuildContext context,
  required bool isTransfer,
  bool startAtKeyboard = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.58,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          color: Theme.of(sheetContext).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: RecordNewPage(
              isTransfer: isTransfer,
              startAtKeyboard: startAtKeyboard,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 把"列表 / 搜索结果点击 → 详情底部表单 → 编辑 / 复制 / 删除"整条链路
/// 收口为一个 helper。两个调用点（首页 `_TxTile.onTap`、搜索页 `_ResultTile`）
/// 共用同一份代码，避免分叉。
///
/// - [parentKey]：调用方根据流水的 categoryId / type 推断出的一级分类 key（用于
///   `preloadFromEntry` 把表单初始 Tab 选中正确分类）。
/// - 删除路径走 `_confirmDelete` 二次确认 → `softDeleteById`，并在成功后弹
///   SnackBar；编辑 / 复制走 `preloadFromEntry` + `_showRecordEditSheet`。
/// - 三类动作执行完毕都会一并 invalidate 首页 / 统计 / 预算相关 provider，让
///   返回上一屏的数据立即刷新。
Future<void> openRecordTileActions({
  required BuildContext context,
  required WidgetRef ref,
  required TransactionEntry tx,
  Category? category,
  required String accountName,
  String? toAccountName,
  required String parentKey,
}) async {
  final action = await showModalBottomSheet<RecordDetailAction>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => RecordDetailSheet(
      tx: tx,
      category: category,
      accountName: accountName,
      toAccountName: toAccountName,
    ),
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case RecordDetailAction.edit:
      await ref.read(recordFormProvider.notifier).preloadFromEntry(
            tx,
            parentKey: parentKey,
            asEdit: true,
          );
      if (!context.mounted) return;
      await _showRecordEditSheet(
        context: context,
        isTransfer: tx.type == 'transfer',
      );
      if (!context.mounted) return;
      _invalidateAfterChange(ref);
      break;
    case RecordDetailAction.copy:
      await ref.read(recordFormProvider.notifier).preloadFromEntry(
            tx,
            parentKey: parentKey,
            asEdit: false,
          );
      if (!context.mounted) return;
      await _showRecordEditSheet(
        context: context,
        isTransfer: tx.type == 'transfer',
      );
      if (!context.mounted) return;
      _invalidateAfterChange(ref);
      break;
    case RecordDetailAction.delete:
      final ok = await _confirmDelete(context);
      if (!ok) return;
      final txRepo =
          await ref.read(transactionRepositoryProvider.future);
      await txRepo.softDeleteById(tx.id);
      if (!context.mounted) return;
      _invalidateAfterChange(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除')),
      );
      break;
  }
}

void _invalidateAfterChange(WidgetRef ref) {
  ref.invalidate(recordMonthSummaryProvider);
  ref.invalidate(statsLinePointsProvider);
  ref.invalidate(statsPieSlicesProvider);
  ref.invalidate(statsRankItemsProvider);
  ref.invalidate(statsHeatmapCellsProvider);
  ref.invalidate(budgetProgressForProvider);
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

/// 根据 [Category] 与 [TransactionEntry] 推断流水所属的一级分类 key。
///
/// 与 `record_home_page.dart::_TxTile._inferParentKey` 同语义，搬到 helper 共享。
String inferParentKeyForTx(Category? category, TransactionEntry tx) {
  if (category != null) return category.parentKey;
  if (tx.type == 'income') return 'income';
  return 'other';
}

/// Step 11.2：附件 [AttachmentMeta.localPath] 缺失或加载失败时的占位 tile。
///
/// 触发场景：① 用户手动删除本地文件；② v8→v9 升级后旧路径不存在标记
/// `missing: true`；③ 远端 download 中（lazy download 在 Step 11.3 接入前
/// remoteKey-only 的 meta 暂时无法 resolve）。
class _BrokenAttachmentTile extends StatelessWidget {
  const _BrokenAttachmentTile({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
