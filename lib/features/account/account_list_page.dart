import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/l10n/l10n_ext.dart';
import '../../data/repository/providers.dart';
import '../../core/util/svg_or_emoji_icon.dart';
import '../../domain/entity/account.dart';
import '../record/record_new_page.dart';
import '../record/record_new_providers.dart';
import 'account_balance.dart';
import 'account_providers.dart';

/// 资产 Tab（Step 7.1 列表 / Step 7.2 CRUD / 重构版）：顶部"资产"卡片
/// （资产 / 净资产 / 负债 三值） + 下方账户卡片列表。
///
/// 顶部资产 = Σ max(0, currentBalance)（仅正余额账户）；
/// 负债 = Σ |min(0, currentBalance)|（欠款账户绝对值）；
/// 净资产 = 资产 - 负债（与原 totalAssets 同值）。
/// 各账户卡片分别展示"图标、名称、类型、当前余额"。信用卡负余额（欠款）
/// 用语义 danger 色突出。重构后：点击账户进入 `/accounts/detail?id=` 详情页
/// 而不再直达编辑；长按弹出菜单（编辑 / 删除），删除走软删（进垃圾桶 30 天）。
class AccountListPage extends ConsumerWidget {
  const AccountListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);
    final balancesAsync = ref.watch(accountBalancesProvider);
    final assetLiabilityAsync = ref.watch(accountAssetLiabilityProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.meAssets)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'account_list_fab',
        onPressed: () async {
          final saved = await context.push<bool>('/accounts/edit');
          if (saved == true) {
            ref.invalidate(accountsListProvider);
            ref.invalidate(accountBalancesProvider);
            ref.invalidate(totalAssetsProvider);
            ref.invalidate(accountAssetLiabilityProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: Text(context.l10n.accountNewTitle),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
        data: (accounts) => balancesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(context.l10n.loadFailedWithError(e.toString())),
          ),
          data: (balances) {
            final byId = {for (final b in balances) b.accountId: b};
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                _AssetsOverviewCard(
                  assetLiabilityAsync: assetLiabilityAsync,
                  onTransfer: () => _openTransferSheet(context, ref),
                ),
                const SizedBox(height: 16),
                if (accounts.isEmpty)
                  const _EmptyState()
                else
                  ...accounts.map(
                    (acc) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AccountCard(
                        account: acc,
                        balance: byId[acc.id],
                        onTap: () async {
                          final changed = await context.push<bool>(
                            '/accounts/detail?id=${acc.id}',
                          );
                          if (changed == true) {
                            ref.invalidate(accountsListProvider);
                            ref.invalidate(accountBalancesProvider);
                            ref.invalidate(totalAssetsProvider);
                            ref.invalidate(accountAssetLiabilityProvider);
                          }
                        },
                        onLongPress: () => _showAccountMenu(context, ref, acc),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 资产卡片右上角"转账"按钮入口——与首页 swap 图标走同一套路径：
  /// reset 表单 + setTransferMode(true) → 弹底部 RecordNewPage(isTransfer: true)
  /// 模态。模态关闭后无论用户是否保存，统一 invalidate 资产相关 provider，
  /// 让顶部卡片和账户列表立刻反映新流水。
  Future<void> _openTransferSheet(BuildContext context, WidgetRef ref) async {
    ref.read(recordFormProvider.notifier).reset();
    ref.read(recordFormProvider.notifier).setTransferMode(true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.58,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Material(
            color: Theme.of(sheetContext).colorScheme.surface,
            child: const SafeArea(
              top: false,
              child: RecordNewPage(isTransfer: true),
            ),
          ),
        ),
      ),
    );
    ref.invalidate(accountsListProvider);
    ref.invalidate(accountBalancesProvider);
    ref.invalidate(totalAssetsProvider);
    ref.invalidate(accountAssetLiabilityProvider);
  }

  void _showAccountMenu(BuildContext context, WidgetRef ref, Account account) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.edit),
              onTap: () async {
                Navigator.pop(ctx);
                final saved = await context.push<bool>(
                  '/accounts/edit?id=${account.id}',
                );
                if (saved == true) {
                  ref.invalidate(accountsListProvider);
                  ref.invalidate(accountBalancesProvider);
                  ref.invalidate(totalAssetsProvider);
                  ref.invalidate(accountAssetLiabilityProvider);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                context.l10n.delete,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, account);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(context.l10n.accountDeleteConfirmMsg(account.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repo = await ref.read(accountRepositoryProvider.future);
      await repo.softDeleteById(account.id);
      ref.invalidate(accountsListProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(totalAssetsProvider);
      ref.invalidate(accountAssetLiabilityProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountDeleted(account.name))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.deleteFailedWithError(e.toString())),
        ),
      );
    }
  }
}

