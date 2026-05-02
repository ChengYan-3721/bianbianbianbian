import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/util/currencies.dart';
import '../../core/util/quick_text_parser.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';
import '../budget/budget_providers.dart';
import '../settings/ai_input_settings_providers.dart';
import '../settings/settings_providers.dart';
import '../stats/stats_range_providers.dart';
import 'ai_input_enhance_service.dart';
import 'quick_input_providers.dart';
import 'record_providers.dart';

/// 一级分类的中文标签——与 `seeder.dart::categoriesByParent.keys` /
/// `budget_providers.dart::kParentKeyLabels` 同集，但本文件刻意复制一份
/// 而不 import 上层 feature——保持 record/quick 与 budget/ 的解耦。
const Map<String, String> _parentKeyLabels = {
  'income': '收入',
  'food': '餐饮',
  'shopping': '购物',
  'transport': '交通',
  'education': '教育',
  'entertainment': '娱乐',
  'social': '人情',
  'housing': '居家',
  'medical': '医疗',
  'investment': '投资',
  'other': '其他',
};

/// 一级分类在确认卡片 / picker 内的展示顺序——与记账页 `parentTabs` 顺序
/// 一致（食/购/行/育/乐/情/住/医/投/收/其），保证用户在首页快捷输入与
/// FAB 进入新建页时看到的分类组次序一致。
const List<String> _parentKeyOrder = [
  'food',
  'shopping',
  'transport',
  'education',
  'entertainment',
  'social',
  'housing',
  'medical',
  'investment',
  'income',
  'other',
];

/// 显示 Step 9.2 的"快速输入确认卡片"。
///
/// 返回 true 表示已成功保存为流水（首页应 invalidate 月度汇总刷新列表，
/// 但本函数内部已调用 `ref.invalidate(recordMonthSummaryProvider)`，外层
/// 可以仅靠返回值判断要不要清空输入框）；返回 false / null 表示用户取消。
Future<bool> showQuickConfirmSheet({
  required BuildContext context,
  required QuickParseResult parsed,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Material(
            color: Theme.of(sheetCtx).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: QuickConfirmCard(parsed: parsed),
            ),
          ),
        ),
      );
    },
  );
  return ok ?? false;
}

/// Step 9.2：本地解析后的"确认卡片"。
///
/// 卡片字段全部可编辑：金额 / 分类 / 时间 / 备注。点击"保存"时构造
/// [TransactionEntry] 并通过 [transactionRepositoryProvider] 写入，
/// 写入后 invalidate 首页月度汇总 + 统计 + 预算 provider。
///
/// 解析结果置信度低于 [quickConfidenceThreshold] 时顶部展示一条红色
/// "请核对"横幅；Step 9.3 LLM 增强按钮也将出现在同一区。
class QuickConfirmCard extends ConsumerStatefulWidget {
  const QuickConfirmCard({super.key, required this.parsed});

  final QuickParseResult parsed;

  @override
  ConsumerState<QuickConfirmCard> createState() => _QuickConfirmCardState();
}

