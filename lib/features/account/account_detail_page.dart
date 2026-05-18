import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/l10n/l10n_ext.dart';
import '../../core/util/category_icon_packs.dart';
import '../../core/util/svg_or_emoji_icon.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';
import '../record/record_providers.dart' show categoriesListProvider;
import '../record/record_tile_actions.dart'
    show inferParentKeyForTx, openRecordTileActions;
import '../settings/settings_providers.dart' show currentIconPackProvider;
import 'account_balance.dart';
import 'account_providers.dart';

/// 账户详情页（资产页重构 · 2026-05）：
///
/// - AppBar：返回 + 右上角「设置」文本按钮（跳到原 [AccountEditPage]）；
/// - 顶部 success 色卡片：余额、年份切换器（默认当年）、年度流出 / 流入；
/// - 下方按月分组的当年流水卡片（默认当月展开，其余折叠）。
///
/// 流入 / 流出口径包含转账（见 [computeAccountYearDetail]）：
/// - 流入：income 进本账户 + transfer 转入本账户
/// - 流出：expense 出本账户 + transfer 转出本账户
class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  late int _year;
  late Set<int> _expandedMonths;
  // 标记用户是否已经主动操作过本年的折叠状态。未操作时，年份切换 / 数据
  // 刷新都按"默认展开当月"重新初始化；操作过后保留用户的选择，避免数据
  // 重拉时把展开的卡片合上。
  bool _userToggled = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _expandedMonths = {now.month};
  }

  void _setYear(int delta) {
    setState(() {
      _year += delta;
      _userToggled = false;
      final now = DateTime.now();
      _expandedMonths = _year == now.year ? {now.month} : <int>{};
    });
  }

  void _toggleMonth(int month) {
    setState(() {
      _userToggled = true;
      if (_expandedMonths.contains(month)) {
        _expandedMonths.remove(month);
      } else {
        _expandedMonths.add(month);
      }
    });
  }

  Future<void> _openSettings(Account account) async {
    final saved =
        await context.push<bool>('/accounts/edit?id=${account.id}');
    if (saved == true) {
      ref.invalidate(accountsListProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(totalAssetsProvider);
      ref.invalidate(accountAssetLiabilityProvider);
      ref.invalidate(currentLedgerTransactionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountsAsync = ref.watch(accountsListProvider);
    final txsAsync = ref.watch(currentLedgerTransactionsProvider);

    return accountsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.loadFailedWithError(e.toString()))),
      ),
      data: (accounts) {
        final account = accounts.firstWhere(
          (a) => a.id == widget.accountId,
          orElse: () => _missingAccount(),
        );
        if (account.id.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.accountNotExist)),
          );
        }
        return Scaffold(
          appBar: AppBar(
            actions: [
              TextButton(
                key: const Key('account_detail_settings_btn'),
                onPressed: () => _openSettings(account),
                child: Text(
                  l10n.accountDetailSettings,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          body: txsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(l10n.loadFailedWithError(e.toString()))),
            data: (txs) {
              final detail = computeAccountYearDetail(
                accountId: account.id,
                year: _year,
                transactions: txs,
              );
              final balance = _currentBalance(account, txs);
              return _DetailBody(
                account: account,
                balance: balance,
                year: _year,
                detail: detail,
                expandedMonths: _expandedMonths,
                onPrevYear: () => _setYear(-1),
                onNextYear: () => _setYear(1),
                onToggleMonth: _toggleMonth,
                userToggled: _userToggled,
              );
            },
          ),
        );
      },
    );
  }

  Account _missingAccount() => Account(
        id: '',
        name: '',
        type: 'other',
        currency: 'CNY',
        updatedAt: DateTime.now(),
        deviceId: '',
      );

  double _currentBalance(Account account, List<TransactionEntry> txs) {
    final nets = aggregateNetAmountsByAccount(txs);
    return account.initialBalance + (nets[account.id] ?? 0);
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.account,
    required this.balance,
    required this.year,
    required this.detail,
    required this.expandedMonths,
    required this.onPrevYear,
    required this.onNextYear,
    required this.onToggleMonth,
    required this.userToggled,
  });

  final Account account;
  final double balance;
  final int year;
  final AccountYearDetail detail;
  final Set<int> expandedMonths;
  final VoidCallback onPrevYear;
  final VoidCallback onNextYear;
  final void Function(int month) onToggleMonth;
  final bool userToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final allMonths = detail.months.reversed.toList(growable: false);
    // 本年只展示到当月，避免未来月份显示空卡片误导用户；历史年份保持 12 个月。
    final months = year == now.year
        ? allMonths.where((g) => g.month <= now.month).toList(growable: false)
        : allMonths;
    final canGoNextYear = year < now.year;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeaderCard(
          balance: balance,
          year: year,
          yearInflow: detail.yearInflow,
          yearOutflow: detail.yearOutflow,
          onPrevYear: onPrevYear,
          onNextYear: canGoNextYear ? onNextYear : null,
        ),
        const SizedBox(height: 12),
        for (final group in months)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MonthCard(
              account: account,
              group: group,
              year: year,
              expanded: expandedMonths.contains(group.month),
              onToggle: () => onToggleMonth(group.month),
            ),
          ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.balance,
    required this.year,
    required this.yearInflow,
    required this.yearOutflow,
    required this.onPrevYear,
    required this.onNextYear,
  });

  final double balance;
  final int year;
  final double yearInflow;
  final double yearOutflow;
  final VoidCallback onPrevYear;
  /// 切到未来年没有意义（也会出现"未来月份"的空卡片），由父级把 `null`
  /// 传进来禁用 "下一年" 箭头。
  final VoidCallback? onNextYear;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<BianBianSemanticColors>()!;
    final bg = semantic.success;
    final fg = Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¥${_fmt.format(balance)}',
            key: const Key('account_detail_balance'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.accountDetailBalance,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _YearSwitcher(
                  year: year,
                  fg: fg,
                  onPrev: onPrevYear,
                  onNext: onNextYear,
                ),
              ),
              Expanded(
                child: _HeaderStat(
                  amount: yearOutflow,
                  label: context.l10n.accountDetailOutflow,
                  fg: fg,
                  amountKey: const Key('account_detail_year_outflow'),
                ),
              ),
              Expanded(
                child: _HeaderStat(
                  amount: yearInflow,
                  label: context.l10n.accountDetailInflow,
                  fg: fg,
                  amountKey: const Key('account_detail_year_inflow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YearSwitcher extends StatelessWidget {
  const _YearSwitcher({
    required this.year,
    required this.fg,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final Color fg;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextEnabled = onNext != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkResponse(
              key: const Key('account_detail_prev_year'),
              onTap: onPrev,
              radius: 18,
              child: Icon(Icons.chevron_left, color: fg, size: 22),
            ),
            const SizedBox(width: 4),
            Text(
              '$year',
              key: const Key('account_detail_year_label'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            InkResponse(
              key: const Key('account_detail_next_year'),
              onTap: onNext,
              radius: 18,
              child: Icon(
                Icons.chevron_right,
                color: nextEnabled ? fg : fg.withValues(alpha: 0.3),
                size: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          context.l10n.accountDetailYear,
          style: theme.textTheme.bodySmall?.copyWith(
            color: fg.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.amount,
    required this.label,
    required this.fg,
    required this.amountKey,
  });

  final double amount;
  final String label;
  final Color fg;
  final Key amountKey;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¥${_fmt.format(amount)}',
          key: amountKey,
          style: theme.textTheme.titleMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: fg.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _MonthCard extends ConsumerWidget {
  const _MonthCard({
    required this.account,
    required this.group,
    required this.year,
    required this.expanded,
    required this.onToggle,
  });

  final Account account;
  final AccountMonthGroup group;
  final int year;
  final bool expanded;
  final VoidCallback onToggle;

  static final _fmt = NumberFormat('#,##0.00');

  String _monthRange(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final mm = month.toString().padLeft(2, '0');
    final ddStart = firstDay.day.toString().padLeft(2, '0');
    final ddEnd = lastDay.day.toString().padLeft(2, '0');
    return '$mm.$ddStart-$mm.$ddEnd';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<BianBianSemanticColors>()!;
    final monthLabel = context.l10n
        .accountDetailMonthLabel(group.month.toString().padLeft(2, '0'));
    final inflowLine = context.l10n
        .accountDetailInflowLine(_fmt.format(group.inflow));
    final outflowLine = context.l10n
        .accountDetailOutflowLine(_fmt.format(group.outflow));

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('account_detail_month_header_${group.month}'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monthLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _monthRange(year, group.month),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inflowLine,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: semantic.danger,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          outflowLine,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: semantic.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFE2A03F),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            _MonthBody(
              account: account,
              transactions: group.transactions,
            ),
        ],
      ),
    );
  }
}

class _MonthBody extends ConsumerWidget {
  const _MonthBody({
    required this.account,
    required this.transactions,
  });

  final Account account;
  final List<TransactionEntry> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
        child: Column(
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.accountDetailEmptyMonth,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    final accounts = ref.watch(accountsListProvider).valueOrNull ??
        const <Account>[];
    final categories = ref.watch(categoriesListProvider).valueOrNull ??
        const <Category>[];
    final iconPack = ref.watch(currentIconPackProvider);

    // 同日多条流水：第一条左侧显示日期，其余空着。倒序遍历完成。
    final children = <Widget>[];
    DateTime? lastDay;
    for (var i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final day = DateTime(tx.occurredAt.year, tx.occurredAt.month,
          tx.occurredAt.day);
      final showDate = lastDay == null || lastDay != day;
      lastDay = day;
      children.add(
        _TxRow(
          tx: tx,
          account: account,
          accounts: accounts,
          categories: categories,
          iconPack: iconPack,
          dayLabel: showDate ? _formatDayLabel(context, day) : '',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Column(
        children: [
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  String _formatDayLabel(BuildContext context, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return context.l10n.accountDetailToday;
    if (day == yesterday) return context.l10n.accountDetailYesterday;
    return context.l10n
        .accountDetailDayLabel(day.day.toString().padLeft(2, '0'));
  }
}

class _TxRow extends ConsumerWidget {
  const _TxRow({
    required this.tx,
    required this.account,
    required this.accounts,
    required this.categories,
    required this.iconPack,
    required this.dayLabel,
  });

  final TransactionEntry tx;
  final Account account;
  final List<Account> accounts;
  final List<Category> categories;
  final BianBianIconPack iconPack;
  final String dayLabel;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<BianBianSemanticColors>()!;
    final isTransfer = tx.type == 'transfer';
    final isOutflowHere = (tx.type == 'expense' && tx.accountId == account.id) ||
        (isTransfer && tx.accountId == account.id);
    final sign = isOutflowHere ? '-' : '+';
    final amountColor =
        isOutflowHere ? semantic.danger : semantic.success;

    Category? matched;
    final cid = tx.categoryId;
    if (cid != null) {
      for (final c in categories) {
        if (c.id == cid) {
          matched = c;
          break;
        }
      }
    }
    final iconText = isTransfer
        ? '🔁'
        : (matched != null
            ? resolveCategoryIcon(
                matched.icon, matched.parentKey, matched.name, iconPack)
            : (tx.type == 'expense' ? '💸' : '💰'));
    final iconSvg = isTransfer ? null : matched?.iconSvg;
    final nameText = isTransfer
        ? context.l10n.txTypeTransfer
        : (matched?.name ?? context.l10n.txTypeUncategorized);
    final note = (tx.tags == null || tx.tags!.isEmpty) ? null : tx.tags;

    String accountName(String? id) {
      if (id == null || id.isEmpty) return context.l10n.recordNewWallet;
      for (final a in accounts) {
        if (a.id == id) return a.name;
      }
      return context.l10n.deletedAccount;
    }

    final transferSub = isTransfer
        ? '${accountName(tx.accountId)} → ${accountName(tx.toAccountId)}'
        : null;

    return InkWell(
      onTap: () async {
        await openRecordTileActions(
          context: context,
          ref: ref,
          tx: tx,
          category: matched,
          accountName: accountName(tx.accountId),
          toAccountName: isTransfer ? accountName(tx.toAccountId) : null,
          parentKey: inferParentKeyForTx(matched, tx),
        );
        if (context.mounted) {
          ref.invalidate(currentLedgerTransactionsProvider);
          ref.invalidate(accountBalancesProvider);
          ref.invalidate(totalAssetsProvider);
          ref.invalidate(accountAssetLiabilityProvider);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              child: Text(
                dayLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgOrEmojiIcon(
                svgString: iconSvg,
                emoji: iconText,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameText, style: theme.textTheme.bodyMedium),
                  if (transferSub != null)
                    Text(
                      transferSub,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (note != null)
                    Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              '$sign¥${_fmt.format(tx.amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
