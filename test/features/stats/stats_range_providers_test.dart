import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/stats/stats_range_providers.dart';

void main() {
  test('thisMonth / lastMonth / thisYear preset produce expected ranges', () {
    final now = DateTime(2026, 1, 15, 10, 20, 30);

    final thisMonth = StatsDateRange.month(now);
    expect(thisMonth.start, DateTime(2026, 1, 1));
    expect(thisMonth.end, DateTime(2026, 1, 31, 23, 59, 59, 999, 999));

    final lastMonth = StatsDateRange.month(DateTime(now.year, now.month - 1, 1));
    expect(lastMonth.start, DateTime(2025, 12, 1));
    expect(lastMonth.end, DateTime(2025, 12, 31, 23, 59, 59, 999, 999));

    final thisYear = StatsDateRange.year(now);
    expect(thisYear.start, DateTime(2026, 1, 1));
    expect(thisYear.end, DateTime(2026, 12, 31, 23, 59, 59, 999, 999));
  });

  test('custom normalize handles cross-year and reversed inputs', () {
    final a = DateTime(2026, 1, 3, 20, 30);
    final b = DateTime(2025, 12, 29, 1, 2);

    final range = StatsDateRange.normalize(a, b);
    expect(range.start, DateTime(2025, 12, 29));
    expect(range.end, DateTime(2026, 1, 3, 23, 59, 59, 999, 999));
  });

  // --- Pie aggregation helpers ---

  final testStart = DateTime(2026, 4, 1);
  final testEnd = DateTime(2026, 4, 30, 23, 59, 59, 999, 999);

  TransactionEntry makeTx({
    String id = 'tx-a',
    String type = 'expense',
    double amount = 10,
    String? categoryId = 'cat-1',
    DateTime? occurredAt,
  }) {
    return TransactionEntry(
      id: id,
      ledgerId: 'ledger-1',
      type: type,
      amount: amount,
      currency: 'CNY',
      categoryId: categoryId,
      occurredAt: occurredAt ?? DateTime(2026, 4, 15),
      updatedAt: DateTime(2026, 4, 1),
      deviceId: 'dev',
    );
  }

Category makeCat({
  String id = 'cat-1',
  String name = '测试分类',
  String? color,
}) {
  return Category(
    id: id,
    name: name,
    color: color,
    parentKey: 'food',
    updatedAt: DateTime(2026, 4, 1),
    deviceId: 'dev',
  );
}

// --- Pie aggregation tests ---

test('aggregatePieSlices returns empty list for no expense entries', () {
    final slices = aggregatePieSlices([], {}, testStart, testEnd);
    expect(slices, isEmpty);
  });

  test('aggregatePieSlices excludes income and transfer entries', () {
    final entries = [
      makeTx(id: 'e1', type: 'expense', amount: 50, categoryId: 'cat-1'),
      makeTx(id: 'e2', type: 'income', amount: 100, categoryId: 'cat-1'),
      makeTx(id: 'e3', type: 'transfer', amount: 30, categoryId: 'cat-1'),
    ];
    final catMap = {'cat-1': makeCat(id: 'cat-1', name: '餐饮')};

    final slices = aggregatePieSlices(entries, catMap, testStart, testEnd);

    expect(slices.length, 1);
    expect(slices.single.amount, 50);
    expect(slices.single.categoryName, '餐饮');
  });

  test('aggregatePieSlices 4 categories sum to 100%', () {
    final entries = [
      makeTx(id: 'e1', categoryId: 'cat-1', amount: 30),
      makeTx(id: 'e2', categoryId: 'cat-1', amount: 20),
      makeTx(id: 'e3', categoryId: 'cat-2', amount: 25),
      makeTx(id: 'e4', categoryId: 'cat-3', amount: 15),
      makeTx(id: 'e5', categoryId: 'cat-4', amount: 10),
    ];
    final catMap = {
      'cat-1': makeCat(id: 'cat-1', name: '餐饮'),
      'cat-2': makeCat(id: 'cat-2', name: '交通'),
      'cat-3': makeCat(id: 'cat-3', name: '购物'),
      'cat-4': makeCat(id: 'cat-4', name: '娱乐'),
    };

    final slices = aggregatePieSlices(entries, catMap, testStart, testEnd);

    expect(slices.length, 4);
    final sum = slices.fold<double>(0, (s, e) => s + e.percentage);
    expect(sum, closeTo(100, 0.01));

    expect(slices[0].amount, 50);
    expect(slices[0].categoryName, '餐饮');
    expect(slices[1].amount, 25);
    expect(slices[2].amount, 15);
    expect(slices[3].amount, 10);
  });

  test('aggregatePieSlices top 6 + 其他 with >6 categories', () {
    final entries = <TransactionEntry>[];
    for (var i = 1; i <= 8; i++) {
      entries.add(makeTx(id: 'e$i', categoryId: 'cat-$i', amount: i * 10.0));
    }
    final catMap = <String, Category>{};
    for (var i = 1; i <= 8; i++) {
      catMap['cat-$i'] = makeCat(id: 'cat-$i', name: '分类$i');
    }

    final slices = aggregatePieSlices(entries, catMap, testStart, testEnd);

    // cat-8 (80) to cat-3 (30) = top 6; cat-2 (20) + cat-1 (10) = 其他 (30)
    expect(slices.length, 7);
    expect(slices[0].amount, 80);
    expect(slices[5].amount, 30);
    expect(slices[6].categoryName, '其他');
    expect(slices[6].amount, 30);
    expect(slices[6].categoryId, isNull);

    final sum = slices.fold<double>(0, (s, e) => s + e.percentage);
    expect(sum, closeTo(100, 0.01));
  });

  test('aggregatePieSlices excludes out-of-range transactions', () {
    final entries = [
      makeTx(id: 'e1', amount: 50, occurredAt: DateTime(2026, 3, 31)),
      makeTx(id: 'e2', amount: 30, occurredAt: DateTime(2026, 4, 15)),
      makeTx(id: 'e3', amount: 20, occurredAt: DateTime(2026, 5, 1)),
    ];
    final catMap = {'cat-1': makeCat(id: 'cat-1', name: '餐饮')};

    final slices = aggregatePieSlices(entries, catMap, testStart, testEnd);

    expect(slices.length, 1);
    expect(slices.single.amount, 30);
  });

  test('aggregatePieSlices uses category color when provided', () {
    final entries = [makeTx(amount: 100)];
    final catMap = {
      'cat-1': makeCat(id: 'cat-1', name: '餐饮', color: '#E76F51'),
    };

    final slices = aggregatePieSlices(entries, catMap, testStart, testEnd);

    expect(slices.single.categoryColor, const Color(0xFFE76F51));
  });

  test('aggregatePieSlices falls back to palette when no color', () {
    final entries = [makeTx(amount: 100)];
    final catMap = {
      'cat-1': makeCat(id: 'cat-1', name: '无颜色分类'),
    };

    final slices = aggregatePieSlices(entries, catMap, testStart, testEnd);

    expect(slices.single.categoryColor, const Color(0xFFFFE9B0));
  });

  // --- Rank aggregation tests (Step 5.4) ---

  test('aggregateRankItems returns empty list for no entries', () {
    final items = aggregateRankItems([], {}, testStart, testEnd);
    expect(items, isEmpty);
  });

  test('aggregateRankItems excludes transfer entries', () {
    final entries = [
      makeTx(id: 'e1', type: 'expense', amount: 50, categoryId: 'cat-1'),
      makeTx(id: 'e2', type: 'transfer', amount: 30, categoryId: 'cat-1'),
      makeTx(id: 'e3', type: 'income', amount: 100, categoryId: 'cat-2'),
    ];
    final catMap = {
      'cat-1': makeCat(id: 'cat-1', name: '餐饮'),
      'cat-2': makeCat(id: 'cat-2', name: '工资'),
    };

    final items = aggregateRankItems(entries, catMap, testStart, testEnd);

    expect(items.length, 2);
    expect(items[0].categoryName, '工资');
    expect(items[0].amount, 100);
    expect(items[0].isIncome, true);
    expect(items[1].categoryName, '餐饮');
    expect(items[1].amount, 50);
    expect(items[1].isIncome, false);
  });

  test('aggregateRankItems sums multiple transactions per category', () {
    final entries = [
      makeTx(id: 'e1', type: 'expense', amount: 30, categoryId: 'cat-1'),
      makeTx(id: 'e2', type: 'expense', amount: 20, categoryId: 'cat-1'),
      makeTx(id: 'e3', type: 'expense', amount: 10, categoryId: 'cat-2'),
    ];
    final catMap = {
      'cat-1': makeCat(id: 'cat-1', name: '餐饮'),
      'cat-2': makeCat(id: 'cat-2', name: '交通'),
    };

    final items = aggregateRankItems(entries, catMap, testStart, testEnd);

    expect(items.length, 2);
    expect(items[0].amount, 50);
    expect(items[1].amount, 10);
  });

  test('aggregateRankItems calculates percentages correctly', () {
    final entries = [
      makeTx(type: 'expense', amount: 60, categoryId: 'cat-1'),
      makeTx(type: 'expense', amount: 40, categoryId: 'cat-2'),
      makeTx(type: 'income', amount: 200, categoryId: 'cat-3'),
      makeTx(type: 'income', amount: 100, categoryId: 'cat-4'),
    ];
    final catMap = {
      'cat-1': makeCat(id: 'cat-1', name: '餐饮'),
      'cat-2': makeCat(id: 'cat-2', name: '购物'),
      'cat-3': makeCat(id: 'cat-3', name: '工资'),
      'cat-4': makeCat(id: 'cat-4', name: '奖金'),
    };

    final items = aggregateRankItems(entries, catMap, testStart, testEnd);

    // 按金额降序：工资(200), 奖金(100), 餐饮(60), 购物(40)
    expect(items[0].percentage, closeTo(200/300*100, 0.01)); // 66.67%
    expect(items[1].percentage, closeTo(100/300*100, 0.01)); // 33.33%
    expect(items[2].percentage, closeTo(60/100*100, 0.01));  // 60%
    expect(items[3].percentage, closeTo(40/100*100, 0.01));  // 40%
  });

  test('aggregateRankItems excludes out-of-range transactions', () {
    final entries = [
      makeTx(amount: 50, occurredAt: DateTime(2026, 3, 31)),
      makeTx(amount: 30, occurredAt: DateTime(2026, 4, 15)),
      makeTx(amount: 20, occurredAt: DateTime(2026, 5, 1)),
    ];
    final catMap = {'cat-1': makeCat(id: 'cat-1', name: '餐饮')};

    final items = aggregateRankItems(entries, catMap, testStart, testEnd);

    expect(items.length, 1);
    expect(items.single.amount, 30);
  });

  test('aggregateRankItems uses category color when provided', () {
    final entries = [makeTx(amount: 100)];
    final catMap = {
      'cat-1': makeCat(id: 'cat-1', name: '餐饮', color: '#E76F51'),
    };

    final items = aggregateRankItems(entries, catMap, testStart, testEnd);

    expect(items.single.categoryColor, const Color(0xFFE76F51));
  });

  test('aggregateRankItems falls back to palette when no color', () {
    final entries = [makeTx(amount: 100)];
    final catMap = {
      'cat-1': makeCat(id: 'cat-1', name: '无颜色分类'),
    };

    final items = aggregateRankItems(entries, catMap, testStart, testEnd);

    expect(items.single.categoryColor, const Color(0xFFFFE9B0));
  });

  test('aggregateRankItems handles mixed income/expense with correct totals', () {
    final entries = [
      makeTx(type: 'income', amount: 500, categoryId: 'inc-1'),
      makeTx(type: 'income', amount: 300, categoryId: 'inc-2'),
      makeTx(type: 'expense', amount: 100, categoryId: 'exp-1'),
      makeTx(type: 'expense', amount: 50, categoryId: 'exp-2'),
    ];
    final catMap = {
      'inc-1': makeCat(id: 'inc-1', name: '工资'),
      'inc-2': makeCat(id: 'inc-2', name: '投资'),
      'exp-1': makeCat(id: 'exp-1', name: '餐饮'),
      'exp-2': makeCat(id: 'exp-2', name: '交通'),
    };

    final items = aggregateRankItems(entries, catMap, testStart, testEnd);

    // 收入按金额降序：工资(500, 62.5%), 投资(300, 37.5%)
    expect(items[0].categoryName, '工资');
    expect(items[0].percentage, closeTo(62.5, 0.01));
    expect(items[1].categoryName, '投资');
    expect(items[1].percentage, closeTo(37.5, 0.01));
    // 支出按金额降序：餐饮(100, 66.67%), 交通(50, 33.33%)
    expect(items[2].categoryName, '餐饮');
    expect(items[2].percentage, closeTo(66.67, 0.01));
    expect(items[3].categoryName, '交通');
    expect(items[3].percentage, closeTo(33.33, 0.01));
  });
  // --- Heatmap aggregation tests (Step 5.5) ---

  test('quantileNormalize returns 0 for non-positive or empty inputs', () {
    expect(quantileNormalize(0, const []), 0);
    expect(quantileNormalize(-1, [10, 20, 30]), 0);
    expect(quantileNormalize(10, const []), 0);
  });

  test('quantileNormalize uses quantile cap instead of linear max scaling', () {
    final sorted = [10.0, 20.0, 30.0, 40.0, 200.0];
    final normalDay = quantileNormalize(30, sorted);
    final extremeDay = quantileNormalize(200, sorted);

    expect(normalDay, greaterThan(0.15));
    expect(normalDay, lessThan(0.35));
    expect(extremeDay, 1.0);
  });

  test('aggregateHeatmapCells builds one cell per day in range', () {
    final cells = aggregateHeatmapCells(
      [
        makeTx(id: 'e1', amount: 20, occurredAt: DateTime(2026, 4, 2)),
        makeTx(id: 'e2', amount: 30, occurredAt: DateTime(2026, 4, 4)),
      ],
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 5),
    );

    expect(cells.length, 5);
    expect(cells.first.day, DateTime(2026, 4, 1));
    expect(cells.last.day, DateTime(2026, 4, 5));
    expect(cells[0].amount, 0);
    expect(cells[1].amount, 20);
    expect(cells[3].amount, 30);
  });

  test('aggregateHeatmapCells excludes income and transfer entries', () {
    final cells = aggregateHeatmapCells(
      [
        makeTx(id: 'e1', type: 'expense', amount: 50, occurredAt: DateTime(2026, 4, 3)),
        makeTx(id: 'e2', type: 'income', amount: 100, occurredAt: DateTime(2026, 4, 3)),
        makeTx(id: 'e3', type: 'transfer', amount: 80, occurredAt: DateTime(2026, 4, 3)),
      ],
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 5),
    );

    expect(cells[2].amount, 50);
  });

  test('aggregateHeatmapCells excludes out-of-range entries', () {
    final cells = aggregateHeatmapCells(
      [
        makeTx(id: 'e1', amount: 10, occurredAt: DateTime(2026, 3, 31)),
        makeTx(id: 'e2', amount: 20, occurredAt: DateTime(2026, 4, 2)),
        makeTx(id: 'e3', amount: 30, occurredAt: DateTime(2026, 4, 6)),
      ],
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 5),
    );

    expect(cells.length, 5);
    expect(cells[1].amount, 20);
    expect(cells.where((cell) => cell.amount > 0).length, 1);
  });

  test('aggregateHeatmapCells keeps extreme day from washing out all other days', () {
    final cells = aggregateHeatmapCells(
      [
        makeTx(id: 'e1', amount: 40, occurredAt: DateTime(2026, 4, 1)),
        makeTx(id: 'e2', amount: 50, occurredAt: DateTime(2026, 4, 2)),
        makeTx(id: 'e3', amount: 45, occurredAt: DateTime(2026, 4, 3)),
        makeTx(id: 'e4', amount: 48, occurredAt: DateTime(2026, 4, 4)),
        makeTx(id: 'e5', amount: 250, occurredAt: DateTime(2026, 4, 5)),
      ],
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 5),
    );

    final normalIntensity = cells[1].intensity;
    final extremeIntensity = cells[4].intensity;

    expect(normalIntensity, greaterThan(0.15));
    expect(extremeIntensity, 1.0);
  });

  // --- Step 8.2 验收：跨币种聚合按 fxRate 折算到账本默认币种 ---

  TransactionEntry makeFxTx({
    String id = 'fx-tx',
    String type = 'expense',
    double amount = 10,
    double fxRate = 1.0,
    String currency = 'CNY',
    String? categoryId = 'cat-1',
    DateTime? occurredAt,
  }) {
    return TransactionEntry(
      id: id,
      ledgerId: 'ledger-1',
      type: type,
      amount: amount,
      currency: currency,
      fxRate: fxRate,
      categoryId: categoryId,
      occurredAt: occurredAt ?? DateTime(2026, 4, 15),
      updatedAt: DateTime(2026, 4, 1),
      deviceId: 'dev',
    );
  }

  test('aggregatePieSlices: USD 10 × fxRate 7.2 → 计入 72 CNY', () {
    final entries = [
      makeFxTx(amount: 10, currency: 'USD', fxRate: 7.2),
    ];
    final catMap = {'cat-1': makeCat(id: 'cat-1', name: '餐饮')};

    final slices = aggregatePieSlices(entries, catMap, testStart, testEnd);

    expect(slices.length, 1);
    expect(slices.single.amount, closeTo(72.0, 1e-9));
  });

  test('aggregateRankItems: USD 10 × 7.2 + CNY 18 → 同分类合计 90 CNY', () {
    final entries = [
      makeFxTx(id: 'a', amount: 10, currency: 'USD', fxRate: 7.2),
      makeFxTx(id: 'b', amount: 18, currency: 'CNY', fxRate: 1.0),
    ];
    final catMap = {'cat-1': makeCat(id: 'cat-1', name: '餐饮')};

    final items = aggregateRankItems(entries, catMap, testStart, testEnd);

    expect(items.length, 1);
    expect(items.single.amount, closeTo(90.0, 1e-9));
  });

  test('aggregateHeatmapCells: USD 10 × 7.2 落在当天 → 单元金额 72 CNY', () {
    final entries = [
      makeFxTx(
        amount: 10,
        currency: 'USD',
        fxRate: 7.2,
        occurredAt: DateTime(2026, 4, 15),
      ),
    ];

    final cells = aggregateHeatmapCells(
      entries,
      DateTime(2026, 4, 15),
      DateTime(2026, 4, 15),
    );

    expect(cells.length, 1);
    expect(cells.single.amount, closeTo(72.0, 1e-9));
  });
}