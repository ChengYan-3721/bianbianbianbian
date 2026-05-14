import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/l10n/l10n_ext.dart';
import '../../core/util/category_icon_packs.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/budget.dart';
import '../../domain/entity/category.dart';
import '../settings/settings_providers.dart';
import 'budget_progress.dart';
import 'budget_providers.dart';

/// 预算设置页（Step 6.1）：当前账本的总预算 + 各分类预算列表。
class BudgetListPage extends ConsumerWidget {
  const BudgetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(activeBudgetsProvider);
    final categoriesAsync = ref.watch(budgetableCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.budgetTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await context.push<bool>('/budget/edit');
          if (saved == true) ref.invalidate(activeBudgetsProvider);
        },
        icon: const Icon(Icons.add),
        label: Text(context.l10n.budgetNew),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
        data: (budgets) => categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
          data: (categories) {
            if (budgets.isEmpty) {
              return const _EmptyState();
            }
            final byId = {for (final c in categories) c.id: c};
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: budgets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _BudgetCard(
                budget: budgets[i],
                category: budgets[i].categoryId == null
                    ? null
                    : byId[budgets[i].categoryId!],
                onEdit: () async {
                  final saved = await context.push<bool>(
                    '/budget/edit?id=${budgets[i].id}',
                  );
                  if (saved == true) ref.invalidate(activeBudgetsProvider);
                },
                onDelete: () => _confirmDelete(context, ref, budgets[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.budgetDeleteConfirm),
        content: Text(context.l10n.budgetDeleteHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await ref.read(budgetRepositoryProvider.future);
    await repo.softDeleteById(budget.id);
    ref.invalidate(activeBudgetsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.deleted)));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.savings_outlined, size: 64, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            context.l10n.budgetEmptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({
    required this.budget,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Budget budget;
  final Category? category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<BianBianSemanticColors>()!;
    final periodLabel = budget.period == 'monthly' ? context.l10n.periodMonthBudget : context.l10n.periodYearBudget;
    final title = budget.categoryId == null
        ? context.l10n.budgetTotal
        : (category?.name ?? context.l10n.budgetDeletedCategory);

    final progressAsync = ref.watch(budgetProgressForProvider(budget));

    // 副标题/可用金额读 progress.carryBalance 而非 budget.carryBalance——
    // 后者在"刚新建、懒结算尚未把派生列写库"的瞬态会是旧值，前者是 settle
    // 后立即可用的最新值，避免出现"已花/上限正确但右上结转/可用未显示"。
    final liveCarry = budget.carryOver
        ? (progressAsync.valueOrNull?.carryBalance ?? budget.carryBalance)
        : 0.0;
    final showAvailable = budget.carryOver && liveCarry > 0;
    final available = budget.amount + liveCarry;

    final subtitle = StringBuffer(periodLabel);
    if (budget.carryOver) {
      subtitle.write(context.l10n.budgetCarryOverLabel);
      if (liveCarry > 0) {
        subtitle.write(' ¥${_fmt.format(liveCarry)}');
      }
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    resolveCategoryIcon(
                      category?.icon,
                      category?.parentKey ?? 'other',
                      category?.name ?? '',
                      ref.watch(currentIconPackProvider),
                      '💰',
                    ),
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          subtitle.toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${_fmt.format(budget.amount)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (showAvailable)
                        Text(
                          context.l10n.budgetAvailable(_fmt.format(available)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: semantic.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: context.l10n.delete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ProgressSection(
                budgetId: budget.id,
                progressAsync: progressAsync,
                semantic: semantic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressSection extends ConsumerWidget {
  const _ProgressSection({
    required this.budgetId,
    required this.progressAsync,
    required this.semantic,
  });

  final String budgetId;
  final AsyncValue<BudgetProgress> progressAsync;
  final BianBianSemanticColors semantic;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return progressAsync.when(
      loading: () => const _ProgressPlaceholder(),
      error: (e, _) => Text(
        context.l10n.budgetProgressFailed(e.toString()),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: semantic.danger,
            ),
      ),
      data: (progress) {
        final session = ref.read(budgetVibrationSessionProvider.notifier);
        if (shouldTriggerBudgetVibration(
          level: progress.level,
          alreadyVibrated: session.hasVibrated(budgetId),
        )) {
          // 把"标记 + 震动"都推迟到当前 frame 渲染完毕之后——build 期间
          // 修改 provider state 会触发 Riverpod 的 "Tried to modify a
          // provider while the widget tree was building" 断言。回调内再做
          // 一次 [hasVibrated] 检查，保证同帧多次 build 注册多个 postFrame
          // 时只执行一次。
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (session.hasVibrated(budgetId)) return;
            session.markVibrated(budgetId);
            HapticFeedback.heavyImpact();
          });
        }
        final color = switch (progress.level) {
          BudgetProgressLevel.green => semantic.success,
          BudgetProgressLevel.orange => semantic.warning,
          BudgetProgressLevel.red => semantic.danger,
        };
        final ratioClamped = progress.ratio.clamp(0.0, 1.0);
        final percent = (progress.ratio * 100).toStringAsFixed(
          progress.ratio >= 1 ? 0 : 1,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratioClamped,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.budgetSpentOverLimit(_fmt.format(progress.spent), _fmt.format(progress.limit)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ProgressPlaceholder extends StatelessWidget {
  const _ProgressPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 8,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.budgetProgressCalculating,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
