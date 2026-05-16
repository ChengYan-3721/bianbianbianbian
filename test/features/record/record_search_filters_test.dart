import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/record/record_search_filters.dart';

/// Step 3.6 验证：流水搜索过滤纯函数。
///
/// 把"取数 + 过滤"切成两段——本测试覆盖纯过滤段（无 IO），所以可以用 Dart
/// 内存对象驱动；UI 层的 widget 测试会在另一个文件覆盖（`record_search_page_test`）。
TransactionEntry _tx({
  required String id,
  String type = 'expense',
  double amount = 30,
  DateTime? occurredAt,
  String? categoryId,
  String? accountId,
  String? toAccountId,
  String? note,
}) {
  return TransactionEntry(
    id: id,
    ledgerId: 'L1',
    type: type,
    amount: amount,
    currency: 'CNY',
    categoryId: categoryId,
    accountId: accountId,
    toAccountId: toAccountId,
    occurredAt: occurredAt ?? DateTime(2026, 5, 1, 12, 0),
    tags: note,
    updatedAt: occurredAt ?? DateTime(2026, 5, 1, 12, 0),
    deviceId: 'dev',
  );
}

Category _cat(String id, String name, {String parentKey = 'food'}) {
  return Category(
    id: id,
    name: name,
    parentKey: parentKey,
    updatedAt: DateTime(2026, 5, 1),
    deviceId: 'dev',
  );
}

Account _acc(String id, String name) {
  return Account(
    id: id,
    name: name,
    type: 'cash',
    updatedAt: DateTime(2026, 5, 1),
    deviceId: 'dev',
  );
}

