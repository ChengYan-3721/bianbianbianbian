import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';
import '../budget/budget_providers.dart' show kParentKeyLabels;
import 'record_search_filters.dart';
import 'record_tile_actions.dart';

/// Step 3.6：流水搜索页 `/record/search`。
///
/// **数据来源**：当前账本（`currentLedgerIdProvider`）下全部未软删流水
/// 一次性拉取（V1 数据量小，全在内存里过滤；后续可改为 SQL 端过滤）。
///
/// **筛选维度**：关键词（备注 / 分类名 / 账户名）+ 日期范围 + 类型
/// （全部 / 支出 / 收入 / 转账）+ 金额范围。所有维度取交集（AND）。
///
/// **空查询**：所有条件均空时不返回结果，UI 展示"输入条件开始搜索"提示，
/// 避免一打开页面就把整本账本砸到屏幕上。
class RecordSearchPage extends ConsumerStatefulWidget {
  const RecordSearchPage({super.key});

  @override
  ConsumerState<RecordSearchPage> createState() => _RecordSearchPageState();
}

class _RecordSearchPageState extends ConsumerState<RecordSearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  /// 关键词 / 金额下限 / 金额上限三个 TextField 的显式 FocusNode。
  ///
  /// 点击搜索结果打开详情底部表单 → 编辑/复制表单或删除对话框这条链路里，
  /// 第一个底部表单 pop 时上层 FocusScope 会把焦点还给最近聚焦过的 TextField
  /// （通常就是关键词输入框），紧接着第二个模态还没起来——这一两帧里键盘
  /// 会被瞬间唤起又收起，肉眼可见地抖一下。
  ///
  /// 解法：在 onTap 进入交互链时把这三个 FocusNode 的 [FocusNode.canRequestFocus]
  /// 标为 false，模态 pop 后 FocusScope 想恢复焦点也无路可走，会自动 fall back
  /// 到 FocusScope 自身（不持有键盘连接），抖动消失。整条链路结束后再恢复。
  final FocusNode _keywordFocus = FocusNode();
  final FocusNode _minAmountFocus = FocusNode();
  final FocusNode _maxAmountFocus = FocusNode();

  SearchQuery _query = const SearchQuery();
  bool _filtersExpanded = false;

  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  static final NumberFormat _amountFmt = NumberFormat('#,##0.00');

  @override
  void dispose() {
    _keywordController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _keywordFocus.dispose();
    _minAmountFocus.dispose();
    _maxAmountFocus.dispose();
    super.dispose();
  }

  /// 进入详情底部表单 / 编辑表单 / 删除对话框等模态前调用：先把当前主焦点
  /// 退掉（让键盘立刻收起），再禁掉三个搜索框的可聚焦能力。这样模态 pop
  /// 时 FocusScope 想把焦点还给最近聚焦的 TextField 也会被拒绝，键盘不会
  /// 再被瞬间唤起。
  ///
  /// 顺序很重要：先 unfocus 后置 canRequestFocus，避免 setter 内部以
  /// `previouslyFocusedChild` 走向另一个 TextField（同样会被禁掉，但能少一次
  /// 焦点切换）。
  void _disableSearchFieldFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    _keywordFocus.canRequestFocus = false;
    _minAmountFocus.canRequestFocus = false;
    _maxAmountFocus.canRequestFocus = false;
  }

  /// 全部模态关闭后恢复，用户后续再点击搜索框才能正常聚焦输入。
  void _enableSearchFieldFocus() {
    _keywordFocus.canRequestFocus = true;
    _minAmountFocus.canRequestFocus = true;
    _maxAmountFocus.canRequestFocus = true;
  }

  void _onKeywordChanged(String v) {
    setState(() {
      _query = _query.copyWith(keyword: v);
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = DateTimeRange(
      start: _query.startDate ?? DateTime(now.year, now.month, 1),
      end: _query.endDate ?? now,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      locale: const Locale('zh', 'CN'),
    );
    if (picked == null) return;
    setState(() {
      _query = _query.copyWith(
        startDate: picked.start,
        endDate: picked.end,
      );
    });
  }

  void _clearDateRange() {
    setState(() {
      _query = _query.copyWith(
        clearStartDate: true,
        clearEndDate: true,
      );
    });
  }

  void _setTypeFilter(SearchTypeFilter f) {
    setState(() => _query = _query.copyWith(typeFilter: f));
  }

  void _onMinAmountChanged(String v) {
    final parsed = double.tryParse(v.trim());
    setState(() {
      _query = parsed == null
          ? _query.copyWith(clearMinAmount: true)
          : _query.copyWith(minAmount: parsed);
    });
  }

  void _onMaxAmountChanged(String v) {
    final parsed = double.tryParse(v.trim());
    setState(() {
      _query = parsed == null
          ? _query.copyWith(clearMaxAmount: true)
          : _query.copyWith(maxAmount: parsed);
    });
  }

  void _resetAllFilters() {
    _keywordController.clear();
    _minAmountController.clear();
    _maxAmountController.clear();
    setState(() {
      _query = const SearchQuery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ledgerIdAsync = ref.watch(currentLedgerIdProvider);
    final txRepoAsync = ref.watch(transactionRepositoryProvider);
    final catRepoAsync = ref.watch(categoryRepositoryProvider);
    final accRepoAsync = ref.watch(accountRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索流水'),
        actions: [
          IconButton(
            tooltip: '重置',
            onPressed: _resetAllFilters,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('search_keyword_field'),
              controller: _keywordController,
              focusNode: _keywordFocus,
              autofocus: true,
              onChanged: _onKeywordChanged,
              decoration: InputDecoration(
                hintText: '关键词（备注 / 分类 / 账户）',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _query.keyword.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _keywordController.clear();
                          _onKeywordChanged('');
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ExpansionTile(
              key: const Key('search_filters_expansion'),
              initiallyExpanded: _filtersExpanded,
              onExpansionChanged: (v) => setState(() => _filtersExpanded = v),
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                '筛选',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withAlpha(180),
                    ),
              ),
              children: [
                _buildDateRangeRow(),
                const SizedBox(height: 8),
                _buildTypeRow(),
                const SizedBox(height: 8),
                _buildAmountRow(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _ResultsView(
              query: _query,
              ledgerIdAsync: ledgerIdAsync,
              txRepoAsync: txRepoAsync,
              catRepoAsync: catRepoAsync,
              accRepoAsync: accRepoAsync,
              dateFmt: _dateFmt,
              amountFmt: _amountFmt,
              onActionStart: _disableSearchFieldFocus,
              onActionEnd: _enableSearchFieldFocus,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildDateRangeRow() {
    final start = _query.startDate;
    final end = _query.endDate;
    final label = (start == null || end == null)
        ? '不限日期'
        : '${_dateFmt.format(start)} ~ ${_dateFmt.format(end)}';
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            '日期',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('search_date_button'),
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(label, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        if (start != null && end != null)
          IconButton(
            tooltip: '清空日期',
            onPressed: _clearDateRange,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildTypeRow() {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            '类型',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: SegmentedButton<SearchTypeFilter>(
            segments: const [
              ButtonSegment(
                value: SearchTypeFilter.all,
                label: Text('全部'),
              ),
              ButtonSegment(
                value: SearchTypeFilter.expense,
                label: Text('支出'),
              ),
              ButtonSegment(
                value: SearchTypeFilter.income,
                label: Text('收入'),
              ),
              ButtonSegment(
                value: SearchTypeFilter.transfer,
                label: Text('转账'),
              ),
            ],
            selected: {_query.typeFilter},
            onSelectionChanged: (s) => _setTypeFilter(s.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow() {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            '金额',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: TextField(
            key: const Key('search_min_amount_field'),
            controller: _minAmountController,
            focusNode: _minAmountFocus,
            onChanged: _onMinAmountChanged,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '下限',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('~'),
        ),
        Expanded(
          child: TextField(
            key: const Key('search_max_amount_field'),
            controller: _maxAmountController,
            focusNode: _maxAmountFocus,
            onChanged: _onMaxAmountChanged,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '上限',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

/// 结果列表视图。把"取数 + 过滤 + 排序 + 渲染"集中在这里，主页面只负责
/// filter UI——`SearchQuery` 由父级 setState 注入，子级 `FutureBuilder` 拼装
/// 数据，避免在 `_RecordSearchPageState` 内自己写一堆 async 状态机。
class _ResultsView extends ConsumerStatefulWidget {
  const _ResultsView({
    required this.query,
    required this.ledgerIdAsync,
    required this.txRepoAsync,
    required this.catRepoAsync,
    required this.accRepoAsync,
    required this.dateFmt,
    required this.amountFmt,
    required this.onActionStart,
    required this.onActionEnd,
  });

  final SearchQuery query;
  final AsyncValue<String> ledgerIdAsync;
  final AsyncValue<dynamic> txRepoAsync;
  final AsyncValue<dynamic> catRepoAsync;
  final AsyncValue<dynamic> accRepoAsync;
  final DateFormat dateFmt;
  final NumberFormat amountFmt;

  /// 由 [_RecordSearchPageState] 注入：进入 / 退出详情底部表单交互链路时禁用
  /// 或恢复搜索 TextField 的 [FocusNode.canRequestFocus]，避免模态切换之间
  /// 键盘瞬闪。详细原理见 [_RecordSearchPageState._disableSearchFieldFocus]。
  final VoidCallback onActionStart;
  final VoidCallback onActionEnd;

  @override
  ConsumerState<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends ConsumerState<_ResultsView> {
  /// 在每次 build 时给 FutureBuilder 一个新 key 时会强制重拉数据。Step 3.6
  /// 续：编辑/复制/删除后调 [_refreshTick]++ → 触发重新 `_loadAndSearch`，
  /// 让搜索结果立即反映出新写入的流水（编辑后金额变化、删除后从列表消失）。
  int _refreshTick = 0;

  void _bumpRefresh() {
    if (!mounted) return;
    setState(() => _refreshTick++);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isEmpty) {
      return _buildHint(
        context,
        icon: Icons.search,
        text: '输入关键词或筛选条件后开始搜索',
      );
    }

    final ledgerId = widget.ledgerIdAsync.valueOrNull;
    final txRepo = widget.txRepoAsync.valueOrNull;
    final catRepo = widget.catRepoAsync.valueOrNull;
    final accRepo = widget.accRepoAsync.valueOrNull;
    if (ledgerId == null ||
        txRepo == null ||
        catRepo == null ||
        accRepo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<_SearchData>(
      // key 用 query + tick 拼装：query 改变 / 编辑后强制刷新都会替换 key，
      // 触发 FutureBuilder 丢弃旧 future 重新拉取。
      key: ValueKey(Object.hash(
        widget.query.keyword,
        widget.query.startDate,
        widget.query.endDate,
        widget.query.typeFilter,
        widget.query.minAmount,
        widget.query.maxAmount,
        _refreshTick,
      )),
      future: _loadAndSearch(
        ledgerId: ledgerId,
        txRepo: txRepo,
        catRepo: catRepo,
        accRepo: accRepo,
        query: widget.query,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.results.isEmpty) {
          return _buildHint(
            context,
            icon: Icons.sentiment_dissatisfied,
            text: '没有找到相关流水',
          );
        }
        return ListView.builder(
          // 用户拖动结果列表时让 keyword / min / max 三个 TextField 自动失焦，
          // 配合点击结果时的 unfocus，确保输入框不会"粘住"键盘。
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: data.results.length,
          itemBuilder: (_, i) => _ResultTile(
            tx: data.results[i],
            data: data,
            amountFmt: widget.amountFmt,
            dateFmt: widget.dateFmt,
            onChanged: _bumpRefresh,
            onActionStart: widget.onActionStart,
            onActionEnd: widget.onActionEnd,
          ),
        );
      },
    );
  }

  static Future<_SearchData> _loadAndSearch({
    required String ledgerId,
    required dynamic txRepo,
    required dynamic catRepo,
    required dynamic accRepo,
    required SearchQuery query,
  }) async {
    final txs = await txRepo.listActiveByLedger(ledgerId) as List<TransactionEntry>;
    final cats = await catRepo.listActiveAll() as List<Category>;
    final accs = await accRepo.listActive() as List<Account>;
    final results = searchTransactions(
      transactions: txs,
      categories: cats,
      accounts: accs,
      query: query,
      // 一级分类是常量、不落库——这里把 key→中文标签字典注入过滤器，
      // 让"餐饮 / 购物 / 收入"这种一级分类名也能命中。
      parentKeyLabels: kParentKeyLabels,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final categoryById = <String, Category>{
      for (final c in cats) c.id: c,
    };
    final accountById = <String, Account>{
      for (final a in accs) a.id: a,
    };
    return _SearchData(
      results: results,
      categoryById: categoryById,
      accountById: accountById,
    );
  }

  Widget _buildHint(BuildContext context,
      {required IconData icon, required String text}) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: colors.primary.withAlpha(140)),
          const SizedBox(height: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withAlpha(160),
                ),
          ),
        ],
      ),
    );
  }
}

class _SearchData {
  const _SearchData({
    required this.results,
    required this.categoryById,
    required this.accountById,
  });

  final List<TransactionEntry> results;
  final Map<String, Category> categoryById;
  final Map<String, Account> accountById;
}

class _ResultTile extends ConsumerWidget {
  const _ResultTile({
    required this.tx,
    required this.data,
    required this.amountFmt,
    required this.dateFmt,
    required this.onChanged,
    required this.onActionStart,
    required this.onActionEnd,
  });

  final TransactionEntry tx;
  final _SearchData data;
  final NumberFormat amountFmt;
  final DateFormat dateFmt;

  /// 编辑 / 复制 / 删除完成后回调，由 `_ResultsView` 用于刷新搜索结果列表
  /// （绕过 Riverpod，因为搜索数据是 page-local FutureBuilder 拉取，不在
  /// `recordMonthSummaryProvider` 等 provider 链上）。
  final VoidCallback onChanged;

  /// 打开 / 关闭详情底部表单整条交互链时的钩子：分别由 [_RecordSearchPageState]
  /// 的 `_disableSearchFieldFocus` / `_enableSearchFieldFocus` 实现，用于禁用 /
  /// 恢复搜索 TextField 的可聚焦能力，避免详情表单 pop 后第二个模态尚未弹起
  /// 之间的一帧里键盘瞬闪。
  final VoidCallback onActionStart;
  final VoidCallback onActionEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = tx.type == 'transfer';
    final isExpense = tx.type == 'expense';
    final sign = isTransfer ? '' : (isExpense ? '-' : '+');
    final amountColor = isTransfer
        ? const Color(0xFF6C8CC8)
        : (isExpense ? const Color(0xFFE76F51) : const Color(0xFFA8D8B9));

    final cat = tx.categoryId == null ? null : data.categoryById[tx.categoryId!];
    final iconText = isTransfer
        ? '🔁'
        : (cat?.icon ?? (isExpense ? '💸' : '💰'));
    final name = isTransfer ? '转账' : (cat?.name ?? '未分类');

    final acc = tx.accountId == null ? null : data.accountById[tx.accountId!];
    final accName = acc?.name ?? '账户';
    final toAcc =
        tx.toAccountId == null ? null : data.accountById[tx.toAccountId!];
    final toAccName = toAcc?.name;
    final note = tx.tags;
    final subtitleParts = <String>[
      dateFmt.format(tx.occurredAt),
      accName,
      if (note != null && note.isNotEmpty) note,
    ];

    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        backgroundColor: amountColor.withAlpha(36),
        child: Text(iconText, style: const TextStyle(fontSize: 16)),
      ),
      title: Text(name),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
      ),
      trailing: Text(
        '$sign${amountFmt.format(tx.amount)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
      ),
      // Step 3.6 续：搜索结果点击复用首页流水 tile 的「详情底部表单 → 编辑 /
      // 复制 / 删除」交互。完成后 `onChanged` 触发 _ResultsView 重拉数据。
      onTap: () async {
        // 关键词 / 金额下限 / 金额上限三个 TextField 在用户点击结果项时
        // 应该让出焦点——否则键盘 + 详情底部表单会同时占屏，体验割裂。
        // 进一步把它们的 canRequestFocus 标为 false：详情表单 pop 后会
        // 触发上层 FocusScope 把焦点还给最近聚焦过的 TextField（通常是
        // 关键词输入框），紧接着的编辑表单 / 删除对话框还没起来时，
        // 键盘会被瞬间唤起又收起。禁用聚焦能力直到整条交互链结束就能
        // 彻底拦掉这一帧抖动。`finally` 保证异常 / 用户手势取消时也能恢复。
        onActionStart();
        try {
          await openRecordTileActions(
            context: context,
            ref: ref,
            tx: tx,
            category: cat,
            accountName: accName,
            toAccountName: toAccName,
            parentKey: inferParentKeyForTx(cat, tx),
          );
        } finally {
          onActionEnd();
        }
        onChanged();
      },
    );
  }
}
