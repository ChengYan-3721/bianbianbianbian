import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/util/currencies.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../settings/settings_providers.dart';
import 'record_new_providers.dart';
import 'widgets/number_keyboard.dart';

/// 记一笔底部抽屉页（按 daodao 交互重构）
///
/// 两个状态：
/// - 分类选择态：先选一级/二级分类；
/// - 数字键盘态：选中二级后进入金额输入与扩展信息编辑。
class RecordNewPage extends ConsumerStatefulWidget {
  const RecordNewPage({
    super.key,
    this.isTransfer = false,
    this.startAtKeyboard = false,
  });

  final bool isTransfer;
  final bool startAtKeyboard;

  static const parentTabs = [
    ('☆', 'favorite'),
    ('收', 'income'),
    ('食', 'food'),
    ('购', 'shopping'),
    ('行', 'transport'),
    ('育', 'education'),
    ('乐', 'entertainment'),
    ('情', 'social'),
    ('住', 'housing'),
    ('医', 'medical'),
    ('投', 'investment'),
    ('其', 'other'),
  ];

  @override
  ConsumerState<RecordNewPage> createState() => _RecordNewPageState();
}

class _RecordNewPageState extends ConsumerState<RecordNewPage> {
  bool _showKeyboard = false;
  int _categoryGridVersion = 0;

  void _refreshCategoryGrid() {
    if (!mounted) return;
    setState(() {
      _categoryGridVersion++;
    });
  }

  @override
  void initState() {
    super.initState();
    _showKeyboard = widget.startAtKeyboard || widget.isTransfer;
    // Step 8.2：进入新建/转账页时把币种字段设为账本默认币种（fire-and-forget）。
    // 编辑/复制路径走 preloadFromEntry，已在 currency 字段填好原 entry 值，
    // initDefaultCurrency 内部会因 currency != 'CNY' 提前 return，不会覆盖。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recordFormProvider.notifier).initDefaultCurrency();
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(recordFormProvider);
    final notifier = ref.read(recordFormProvider.notifier);
    final effectiveShowKeyboard = widget.isTransfer ? true : _showKeyboard;
    // Step 8.1：开关关闭时记账页币种字段隐藏（loading/error 期间默认按
    // "关闭"显示，避免短暂闪现币种键的不一致体验）。
    final showCurrencyKey =
        ref.watch(multiCurrencyEnabledProvider).valueOrNull ?? false;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.isTransfer ? '转账' : '记一笔'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          Expanded(
            child: effectiveShowKeyboard
                ? _KeyboardStage(
                    form: form,
                    onBackToCategory: () =>
                        setState(() => _showKeyboard = false),
                    isTransfer: widget.isTransfer,
                  )
                : widget.isTransfer
                    ? _TransferEntryStage(
                        onEnter: () {
                          notifier.initDefaultAccount();
                          setState(() => _showKeyboard = true);
                        },
                      )
                    : _RecordPageRefreshMarker(
                        onRefresh: _refreshCategoryGrid,
                        child: _CategoryStage(
                          key: ValueKey(
                            '${form.selectedParentKey}|${form.categoryId}|$_categoryGridVersion',
                          ),
                          parentKey: form.selectedParentKey,
                          selectedId: form.categoryId,
                          onParentChanged: notifier.setParentKey,
                          onCategorySelected: (id, pk) {
                            notifier.setCategory(id, parentKey: pk);
                            notifier.initDefaultAccount(); // fire-and-forget，键盘立即弹出
                            setState(() => _showKeyboard = true);
                          },
                        ),
                      ),
          ),
          if (!_showKeyboard && !widget.isTransfer)
            _ParentTabs(
              selectedKey: form.selectedParentKey,
              onChanged: notifier.setParentKey,
            ),
          if (effectiveShowKeyboard)
            NumberKeyboard(
              onKeyTap: notifier.onKeyTap,
              currencyLabel: form.currency,
              showEquals: notifier.hasOperator,
              onCurrencyTap: () async {
                // Step 8.2：CNY 键改为打开 11 内置币种下拉。
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  builder: (sheetContext) => _CurrencyPicker(
                    selectedCode: form.currency,
                  ),
                );
                if (picked != null && picked != form.currency) {
                  notifier.setCurrency(picked);
                }
              },
              showCurrencyKey: showCurrencyKey,
              onActionTap: () async {
                if (notifier.hasOperator) {
                  if (!notifier.canAction) return;
                  notifier.onActionTap();
                  return;
                }
                if (!form.canSave) return;
                if (widget.isTransfer &&
                    form.accountId != null &&
                    form.toAccountId != null &&
                    form.accountId == form.toAccountId) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('转出账户和转入账户不能相同')),
                  );
                  return;
                }
                final navigator = Navigator.of(context);
                final ok = await notifier.save();
                if (!mounted) return;
                if (ok) navigator.pop();
              },
              canAction: notifier.hasOperator ? notifier.canAction : form.canSave,
            ),
        ],
      ),
    );
  }
}

