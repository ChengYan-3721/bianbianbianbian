import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../data/repository/exceptions.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/budget.dart';
import '../../domain/entity/category.dart';
import 'budget_providers.dart';

/// 预算编辑/新建页（Step 6.1）。
class BudgetEditPage extends ConsumerStatefulWidget {
  const BudgetEditPage({super.key, this.budgetId});

  final String? budgetId;

  @override
  ConsumerState<BudgetEditPage> createState() => _BudgetEditPageState();
}

class _BudgetEditPageState extends ConsumerState<BudgetEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String _period = 'monthly';
  String? _categoryId; // null = 总预算
  bool _carryOver = false;
  DateTime? _startDate;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<Budget?> _loadBudget() async {
    if (widget.budgetId == null) return null;
    final l10n = context.l10n;
    final ledgerId = await ref.read(currentLedgerIdProvider.future);
    final repo = await ref.read(budgetRepositoryProvider.future);
    final all = await repo.listActiveByLedger(ledgerId);
    return all.firstWhere(
      (b) => b.id == widget.budgetId,
      orElse: () => throw StateError(l10n.budgetNotExist),
    );
  }

  void _hydrate(Budget? existing) {
    if (_initialized) return;
    _initialized = true;
    if (existing == null) {
      // 新建：默认起始 = 本月 1 日。
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month);
      return;
    }
    _period = existing.period;
    _categoryId = existing.categoryId;
    _carryOver = existing.carryOver;
    _startDate = existing.startDate;
    _amountController.text = existing.amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.budgetId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '${context.l10n.edit}${context.l10n.budgetTitle}' : context.l10n.budgetNew),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.l10n.save),
          ),
        ],
      ),
      body: FutureBuilder<Budget?>(
        future: _loadBudget(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.loadFailedWithError(snapshot.error.toString())));
          }
          _hydrate(snapshot.data);

          final categoriesAsync = ref.watch(budgetableCategoriesProvider);
          return categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(context.l10n.loadFailedWithError(e.toString()))),
            data: (categories) => _buildForm(context, categories),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Category> categories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.budgetPeriod),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'monthly', label: Text(context.l10n.periodMonthly)),
                ButtonSegment(value: 'yearly', label: Text(context.l10n.periodYearly)),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: InputDecoration(
                labelText: context.l10n.budgetCategory,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(context.l10n.budgetTotalNoCategory),
                ),
                ..._sortedCategoryItems(context, categories),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: context.l10n.budgetAmount,
                prefixText: '¥ ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                final raw = v?.trim() ?? '';
                if (raw.isEmpty) return context.l10n.budgetAmountRequired;
                final n = double.tryParse(raw);
                if (n == null || n <= 0) return context.l10n.budgetAmountPositive;
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.budgetCarryOver),
              subtitle: Text(context.l10n.budgetCarryOverHint),
              value: _carryOver,
              onChanged: (v) => setState(() => _carryOver = v),
            ),
            if (_carryOver) ...[
              const SizedBox(height: 4),
              _StartDatePicker(
                period: _period,
                isEdit: widget.budgetId != null,
                value: _startDate ??
                    () {
                      final n = DateTime.now();
                      return DateTime(n.year, n.month);
                    }(),
                onChanged: (d) => setState(() => _startDate = d),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String?>> _sortedCategoryItems(
    BuildContext context,
    List<Category> categories,
  ) {
    final labels = parentKeyLabels(context);
    final sorted = [...categories]..sort((a, b) {
        final pa = labels[a.parentKey] ?? a.parentKey;
        final pb = labels[b.parentKey] ?? b.parentKey;
        final c = pa.compareTo(pb);
        if (c != 0) return c;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return [
      for (final c in sorted)
        DropdownMenuItem<String?>(
          value: c.id,
          child: Text(
            '${labels[c.parentKey] ?? c.parentKey} · ${c.name}',
          ),
        ),
    ];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final ledgerId = await ref.read(currentLedgerIdProvider.future);
      final repo = await ref.read(budgetRepositoryProvider.future);
      final amount = double.parse(_amountController.text.trim());
      final now = DateTime.now();

      Budget entity;
      if (widget.budgetId != null) {
        final all = await repo.listActiveByLedger(ledgerId);
        final existing = all.firstWhere((b) => b.id == widget.budgetId!);
        // 直接构造而非 copyWith：实体的 copyWith 不支持把 categoryId 清回 null。
        entity = Budget(
          id: existing.id,
          ledgerId: existing.ledgerId,
          period: _period,
          categoryId: _categoryId,
          amount: amount,
          carryOver: _carryOver,
          // 编辑模式：startDate 不允许在 UI 改（会让历史结算 anchor 失效）。
          startDate: existing.startDate,
          updatedAt: now,
          deletedAt: existing.deletedAt,
          deviceId: existing.deviceId,
        );
      } else {
        // 新建模式：用户可在 _StartDatePicker 里选起始月份；默认 = 本月 1 日。
        // anchor 由 applyCarryOverToggle 基于 startDate 推导，让"起始 = 上月"时
        // 5/1 进预算页能直接结算上月剩余。
        final start = _startDate ??
            (_period == 'monthly'
                ? DateTime(now.year, now.month)
                : DateTime(now.year));
        entity = Budget(
          id: const Uuid().v4(),
          ledgerId: ledgerId,
          period: _period,
          categoryId: _categoryId,
          amount: amount,
          carryOver: _carryOver,
          startDate: start,
          updatedAt: now,
          deviceId: '', // repo 覆写
        );
      }

      await repo.save(entity);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on BudgetConflictException catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      final periodLabel = e.period == 'yearly'
          ? l10n.periodYearly
          : l10n.periodMonthly;
      final msg = e.isTotal
          ? l10n.budgetConflictTotal(periodLabel)
          : l10n.budgetConflictCategory(periodLabel);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.saveFailedWithError(e.toString()))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// 起始月份选择器（仅在 `_carryOver = true` 时显示）。
///
/// 新建模式可选；编辑模式只读——历史 anchor 已落库，UI 改 startDate 不会
/// 反向 invalidate 已经累加的 carryBalance，会造成显示与计算的不一致。
class _StartDatePicker extends StatelessWidget {
  const _StartDatePicker({
    required this.period,
    required this.isEdit,
    required this.value,
    required this.onChanged,
  });

  final String period; // monthly | yearly
  final bool isEdit;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = period == 'yearly' ? '${value.year}${context.l10n.budgetYearStartFrom}' : '${value.year}-${value.month.toString().padLeft(2, '0')} 起'; // i18n-exempt: monthly date format suffix

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isEdit ? null : () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.budgetCarryStart, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    fmt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.budgetCarryStartHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isEdit)
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5, 1);
    final lastDate = DateTime(now.year, now.month);
    final picked = await showDatePicker(
      context: context,
      initialDate: value.isAfter(lastDate) ? lastDate : value,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: context.l10n.budgetSelectCarryStartMonth,
      // 不需要选具体日期；datePicker 会让用户选日，我们规整到该月 1 日。
    );
    if (picked == null) return;
    final normalized = period == 'yearly'
        ? DateTime(picked.year)
        : DateTime(picked.year, picked.month);
    onChanged(normalized);
  }
}
