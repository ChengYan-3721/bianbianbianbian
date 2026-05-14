import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../core/util/category_icon_packs.dart';
import '../../data/local/attachment_meta_codec.dart';
import '../../data/repository/providers.dart' show transactionRepositoryProvider;
import '../../domain/entity/attachment_meta.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';
import '../budget/budget_providers.dart';
import '../settings/settings_providers.dart';
import '../stats/stats_range_providers.dart';
import '../sync/attachment/attachment_providers.dart';
import 'record_home_page.dart' show formatTxAmountForDetail;
import 'record_new_page.dart';
import 'record_new_providers.dart';
import 'record_providers.dart';
import 'widgets/attachment_thumbnail.dart';

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

  List<AttachmentMeta> _decodeAttachmentMetas() =>
      AttachmentMetaCodec.decode(tx.attachmentsEncrypted);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = category;
    final iconPack = ref.watch(currentIconPackProvider);
    final icon = tx.type == 'transfer'
        ? '🔁'
        : (c != null
            ? resolveCategoryIcon(c.icon, c.parentKey, c.name, iconPack)
            : (tx.type == 'income' ? '💰' : '💸'));
    final name = tx.type == 'transfer' ? context.l10n.txTypeTransfer : (c?.name ?? context.l10n.txTypeUncategorized);
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
            _DetailKV(label: context.l10n.detailType, value: tx.type == 'income' ? context.l10n.txTypeIncome : (tx.type == 'expense' ? context.l10n.txTypeExpense : context.l10n.txTypeTransfer)),
            _DetailKV(
              label: tx.type == 'transfer' ? context.l10n.detailTransferFrom : context.l10n.recordNewWallet,
              value: accountName,
            ),
            if (tx.type == 'transfer')
              _DetailKV(label: context.l10n.detailTransferTo, value: toAccountName ?? context.l10n.detailAccount),
            _DetailKV(label: context.l10n.detailTime, value: date),
            _DetailKV(
              label: context.l10n.recordNewNote,
              value: (tx.tags == null || tx.tags!.isEmpty) ? '—' : tx.tags!,
            ),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.detailImages,
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
                    return AttachmentThumbnail(
                      meta: meta,
                      txId: tx.id,
                      size: 84,
                      onTap: () => _openFullscreenViewer(
                        context: context,
                        meta: meta,
                        txId: tx.id,
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
                    child: Text(context.l10n.detailCopy),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _popWithAction(
                      context,
                      RecordDetailAction.edit,
                    ),
                    child: Text(context.l10n.edit),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _popWithAction(
                      context,
                      RecordDetailAction.delete,
                    ),
                    child: Text(context.l10n.delete),
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
      // Step 11.4：软删后清 cache 子目录——不动 documents（垃圾桶恢复时
      // 仍可读原图）+ 不动远端对象（30 天后由 trash GC 硬删）。失败静默。
      unawaited(_purgeAttachmentCache(ref, tx.id));
      if (!context.mounted) return;
      _invalidateAfterChange(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deleted)),
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

/// Step 11.4：软删流水时联动清 `<cache>/attachments/<txId>/`。
///
/// fire-and-forget，调用方不需要 await——cache 是性能层，清不掉只是空间
/// 浪费，下一次 [AttachmentCachePruner.prune] 会按 LRU 兜底。
///
/// pruner provider 还在 loading 时（启动初期 / 切 backend 期间）也直接吞
/// 掉——没有 cache 的 App 也是合规状态。
Future<void> _purgeAttachmentCache(WidgetRef ref, String txId) async {
  try {
    final pruner = await ref.read(attachmentCachePrunerProvider.future);
    await pruner.removeForTransaction(txId);
  } catch (_) {
    // 静默——cache 清理失败不影响业务。
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.recordDeleteConfirm),
          content: Text(context.l10n.recordDeleteHint),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.onSurface,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.delete),
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

/// Step 11.3：详情页点击缩略图时的全屏预览。统一封装到 helper，避免在
/// `RecordDetailSheet` 的 `itemBuilder` 里堆 60 行内联 dialog。
///
/// 实现走 [AttachmentThumbnail.ensureLocal] 的同一懒下载路径：先点缩略图
/// 表示用户本地一定已经有文件了（缩略图本身是渲染成功态点上的）；这里再走
/// 一次 [AttachmentThumbnail] 在大图模式（fit=contain）渲染即可。
Future<void> _openFullscreenViewer({
  required BuildContext context,
  required AttachmentMeta meta,
  required String txId,
}) {
  return showDialog<void>(
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
                child: AttachmentThumbnail(
                  meta: meta,
                  txId: txId,
                  size: MediaQuery.of(dialogContext).size.shortestSide,
                  borderRadius: 0,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                tooltip: context.l10n.close,
                color: Colors.white,
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      );
    },
  );
}