class _RecordPageRefreshMarker extends InheritedWidget {
  const _RecordPageRefreshMarker({
    required this.onRefresh,
    required super.child,
  });

  final VoidCallback onRefresh;

  @override
  bool updateShouldNotify(_RecordPageRefreshMarker oldWidget) => false;
}

class _CategoryStage extends StatelessWidget {
  const _CategoryStage({
    super.key,
    required this.parentKey,
    required this.selectedId,
    required this.onParentChanged,
    required this.onCategorySelected,
  });

  final String parentKey;
  final String? selectedId;
  final ValueChanged<String> onParentChanged;
  final void Function(String id, String parentKey) onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择分类',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _CategoryGrid(
              parentKey: parentKey,
              selectedId: selectedId,
              onSelected: (id, pk) => onCategorySelected(id, pk),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyboardStage extends ConsumerWidget {
  const _KeyboardStage({
    required this.form,
    required this.onBackToCategory,
    required this.isTransfer,
  });

  final RecordFormData form;
  final VoidCallback onBackToCategory;
  final bool isTransfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(recordFormProvider.notifier);
    final repo = ref.watch(categoryRepositoryProvider).valueOrNull;

    return FutureBuilder<List<Category>>(
      future: repo?.listActiveAll(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
        final selectedCategoryName = _resolveCategoryName(
          categories,
          form.categoryId,
        );

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _AmountDisplay(form: form),
              ),
              const SizedBox(height: 0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MetaToolbar(
                  form: form,
                  selectedCategoryName: selectedCategoryName,
                  onBackToCategory: onBackToCategory,
                  onTimeChanged: notifier.setOccurredAt,
                  onAccountSelected: notifier.setAccount,
                  onToAccountSelected: notifier.setToAccount,
                  onNoteChanged: notifier.setNote,
                  isTransfer: isTransfer,
                ),
              ),
              const SizedBox(height: 0),
            ],
          ),
        );
      },
    );
  }

  String _resolveCategoryName(List<Category> categories, String? categoryId) {
    if (categoryId == null) return '切换';
    for (final c in categories) {
      if (c.id == categoryId) return c.name;
    }
    return '切换';
  }
}

