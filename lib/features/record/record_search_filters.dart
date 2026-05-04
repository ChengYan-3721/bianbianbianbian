import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';

/// Step 3.6：搜索筛选所支持的流水类型。
enum SearchTypeFilter {
  /// 全部（含 income / expense / transfer）。
  all,

  /// 仅支出。
  expense,

  /// 仅收入。
  income,

  /// 仅转账。
  transfer,
}

/// Step 3.6：搜索查询条件。所有字段都是可选——空字符串关键词、null 边界、
/// [SearchTypeFilter.all] 都视为"不约束该维度"。
class SearchQuery {
  const SearchQuery({
    this.keyword = '',
    this.startDate,
    this.endDate,
    this.typeFilter = SearchTypeFilter.all,
    this.minAmount,
    this.maxAmount,
  });

  final String keyword;

  /// 起始日期（按日比较，含本日）。
  final DateTime? startDate;

  /// 结束日期（按日比较，含本日）。
  final DateTime? endDate;

  final SearchTypeFilter typeFilter;

  /// 金额下限（含）。绝对值比较——支出 / 收入都用正数。
  final double? minAmount;

  /// 金额上限（含）。
  final double? maxAmount;

  SearchQuery copyWith({
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
    SearchTypeFilter? typeFilter,
    double? minAmount,
    double? maxAmount,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
  }) {
    return SearchQuery(
      keyword: keyword ?? this.keyword,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      typeFilter: typeFilter ?? this.typeFilter,
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
    );
  }

  /// 是否所有条件都是空——纯空查询时搜索页应当避免一次性把全部流水砸到屏幕上，
  /// 改为提示"输入关键词或筛选条件后开始搜索"。
  bool get isEmpty =>
      keyword.trim().isEmpty &&
      startDate == null &&
      endDate == null &&
      typeFilter == SearchTypeFilter.all &&
      minAmount == null &&
      maxAmount == null;
}

/// Step 3.6：核心搜索过滤函数（纯函数，便于单测）。
///
/// 关键词匹配（不区分大小写，全部命中即可，不做分词）：
/// 1. 流水的备注（drift 层为 `tags` 列；UI 中作为"备注"展示）；
/// 2. 流水所属**二级分类**的名称（[categories] 中通过 `tx.categoryId` 反查）；
/// 3. 流水所属**一级分类**的中文标签（通过 [parentKeyLabels] 把
///    `cat.parentKey` 翻译为"餐饮 / 购物 / 收入 ..."；同时也允许直接命中
///    parent key 字符串本身，方便英文关键词搜索）；
/// 4. 流水所属账户的名称（[accounts] 中通过 `tx.accountId` 反查；转账还会附加
///    `toAccountId` 命中）。
///
/// 其它筛选维度都按"取交集"语义（AND）：
/// - [SearchQuery.startDate] / [SearchQuery.endDate] 闭区间（按 [TransactionEntry.occurredAt] 的日期分量比较）；
/// - [SearchQuery.typeFilter] 命中 type 字段；
/// - [SearchQuery.minAmount] / [SearchQuery.maxAmount] 用金额绝对值闭区间。
///
/// [parentKeyLabels]：一级分类 key → 中文标签的字典。调用方注入（V1 复用
/// `budget_providers.dart::kParentKeyLabels`），不在本文件硬编码——保持
/// `record_search_filters` 是纯领域过滤函数、不依赖其它 feature 的常量。
///
/// 不会修改入参，不会触达 IO。结果保留输入顺序——调用方自行决定排序（搜索页
/// 默认按 occurredAt 倒序展示）。
List<TransactionEntry> searchTransactions({
  required List<TransactionEntry> transactions,
  required List<Category> categories,
  required List<Account> accounts,
  required SearchQuery query,
  Map<String, String> parentKeyLabels = const <String, String>{},
}) {
  if (query.isEmpty) {
    // 调用方预期空查询不返回结果（搜索页 UI 据此显示"开始搜索"提示）。
    return const [];
  }

  // 反查表——避免在循环里反复 O(N) 找。
  final categoryById = <String, Category>{
    for (final c in categories) c.id: c,
  };
  final accountById = <String, Account>{
    for (final a in accounts) a.id: a,
  };

  final keyword = query.keyword.trim().toLowerCase();
  final start = query.startDate == null
      ? null
      : DateTime(
          query.startDate!.year,
          query.startDate!.month,
          query.startDate!.day,
        );
  final end = query.endDate == null
      ? null
      : DateTime(
          query.endDate!.year,
          query.endDate!.month,
          query.endDate!.day,
          23,
          59,
          59,
          999,
        );

  bool matchKeyword(TransactionEntry tx) {
    if (keyword.isEmpty) return true;
    // 备注（drift `tags` 列）。
    final note = tx.tags;
    if (note != null && note.toLowerCase().contains(keyword)) return true;
    // 二级分类名 + 一级分类标签（中文）+ 一级分类 key（英文）。
    // 一级分类不落库，仅以 [parentKey] 字符串关联——所以通过 [parentKeyLabels]
    // 反查中文展示名。同时保留对 parent key 字面量的匹配，确保用户输入
    // "food" 也能命中"餐饮"下的所有流水（开发自用 / 英文搜索场景）。
    final cat = tx.categoryId == null ? null : categoryById[tx.categoryId!];
    if (cat != null) {
      if (cat.name.toLowerCase().contains(keyword)) return true;
      final parentLabel = parentKeyLabels[cat.parentKey];
      if (parentLabel != null &&
          parentLabel.toLowerCase().contains(keyword)) {
        return true;
      }
      if (cat.parentKey.toLowerCase().contains(keyword)) return true;
    }
    // 账户名（转出 / 转入双侧均比对）。
    final acc = tx.accountId == null ? null : accountById[tx.accountId!];
    if (acc != null && acc.name.toLowerCase().contains(keyword)) return true;
    final toAcc = tx.toAccountId == null ? null : accountById[tx.toAccountId!];
    if (toAcc != null && toAcc.name.toLowerCase().contains(keyword)) {
      return true;
    }
    return false;
  }

  bool matchDate(TransactionEntry tx) {
    if (start != null && tx.occurredAt.isBefore(start)) return false;
    if (end != null && tx.occurredAt.isAfter(end)) return false;
    return true;
  }

  bool matchType(TransactionEntry tx) {
    switch (query.typeFilter) {
      case SearchTypeFilter.all:
        return true;
      case SearchTypeFilter.expense:
        return tx.type == 'expense';
      case SearchTypeFilter.income:
        return tx.type == 'income';
      case SearchTypeFilter.transfer:
        return tx.type == 'transfer';
    }
  }

  bool matchAmount(TransactionEntry tx) {
    final v = tx.amount.abs();
    if (query.minAmount != null && v < query.minAmount!) return false;
    if (query.maxAmount != null && v > query.maxAmount!) return false;
    return true;
  }

  return transactions
      .where((tx) =>
          matchKeyword(tx) &&
          matchDate(tx) &&
          matchType(tx) &&
          matchAmount(tx))
      .toList(growable: false);
}