void main() {
  group('searchTransactions', () {
    test('空查询返回空列表（不把全部流水砸到屏幕上）', () {
      final result = searchTransactions(
        transactions: [_tx(id: 'a')],
        categories: const [],
        accounts: const [],
        query: const SearchQuery(),
      );
      expect(result, isEmpty);
    });

    test('关键词匹配备注：搜索"午餐"命中备注为"和同事的午餐"的流水', () {
      final txs = [
        _tx(id: 't1', note: '和同事的午餐'),
        _tx(id: 't2', note: '打车'),
      ];
      final result = searchTransactions(
        transactions: txs,
        categories: const [],
        accounts: const [],
        query: const SearchQuery(keyword: '午餐'),
      );
      expect(result.map((e) => e.id), ['t1']);
    });

    test('关键词匹配分类名', () {
      final cat = _cat('c1', '餐饮');
      final txs = [
        _tx(id: 't1', categoryId: 'c1'),
        _tx(id: 't2'),
      ];
      final result = searchTransactions(
        transactions: txs,
        categories: [cat],
        accounts: const [],
        query: const SearchQuery(keyword: '餐饮'),
      );
      expect(result.map((e) => e.id), ['t1']);
    });

    test('关键词匹配一级分类中文标签：搜"餐饮" 命中所有 parentKey=food 的流水', () {
      // 二级分类名是"早餐"/"午餐"——不含"餐饮"二字；但通过一级标签
      // food → "餐饮" 应该都能命中。
      final breakfast = _cat('c1', '早餐', parentKey: 'food');
      final lunch = _cat('c2', '午餐', parentKey: 'food');
      final clothes = _cat('c3', '衣服', parentKey: 'shopping');
      final txs = [
        _tx(id: 't1', categoryId: 'c1'),
        _tx(id: 't2', categoryId: 'c2'),
        _tx(id: 't3', categoryId: 'c3'),
      ];
      final result = searchTransactions(
        transactions: txs,
        categories: [breakfast, lunch, clothes],
        accounts: const [],
        query: const SearchQuery(keyword: '餐饮'),
        parentKeyLabels: const {
          'food': '餐饮',
          'shopping': '购物',
        },
      );
      expect(result.map((e) => e.id).toSet(), {'t1', 't2'});
    });

    test('关键词匹配一级分类英文 key：搜"food" 命中', () {
      final breakfast = _cat('c1', '早餐', parentKey: 'food');
      final clothes = _cat('c2', '衣服', parentKey: 'shopping');
      final txs = [
        _tx(id: 't1', categoryId: 'c1'),
        _tx(id: 't2', categoryId: 'c2'),
      ];
      final result = searchTransactions(
        transactions: txs,
        categories: [breakfast, clothes],
        accounts: const [],
        query: const SearchQuery(keyword: 'food'),
        parentKeyLabels: const {
          'food': '餐饮',
          'shopping': '购物',
        },
      );
      expect(result.map((e) => e.id), ['t1']);
    });

    test('关键词匹配账户名（含转账目标账户）', () {
      final accs = [_acc('a1', '招行储蓄'), _acc('a2', '工商信用卡')];
      final txs = [
        _tx(id: 't1', accountId: 'a1'),
        _tx(id: 't2', accountId: 'a2'),
        _tx(
          id: 't3',
          type: 'transfer',
          accountId: 'a1',
          toAccountId: 'a2',
        ),
      ];
      final result = searchTransactions(
        transactions: txs,
        categories: const [],
        accounts: accs,
        query: const SearchQuery(keyword: '工商'),
      );
      // t2 通过 accountId 命中；t3 通过 toAccountId 命中。
      expect(result.map((e) => e.id).toSet(), {'t2', 't3'});
    });

    test('关键词大小写不敏感', () {
      final txs = [_tx(id: 't1', note: 'Coffee')];
      final result = searchTransactions(
        transactions: txs,
        categories: const [],
        accounts: const [],
        query: const SearchQuery(keyword: 'coffee'),
      );
      expect(result.map((e) => e.id), ['t1']);
    });

    test('日期范围闭区间（含起止两端）', () {
      final txs = [
        _tx(id: 't1', occurredAt: DateTime(2026, 5, 1, 23, 59)),
        _tx(id: 't2', occurredAt: DateTime(2026, 5, 5, 0, 0)),
        _tx(id: 't3', occurredAt: DateTime(2026, 5, 6, 12, 0)),
        _tx(id: 't4', occurredAt: DateTime(2026, 4, 30, 23, 0)),
      ];
      final result = searchTransactions(
        transactions: txs,
        categories: const [],
        accounts: const [],
        query: SearchQuery(
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 5),
        ),
      );
      expect(result.map((e) => e.id).toSet(), {'t1', 't2'});
    });

    test('类型筛选：仅支出', () {
      final txs = [
        _tx(id: 't1', type: 'expense'),
        _tx(id: 't2', type: 'income'),
        _tx(id: 't3', type: 'transfer', accountId: 'a', toAccountId: 'b'),
      ];
      // 加 startDate 让 query 非空。
      final result = searchTransactions(
        transactions: txs,
        categories: const [],
        accounts: const [],
        query: SearchQuery(
          typeFilter: SearchTypeFilter.expense,
          startDate: DateTime(2020),
          endDate: DateTime(2030),
        ),
      );
      expect(result.map((e) => e.id), ['t1']);
    });

    test('金额范围 100-200 命中范围内流水', () {
      final txs = [
        _tx(id: 't1', amount: 50),
        _tx(id: 't2', amount: 100),
        _tx(id: 't3', amount: 150),
        _tx(id: 't4', amount: 200),
        _tx(id: 't5', amount: 250),
      ];
      final result = searchTransactions(
        transactions: txs,
        categories: const [],
        accounts: const [],
        query: const SearchQuery(minAmount: 100, maxAmount: 200),
      );
      expect(result.map((e) => e.id).toSet(), {'t2', 't3', 't4'});
    });

    test('多维度取交集：关键词 + 日期 + 金额 + 类型', () {
      final txs = [
        _tx(
          id: 'hit',
          type: 'expense',
          amount: 150,
          occurredAt: DateTime(2026, 5, 5),
          note: '团建聚餐',
        ),
        _tx(
          id: 'wrongType',
          type: 'income',
          amount: 150,
          occurredAt: DateTime(2026, 5, 5),
          note: '团建聚餐',
        ),
        _tx(
          id: 'wrongAmount',
          type: 'expense',
          amount: 50,
          occurredAt: DateTime(2026, 5, 5),
          note: '团建聚餐',
        ),
        _tx(
          id: 'wrongDate',
          type: 'expense',
          amount: 150,
          occurredAt: DateTime(2026, 4, 30),
          note: '团建聚餐',
        ),
        _tx(
          id: 'wrongKeyword',
          type: 'expense',
          amount: 150,
          occurredAt: DateTime(2026, 5, 5),
          note: '打车',
        ),
      ];
      final result = searchTransactions(
        transactions: txs,
        categories: const [],
        accounts: const [],
        query: SearchQuery(
          keyword: '聚餐',
          typeFilter: SearchTypeFilter.expense,
          minAmount: 100,
          maxAmount: 200,
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 31),
        ),
      );
      expect(result.map((e) => e.id), ['hit']);
    });

    test('SearchQuery.copyWith 支持 clear 标志位置空', () {
      const q = SearchQuery(
        keyword: 'x',
        minAmount: 10,
        maxAmount: 100,
      );
      final cleared = q.copyWith(clearMinAmount: true, clearMaxAmount: true);
      expect(cleared.keyword, 'x');
      expect(cleared.minAmount, isNull);
      expect(cleared.maxAmount, isNull);
    });

    test('SearchQuery.isEmpty 仅空白关键词 + 默认 type → true', () {
      expect(const SearchQuery().isEmpty, isTrue);
      expect(const SearchQuery(keyword: '   ').isEmpty, isTrue);
      expect(
        const SearchQuery(typeFilter: SearchTypeFilter.expense).isEmpty,
        isFalse,
      );
    });
  });
}