class _AssetsOverviewCard extends StatelessWidget {
  const _AssetsOverviewCard({
    required this.assetLiabilityAsync,
    required this.onTransfer,
  });

  final AsyncValue<({double assets, double liabilities})> assetLiabilityAsync;
  final VoidCallback onTransfer;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadFailed = context.l10n.loadFailed;
    final (assetsText, netText, liabilitiesText) = assetLiabilityAsync.when(
      loading: () => ('--', '--', '--'),
      error: (e, _) => (loadFailed, loadFailed, loadFailed),
      data: (v) => (
        '¥${_fmt.format(v.assets)}',
        '¥${_fmt.format(v.assets - v.liabilities)}',
        '¥${_fmt.format(v.liabilities)}',
      ),
    );

    final onContainer = theme.colorScheme.onPrimaryContainer;
    final dividerColor = onContainer.withValues(alpha: 0.25);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: onContainer.withValues(alpha: 0.85),
    );

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.accountAssets, style: labelStyle),
                      const SizedBox(height: 6),
                      Text(
                        assetsText,
                        key: const Key('account_assets_amount'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                _TransferPill(onTap: onTransfer, color: onContainer),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _OverviewCell(
                    label: context.l10n.accountNetAssets,
                    amount: netText,
                    amountKey: const Key('account_net_assets_amount'),
                    color: onContainer,
                  ),
                ),
                Container(width: 1, height: 32, color: dividerColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _OverviewCell(
                      label: context.l10n.accountLiabilities,
                      amount: liabilitiesText,
                      amountKey: const Key('account_liabilities_amount'),
                      color: onContainer,
                    ),
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

class _TransferPill extends StatelessWidget {
  const _TransferPill({required this.onTap, required this.color});

  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        key: const Key('account_list_transfer_btn'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            context.l10n.txTypeTransfer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewCell extends StatelessWidget {
  const _OverviewCell({
    required this.label,
    required this.amount,
    required this.amountKey,
    required this.color,
  });

  final String label;
  final String amount;
  final Key amountKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          key: amountKey,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.26),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.accountEmptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.balance,
    required this.onTap,
    required this.onLongPress,
  });

  final Account account;
  final AccountBalance? balance;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<BianBianSemanticColors>()!;
    final amount = balance?.currentBalance ?? 0;
    final isNegative = amount < 0;
    final amountColor = isNegative
        ? semantic.danger
        : theme.colorScheme.onSurface;
    final typeLabel = _typeLabel(context, account.type);
    final notInTotalSuffix = account.includeInTotal
        ? ''
        : context.l10n.accountNotInTotal;
    final creditInfo = account.type == 'credit'
        ? _creditDayLine(context, account.billingDay, account.repaymentDay)
        : null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SvgOrEmojiIcon(
                svgString: account.iconSvg,
                emoji: account.icon ?? '💳',
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '$typeLabel$notInTotalSuffix',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.54,
                        ),
                      ),
                    ),
                    if (creditInfo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        creditInfo,
                        key: Key('credit_info_${account.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${isNegative ? '-' : ''}¥${_fmt.format(amount.abs())}',
                key: Key('account_balance_${account.id}'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 信用卡专属副标题文案：根据填写情况组合"账单日 X 号 · 还款日 Y 号"，
  /// 任一字段缺失时仅显示已填字段；两者都缺失返回 null（UI 不渲染整行）。
  String? _creditDayLine(
    BuildContext context,
    int? billingDay,
    int? repaymentDay,
  ) {
    final parts = <String>[];
    if (billingDay != null) {
      parts.add(context.l10n.accountBillingDayDisplay(billingDay));
    }
    if (repaymentDay != null) {
      parts.add(context.l10n.accountRepaymentDayDisplay(repaymentDay));
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  static String _typeLabel(BuildContext context, String type) {
    final l10n = context.l10n;
    switch (type) {
      case 'cash':
        return l10n.accountTypeCash;
      case 'debit':
        return l10n.accountTypeDebit;
      case 'credit':
        return l10n.accountTypeCredit;
      case 'third_party':
        return l10n.accountTypeThirdParty;
      case 'other':
      default:
        return l10n.accountTypeOther;
    }
  }
}