class _QuickConfirmCardState extends ConsumerState<QuickConfirmCard> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String? _categoryId;
  String? _parentKey;
  late DateTime _occurredAt;
  bool _saving = false;
  bool _categoriesLoaded = false;
  List<Category> _categories = const [];
  bool _aiEnhancing = false;

  @override
  void initState() {
    super.initState();
    final p = widget.parsed;
    _amountController = TextEditingController(
      text: p.amount == null ? '' : _formatAmount(p.amount!),
    );
    _noteController = TextEditingController(text: p.note ?? '');
    _parentKey = p.categoryParentKey;

    // 时间：解析得到的日期 + "现在"的时分；解析未识别时回退到当前时间。
    // 测试通过 override `quickTextParserProvider` 注入固定时钟保证 occurredAt
    // 的日期部分稳定；时分会随真实时钟变化，因此 widget 测试只断言日期部分。
    final now = DateTime.now();
    final base = p.occurredAt;
    _occurredAt = base == null
        ? now
        : DateTime(base.year, base.month, base.day, now.hour, now.minute);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCategories();
    });
  }

  /// 把 `25.0` / `25.00` 格式化为 `25`，`25.50` 为 `25.5`，`25.55` 保持原样。
  /// 与 [RecordForm.preloadFromEntry] 的 normalize 风格一致。
  static String _formatAmount(double amount) {
    final s = amount.toStringAsFixed(2);
    if (s.endsWith('.00')) return s.substring(0, s.length - 3);
    if (s.endsWith('0')) return s.substring(0, s.length - 1);
    return s;
  }

  Future<void> _loadCategories() async {
    final repo = await ref.read(categoryRepositoryProvider.future);
    final cats = await repo.listActiveAll();
    cats.sort((a, b) {
      final aIdx = _parentKeyOrder.indexOf(a.parentKey);
      final bIdx = _parentKeyOrder.indexOf(b.parentKey);
      if (aIdx != bIdx) return aIdx.compareTo(bIdx);
      return a.sortOrder.compareTo(b.sortOrder);
    });
    if (!mounted) return;

    // Step 9.2 v2：在解析器给出的 parentKey 之外再做一次"实际二级分类名"
    // 精确匹配——用户的真实分类（含自定义命名）优先于固定关键词词典的兜底。
    //
    // 匹配规则：在 [QuickParseResult.rawText] 中按"二级分类名长度倒序"扫描
    // `contains`，命中即用该分类的 `id` + `parentKey` 覆盖解析器结果。例如
    //   - "午餐 20"：parser=food + 默认首个=早餐 → 二次匹配命中"午餐"
    //     subcategory → 改为 food/午餐。
    //   - "红包收入 200"：parser 的词典 `红包→social`（残余 note "收入"）
    //     → 二次匹配命中 income/红包 subcategory（最长精确匹配胜）→ 把
    //     parentKey 切到 income，并把"收入"（income 的 parent label）从
    //     note 剥离。
    //   - "红包支出 100"：二次匹配命中 social/红包支出（更长）→ social。
    //
    // 仅命中"分类自身名"才覆盖；命中不到则保留 parser parentKey + 默认
    // sortOrder=0 的兜底。
    final raw = widget.parsed.rawText;
    final byLengthDesc = [...cats]
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    Category? exactMatch;
    for (final c in byLengthDesc) {
      if (c.name.isEmpty) continue;
      if (raw.contains(c.name)) {
        exactMatch = c;
        break;
      }
    }

    setState(() {
      _categories = cats;
      _categoriesLoaded = true;
      if (exactMatch != null) {
        _categoryId = exactMatch.id;
        _parentKey = exactMatch.parentKey;
        // 同步把"覆盖后的 parent label"（如 income → "收入"）从 note 里剥
        // 离——原 parser 把"红包"判为 social 时，"收入"作为残余留在 note；
        // 一旦我们覆盖到 income，"收入"就该作为分类标签被吞掉，不再当备
        // 注。
        final parentLabel = _parentKeyLabels[exactMatch.parentKey];
        if (parentLabel != null) {
          final current = _noteController.text;
          if (current.contains(parentLabel)) {
            final cleaned = current
                .replaceAll(parentLabel, ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            _noteController.text = cleaned;
          }
        }
      } else if (_parentKey != null && _categoryId == null) {
        for (final c in cats) {
          if (c.parentKey == _parentKey) {
            _categoryId = c.id;
            break;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _parsedAmount {
    final txt = _amountController.text.trim();
    if (txt.isEmpty) return null;
    final v = double.tryParse(txt);
    if (v == null || v <= 0) return null;
    return v;
  }

  bool get _canSave => _parsedAmount != null && _categoryId != null;

  Category? get _selectedCategory {
    if (_categoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  Future<void> _pickCategory() async {
    if (!_categoriesLoaded) return;
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (_, controller) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Material(
                color: Theme.of(sheetCtx).colorScheme.surface,
                child: _CategoryPickerList(
                  categories: _categories,
                  scrollController: controller,
                  selectedId: _categoryId,
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _categoryId = picked.id;
        _parentKey = picked.parentKey;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _occurredAt.isAfter(now) ? now : _occurredAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
      locale: const Locale('zh', 'CN'),
      cancelText: '取消',
      confirmText: '确定',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
      cancelText: '取消',
      confirmText: '确定',
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      final amount = _parsedAmount!;
      final ledgerId = await ref.read(currentLedgerIdProvider.future);
      final ledgerCurrency =
          await ref.read(currentLedgerDefaultCurrencyProvider.future);
      // 同币种 → fxRate=1.0；快速输入暂不暴露币种切换，用账本默认币种保存。
      final tx = TransactionEntry(
        id: const Uuid().v4(),
        ledgerId: ledgerId,
        type: _parentKey == 'income' ? 'income' : 'expense',
        amount: amount,
        currency: ledgerCurrency,
        fxRate: 1.0,
        categoryId: _categoryId,
        accountId: null,
        toAccountId: null,
        occurredAt: _occurredAt,
        tags: () {
          final n = _noteController.text.trim();
          return n.isEmpty ? null : n;
        }(),
        attachmentsEncrypted: null,
        updatedAt: DateTime.now(),
        deviceId: '', // repo 会覆写
      );

      final txRepo = await ref.read(transactionRepositoryProvider.future);
      await txRepo.save(tx);

      ref.invalidate(recordMonthSummaryProvider);
      ref.invalidate(statsLinePointsProvider);
      ref.invalidate(statsPieSlicesProvider);
      ref.invalidate(statsRankItemsProvider);
      ref.invalidate(statsHeatmapCellsProvider);
      ref.invalidate(budgetProgressForProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Step 9.3：调用 LLM 增强本地解析。
  ///
  /// 失败语义：[AiEnhanceException] 一律 SnackBar 提示"AI 解析失败：$message"，
  /// 卡片字段保持本地解析的原值不变（implementation-plan §9.3 验证 2 "网络
  /// 失败回退本地结果"）。任何 schema 不符也走同分支（验证 3 "JSON 不符合
  /// schema 时不崩溃"）。
  ///
  /// 成功路径：用 LLM 返回的字段重写卡片——
  /// - amount 非 null → 改写 `_amountController`；
  /// - categoryParentKey 非 null → 切 `_parentKey`，并在 `_categories` 中选该
  ///   parent 下首个二级分类（与 `_loadCategories` 的兜底策略一致）；
  /// - occurredAt 非 null → 取日期 + 保留当前时分；
  /// - note 非 null → 改写 `_noteController`。
  Future<void> _runAiEnhance() async {
    if (_aiEnhancing) return;
    setState(() => _aiEnhancing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(aiInputEnhanceServiceProvider);
      final result = await service.enhance(widget.parsed.rawText);
      if (!mounted) return;
      setState(() {
        if (result.amount != null) {
          _amountController.text = _formatAmount(result.amount!);
        }
        if (result.categoryParentKey != null) {
          _parentKey = result.categoryParentKey;
          _categoryId = null;
          for (final c in _categories) {
            if (c.parentKey == result.categoryParentKey) {
              _categoryId = c.id;
              break;
            }
          }
        }
        if (result.occurredAt != null) {
          final d = result.occurredAt!;
          _occurredAt =
              DateTime(d.year, d.month, d.day, _occurredAt.hour, _occurredAt.minute);
        }
        if (result.note != null) {
          _noteController.text = result.note!;
        }
      });
      messenger.showSnackBar(const SnackBar(content: Text('AI 已更新')));
    } on AiEnhanceException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('AI 解析失败：${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('AI 解析失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _aiEnhancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parsed;
    final lowConfidence = p.confidence < quickConfidenceThreshold;
    final ledgerCurrency =
        ref.watch(currentLedgerDefaultCurrencyProvider).valueOrNull ?? 'CNY';
    final symbol = kBuiltInCurrencies
        .firstWhere(
          (c) => c.code == ledgerCurrency,
          orElse: () => kBuiltInCurrencies.first,
        )
        .symbol;
    final selectedCat = _selectedCategory;
    final color = Theme.of(context).colorScheme;

    // Step 9.3：AI 增强按钮显隐——必须 (低置信度) AND (用户已配置 AI)。
    // implementation-plan §9.3 验证 1 "没有配置 API 时按钮不显示" 由
    // [AiInputSettings.hasMinimalConfig] 守门：enabled + endpoint + key + model
    // 四件齐全才返回 true。
    final aiSettings =
        ref.watch(aiInputSettingsNotifierProvider).valueOrNull;
    final showAiButton =
        lowConfidence && (aiSettings?.hasMinimalConfig ?? false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '确认记一笔',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          if (lowConfidence)
            Container(
              key: const Key('quick_confirm_low_conf_banner'),
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE76F51).withAlpha(36),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE76F51).withAlpha(120),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFE76F51),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '识别置信度较低，请核对',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: const Color(0xFFE76F51),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (showAiButton) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: const Key('quick_confirm_ai_enhance_button'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE76F51),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _aiEnhancing ? null : _runAiEnhance,
                      icon: _aiEnhancing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('✨'),
                      label: Text(_aiEnhancing ? '解析中…' : 'AI 增强'),
                    ),
                  ],
                ],
              ),
            ),
          // 金额
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '金额',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color.onSurface.withAlpha(160),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('quick_confirm_amount_field'),
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      prefixText: '$symbol ',
                      isDense: true,
                      border: const UnderlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          // 分类
          InkWell(
            key: const Key('quick_confirm_category_row'),
            onTap: _categoriesLoaded ? _pickCategory : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '分类',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color.onSurface.withAlpha(160),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: selectedCat != null
                        ? Row(
                            children: [
                              Text(
                                selectedCat.icon ?? '🏷️',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_parentKeyLabels[selectedCat.parentKey] ?? '其他'} / ${selectedCat.name}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _categoriesLoaded ? '请选择' : '加载中…',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: color.onSurface.withAlpha(120),
                                ),
                          ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: color.onSurface.withAlpha(120),
                  ),
                ],
              ),
            ),
          ),
          // 时间
          InkWell(
            key: const Key('quick_confirm_time_row'),
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '时间',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color.onSurface.withAlpha(160),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatDateTime(_occurredAt),
                      key: const Key('quick_confirm_time_text'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: color.onSurface.withAlpha(120),
                  ),
                ],
              ),
            ),
          ),
          // 备注
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '备注',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color.onSurface.withAlpha(160),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('quick_confirm_note_field'),
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: '可留空',
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('quick_confirm_save_button'),
                  onPressed: _canSave && !_saving ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 分类选择器内层——纵向 ListView，按一级分类分组。
class _CategoryPickerList extends StatelessWidget {
  const _CategoryPickerList({
    required this.categories,
    required this.scrollController,
    required this.selectedId,
  });

  final List<Category> categories;
  final ScrollController scrollController;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Category>>{};
    for (final c in categories) {
      grouped.putIfAbsent(c.parentKey, () => []).add(c);
    }
    final orderedKeys = _parentKeyOrder
        .where((k) => grouped.containsKey(k))
        .toList(growable: false);
    final color = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '选择分类',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: scrollController,
            children: [
              for (final pk in orderedKeys) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    _parentKeyLabels[pk] ?? pk,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color.onSurface.withAlpha(160),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                for (final c in grouped[pk]!)
                  ListTile(
                    key: Key('quick_confirm_picker_${c.id}'),
                    leading: Text(
                      c.icon ?? '🏷️',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(c.name),
                    trailing: c.id == selectedId
                        ? Icon(Icons.check, color: color.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(c),
                  ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
