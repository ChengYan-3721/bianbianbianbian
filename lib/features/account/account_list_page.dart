import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/l10n/l10n_ext.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import 'account_balance.dart';
import 'account_providers.dart';

/// 资产 Tab（Step 7.1 列表 / Step 7.2 CRUD）：顶部"总资产"卡片 + 下方账户卡片列表。
///
/// 总资产 = 当前账本下全部 `include_in_total = true` 的账户当前余额相加；
/// 各账户卡片分别展示"图标、名称、类型、当前余额"。信用卡负余额（欠款）
/// 用语义 danger 色突出。Step 7.2：新增 FAB 进入新建页、点击卡片进入编辑、
/// 长按弹出菜单（编辑 / 删除），删除走软删（进垃圾桶 30 天）。
class AccountListPage extends ConsumerWidget {
  const AccountListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);
    final balancesAsync = ref.watch(accountBalancesProvider);
    final totalAsync = ref.watch(totalAssetsProvider);

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
          }
        },
        icon: const Icon(Icons.add),
        label: Text(context.l10n.accountNewTitle),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
        data: (accounts) => balancesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
          data: (balances) {
            final byId = {for (final b in balances) b.accountId: b};
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                _TotalAssetsCard(totalAsync: totalAsync),
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
                          final saved = await context.push<bool>(
                            '/accounts/edit?id=${acc.id}',
                          );
                          if (saved == true) {
                            ref.invalidate(accountsListProvider);
                            ref.invalidate(accountBalancesProvider);
                            ref.invalidate(totalAssetsProvider);
                          }
                        },
                        onLongPress: () =>
                            _showAccountMenu(context, ref, acc),
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

  void _showAccountMenu(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) {
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
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(context.l10n.delete, style: const TextStyle(color: Colors.red)),
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountDeleted(account.name))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deleteFailedWithError(e.toString()))),
      );
    }
  }
}

class _TotalAssetsCard extends StatelessWidget {
  const _TotalAssetsCard({required this.totalAsync});

  final AsyncValue<double> totalAsync;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountText = totalAsync.when(
      loading: () => '--',
      error: (e, _) => context.l10n.loadFailed,
      data: (v) => '¥${_fmt.format(v)}',
    );
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.accountTotalAssets,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              amountText,
              key: const Key('total_assets_amount'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
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
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.black26,
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
    final amount = balance?.currentBalance ?? account.initialBalance;
    final isNegative = amount < 0;
    final amountColor =
        isNegative ? semantic.danger : theme.colorScheme.onSurface;
    final typeLabel = _typeLabel(context, account.type);
    final notInTotalSuffix = account.includeInTotal ? '' : context.l10n.accountNotInTotal;
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
              Text(
                account.icon ?? '💳',
                style: const TextStyle(fontSize: 28),
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
                        color: Colors.black54,
                      ),
                    ),
                    if (creditInfo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        creditInfo,
                        key: Key('credit_info_${account.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
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
  String? _creditDayLine(BuildContext context, int? billingDay, int? repaymentDay) {
    final parts = <String>[];
    if (billingDay != null) parts.add(context.l10n.accountBillingDayDisplay(billingDay));
    if (repaymentDay != null) parts.add(context.l10n.accountRepaymentDayDisplay(repaymentDay));
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
