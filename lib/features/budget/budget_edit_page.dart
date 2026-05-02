import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repository/budget_repository.dart';
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
    final ledgerId = await ref.read(currentLedgerIdProvider.future);
    final repo = await ref.read(budgetRepositoryProvider.future);
    final all = await repo.listActiveByLedger(ledgerId);
    return all.firstWhere(
      (b) => b.id == widget.budgetId,
      orElse: () => throw StateError('预算不存在'),
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
        title: Text(isEdit ? '编辑预算' : '新建预算'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
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
            return Center(child: Text('加载失败：${snapshot.error}'));
          }
          _hydrate(snapshot.data);

          final categoriesAsync = ref.watch(budgetableCategoriesProvider);
          return categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
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
            const Text('周期'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'monthly', label: Text('月')),
                ButtonSegment(value: 'yearly', label: Text('年')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: '分类',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('总预算（不限分类）'),
                ),
                ..._sortedCategoryItems(categories),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '预算金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                final raw = v?.trim() ?? '';
                if (raw.isEmpty) return '请输入金额';
                final n = double.tryParse(raw);
                if (n == null || n <= 0) return '金额必须大于 0';
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('开启结转'),
              subtitle: const Text('未花完金额累加到下个周期'),
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
    List<Category> categories,
  ) {
    final sorted = [...categories]..sort((a, b) {
        final pa = kParentKeyLabels[a.parentKey] ?? a.parentKey;
        final pb = kParentKeyLabels[b.parentKey] ?? b.parentKey;
        final c = pa.compareTo(pb);
        if (c != 0) return c;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return [
      for (final c in sorted)
        DropdownMenuItem<String?>(
          value: c.id,
          child: Text(
            '${kParentKeyLabels[c.parentKey] ?? c.parentKey} · ${c.name}',
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
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
    final fmt = period == 'yearly' ? '${value.year} 年起' : '${value.year}-${value.month.toString().padLeft(2, '0')} 起';

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
                  Text('结转起始', style: theme.textTheme.bodyMedium),
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
                      '选择更早的月份可让那时之后的剩余结转到本月',
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
      helpText: '选择结转起始月份',
      // 不需要选具体日期；datePicker 会让用户选日，我们规整到该月 1 日。
    );
    if (picked == null) return;
    final normalized = period == 'yearly'
        ? DateTime(picked.year)
        : DateTime(picked.year, picked.month);
    onChanged(normalized);
  }
}