class _ParentTabs extends StatelessWidget {
  const _ParentTabs({required this.selectedKey, required this.onChanged});

  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: RecordNewPage.parentTabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, key) = RecordNewPage.parentTabs[index];
          final selected = selectedKey == key;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colors.primary : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colors.onPrimary
                      : colors.onSurface.withAlpha(180),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.form});

  final RecordFormData form;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Step 8.2：根据 form.currency 在 kBuiltInCurrencies 中查找符号，避免硬
    // 编码 ¥/$；非内置币种回退到列表第一项（CNY）。
    final currency = kBuiltInCurrencies.firstWhere(
      (c) => c.code == form.currency,
      orElse: () => kBuiltInCurrencies.first,
    );
    final symbol = currency.symbol;
    final amountText = form.expression.isNotEmpty
        ? form.expression
        : (form.amount ?? 0).toStringAsFixed(2);
    final displayAmount = '$symbol $amountText';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withAlpha(100)),
      ),
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayAmount,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                  fontFamily: 'monospace',
                ),
            key: const Key('amount_result'),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({
    required this.parentKey,
    required this.selectedId,
    required this.onSelected,
  });

  final String parentKey;
  final String? selectedId;
  final void Function(String id, String parentKey) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(categoryRepositoryProvider).valueOrNull;
    if (repo == null) {
      return const Center(child: Text('加载分类…'));
    }

    return FutureBuilder<List<Category>>(
      key: ValueKey('$parentKey|$selectedId'),
      future: parentKey == 'favorite'
          ? repo.listFavorites()
          : repo.listActiveByParentKey(parentKey),
      builder: (context, snapshot) {
        final cats = snapshot.data ?? [];
        final hasData = cats.isNotEmpty;
        final itemCount = hasData ? cats.length + 1 : 1;
        return GridView.builder(
          itemCount: itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.95,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (!hasData || index == cats.length) {
              final isFavoriteTab = parentKey == 'favorite';
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  if (isFavoriteTab) {
                    await context.push('/record/categories');
                  } else {
                    await context.push('/record/categories/parent?parentKey=$parentKey');
                  }
                  if (!context.mounted) return;
                  final markRefresh = context
                      .findAncestorWidgetOfExactType<_RecordPageRefreshMarker>();
                  markRefresh?.onRefresh();
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isFavoriteTab ? Icons.add : Icons.edit_outlined,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFavoriteTab ? '添加' : '编辑',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }

            final cat = cats[index];
            final selected = selectedId == cat.id;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelected(cat.id, cat.parentKey),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  color: selected
                      ? Theme.of(context).colorScheme.primary.withAlpha(24)
                      : null,
                ),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat.icon ?? '📁', style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetaToolbar extends StatelessWidget {
  const _MetaToolbar({
    required this.form,
    required this.selectedCategoryName,
    required this.onBackToCategory,
    required this.onTimeChanged,
    required this.onAccountSelected,
    required this.onToAccountSelected,
    required this.onNoteChanged,
    required this.isTransfer,
  });

  final RecordFormData form;
  final String selectedCategoryName;
  final VoidCallback onBackToCategory;
  final ValueChanged<DateTime?> onTimeChanged;
  final ValueChanged<String?> onAccountSelected;
  final ValueChanged<String?> onToAccountSelected;
  final ValueChanged<String> onNoteChanged;
  final bool isTransfer;

  @override
  Widget build(BuildContext context) {
    final occurredAt = form.occurredAt ?? DateTime.now();
    final timeLabel =
        '${occurredAt.month.toString().padLeft(2, '0')}.${occurredAt.day.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: isTransfer
                    ? _WalletPillButton(
                        selectedId: form.accountId,
                        onSelected: onAccountSelected,
                        emptyText: '转出账户',
                        icon: Icons.call_made,
                        excludeId: form.toAccountId,
                      )
                    : _MetaPillButton(
                        label: '分类',
                        value: selectedCategoryName,
                        icon: Icons.breakfast_dining,
                        onTap: onBackToCategory,
                      ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: _MetaPillButton(
                  label: '日期',
                  value: timeLabel,
                  icon: Icons.schedule,
                  onTap: () async {
                    final now = DateTime.now();
                    final time = form.occurredAt ?? now;
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: time.isAfter(now) ? now : time,
                      firstDate: DateTime(2020),
                      lastDate: now,
                      locale: const Locale('zh', 'CN'),
                      cancelText: '取消',
                      confirmText: '确定',
                      builder: (context, child) {
                        final scheme = Theme.of(context).colorScheme;
                        final base = Theme.of(context);
                        return Theme(
                          data: base.copyWith(
                            datePickerTheme: const DatePickerThemeData(
                              headerHeadlineStyle: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w400,
                              ),
                              headerHelpStyle: TextStyle(
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.onSurface,
                                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked == null || !context.mounted) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(time),
                      cancelText: '取消',
                      confirmText: '确定',
                      builder: (context, child) {
                        final scheme = Theme.of(context).colorScheme;
                        return Theme(
                          data: Theme.of(context).copyWith(
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.onSurface,
                                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (t == null) return;
                    onTimeChanged(
                      DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: isTransfer
                    ? _WalletPillButton(
                        selectedId: form.toAccountId,
                        onSelected: onToAccountSelected,
                        emptyText: '转入账户',
                        icon: Icons.call_received,
                        excludeId: form.accountId,
                      )
                    : _WalletPillButton(
                        selectedId: form.accountId,
                        onSelected: onAccountSelected,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _NotePillButton(
                note: form.note,
                onChanged: onNoteChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaPillButton extends StatelessWidget {
  const _MetaPillButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withAlpha(80),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colors.onSurface.withAlpha(180)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletPillButton extends ConsumerWidget {
  const _WalletPillButton({
    required this.selectedId,
    required this.onSelected,
    this.emptyText = '钱包',
    this.icon = Icons.account_balance_wallet_outlined,
    this.excludeId,
  });

  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final String emptyText;
  final IconData icon;
  final String? excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(accountRepositoryProvider).valueOrNull;
    if (repo == null) {
      return _MetaPillButton(
        label: emptyText,
        value: emptyText,
        icon: icon,
        onTap: _noop,
      );
    }

    return FutureBuilder<List<Account>>(
      future: repo.listActive(),
      builder: (context, snapshot) {
        final allAccounts = snapshot.data ?? [];
        final accounts = excludeId == null
            ? allAccounts
            : allAccounts.where((a) => a.id != excludeId).toList();
        final selected = selectedId == null
            ? null
            : allAccounts.where((a) => a.id == selectedId).firstOrNull;
        return _MetaPillButton(
          label: emptyText,
          value: selected?.name ?? emptyText,
          icon: icon,
          onTap: () => showModalBottomSheet(
            context: context,
            builder: (ctx) => ListView(
              shrinkWrap: true,
              children: [
                for (final a in accounts)
                  ListTile(
                    leading: Text(a.icon ?? '💳'),
                    title: Text(a.name),
                    onTap: () {
                      onSelected(a.id);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _noop() {}

class _NoteSheet extends ConsumerWidget {
  const _NoteSheet({
    required this.controller,
    required this.notifier,
    required this.onConfirm,
  });

  final TextEditingController controller;
  final RecordForm notifier;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            '备注',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('note_field'),
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '输入备注',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _NoteAttachments(notifier: notifier),
          const SizedBox(height: 8),
          _NoteActions(
            notifier: notifier,
            onConfirm: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _NoteAttachments extends ConsumerWidget {
  const _NoteAttachments({required this.notifier});

  final RecordForm notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(recordFormProvider).attachmentPaths;
    if (paths.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: paths.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final path = paths[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tooltip: '删除图片',
                      onPressed: () => notifier.removeAttachmentAt(index),
                      icon: const Icon(Icons.cancel, size: 18),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoteActions extends ConsumerWidget {
  const _NoteActions({required this.notifier, required this.onConfirm});

  final RecordForm notifier;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(recordFormProvider).attachmentPaths.length;

    return Row(
      children: [
        IconButton(
          tooltip: '相册',
          onPressed: () => _pickAndShowError(context, () => notifier.pickAndAttachFromGallery()),
          icon: const Icon(Icons.photo_library_outlined),
        ),
        IconButton(
          tooltip: '拍照',
          onPressed: () => _pickAndShowError(context, () => notifier.pickAndAttachFromCamera()),
          icon: const Icon(Icons.camera_alt_outlined),
        ),
        Text(
          '$count/3',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const Spacer(),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: onConfirm,
          child: const Text('确定'),
        ),
      ],
    );
  }

  Future<void> _pickAndShowError(
    BuildContext context,
    Future<String?> Function() pick,
  ) async {
    final msg = await pick();
    if (msg != null && context.mounted) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('提示'),
          content: Text(msg),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onSurface,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }
}

class _TransferEntryStage extends ConsumerWidget {
  const _TransferEntryStage({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(recordFormProvider);
    final canEnter = form.accountId != null && form.toAccountId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '转账设置',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          _MetaToolbar(
            form: form,
            selectedCategoryName: '转账',
            onBackToCategory: _noop,
            onTimeChanged: ref.read(recordFormProvider.notifier).setOccurredAt,
            onAccountSelected: ref.read(recordFormProvider.notifier).setAccount,
            onToAccountSelected:
                ref.read(recordFormProvider.notifier).setToAccount,
            onNoteChanged: ref.read(recordFormProvider.notifier).setNote,
            isTransfer: true,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canEnter ? onEnter : null,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('输入金额'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotePillButton extends ConsumerWidget {
  const _NotePillButton({required this.note, required this.onChanged});

  final String note;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = note.isEmpty ? '备注' : note;
    return _MetaPillButton(
      label: '备注',
      value: value,
      icon: Icons.edit_note_outlined,
      onTap: () async {
        final controller = TextEditingController(text: note);
        final notifier = ref.read(recordFormProvider.notifier);
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => _NoteSheet(
            controller: controller,
            notifier: notifier,
            onConfirm: () {
              onChanged(controller.text.trim());
              Navigator.pop(ctx);
            },
          ),
        );
      },
    );
  }
}

/// Step 8.2：币种选择器底部抽屉。
///
/// 罗列 [kBuiltInCurrencies] 11 种内置币种；当前选中项尾部带 ✓。点击某行
/// `Navigator.pop(context, code)` 把 ISO 码回传给调用方。
class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.selectedCode});

  final String selectedCode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 6, bottom: 8),
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择币种',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kBuiltInCurrencies.length,
                itemBuilder: (context, index) {
                  final c = kBuiltInCurrencies[index];
                  final selected = c.code == selectedCode;
                  return ListTile(
                    key: Key('currency_picker_${c.code}'),
                    leading: SizedBox(
                      width: 68,
                      child: Text(
                        c.symbol,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text('${c.code}  ·  ${c.name}'),
                    trailing: selected
                        ? Icon(Icons.check, color: colors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, c.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}