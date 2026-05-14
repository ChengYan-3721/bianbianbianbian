import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';

part 'stats_range_providers.g.dart';

enum StatsRangePreset { thisMonth, lastMonth, thisYear, custom }

typedef StatsNow = DateTime Function();

class StatsDateRange {
  const StatsDateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  StatsDateRange copyWith({
    DateTime? start,
    DateTime? end,
  }) {
    return StatsDateRange(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is StatsDateRange &&
            other.start == start &&
            other.end == end);
  }

  @override
  int get hashCode => Object.hash(start, end);

  static StatsDateRange month(DateTime month) {
    final s = DateTime(month.year, month.month, 1);
    final e = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999, 999);
    return StatsDateRange(start: s, end: e);
  }

  static StatsDateRange year(DateTime year) {
    final s = DateTime(year.year, 1, 1);
    final e = DateTime(year.year, 12, 31, 23, 59, 59, 999, 999);
    return StatsDateRange(start: s, end: e);
  }

  static StatsDateRange normalize(DateTime start, DateTime end) {
    final sameOrder = !start.isAfter(end);
    final s = sameOrder ? start : end;
    final e = sameOrder ? end : start;
    return StatsDateRange(start: _startOfDay(s), end: _endOfDay(e));
  }

  static DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime _endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999, 999);
}

class StatsRangeState {
  const StatsRangeState({
    required this.preset,
    required this.range,
  });

  final StatsRangePreset preset;
  final StatsDateRange range;

  StatsRangeState copyWith({
    StatsRangePreset? preset,
    StatsDateRange? range,
  }) {
    return StatsRangeState(
      preset: preset ?? this.preset,
      range: range ?? this.range,
    );
  }
}

class StatsPieSlice {
  const StatsPieSlice({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.amount,
    required this.percentage,
  });

  final String? categoryId;
  final String categoryName;
  final Color categoryColor;
  final double amount;
  final double percentage;
}

const _piePalette = [
  Color(0xFFFFE9B0),
  Color(0xFFFFB7C5),
  Color(0xFF8A5A3B),
  Color(0xFFA8D8B9),
  Color(0xFFF4A261),
  Color(0xFFE76F51),
];

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return null;
  }
}

List<StatsPieSlice> aggregatePieSlices(
  List<TransactionEntry> entries,
  Map<String, Category> categoryMap,
  DateTime start,
  DateTime end,
) {
  final byCategory = <String, double>{};
  double total = 0;

  for (final tx in entries) {
    if (tx.type != 'expense') continue;
    final occurred = tx.occurredAt;
    if (occurred.isBefore(start) || occurred.isAfter(end)) continue;
    if (tx.categoryId == null) continue;

    // Step 8.2：所有聚合按 amount * fxRate 折算到账本默认币种。
    final converted = tx.amount * tx.fxRate;
    byCategory[tx.categoryId!] = (byCategory[tx.categoryId!] ?? 0) + converted;
    total += converted;
  }

  if (byCategory.isEmpty) return [];

  final sorted = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final slices = <StatsPieSlice>[];
  double othersAmount = 0;

  for (var i = 0; i < sorted.length; i++) {
    final entry = sorted[i];
    if (i < 6) {
      final cat = categoryMap[entry.key];
      slices.add(StatsPieSlice(
        categoryId: entry.key,
        categoryName: cat?.name ?? '未分类', // i18n-exempt: fallback label, localized in UI
        categoryColor:
            _parseHexColor(cat?.color) ?? _piePalette[i % _piePalette.length],
        amount: entry.value,
        percentage: total > 0 ? entry.value / total * 100 : 0,
      ));
    } else {
      othersAmount += entry.value;
    }
  }

  if (othersAmount > 0) {
    slices.add(StatsPieSlice(
      categoryId: null,
      categoryName: '其他', // i18n-exempt: fallback label, localized in UI
      categoryColor: const Color(0xFFBDBDBD),
      amount: othersAmount,
      percentage: total > 0 ? othersAmount / total * 100 : 0,
    ));
  }

  return slices;
}

class StatsLinePoint {
  const StatsLinePoint({
    required this.day,
    required this.income,
    required this.expense,
  });

  final DateTime day;
  final double income;
  final double expense;
}

class StatsHeatmapCell {
  const StatsHeatmapCell({
    required this.day,
    required this.amount,
    required this.intensity,
    required this.isInRange,
  });

  final DateTime day;
  final double amount;
  final double intensity;
  final bool isInRange;
}

@visibleForTesting
double quantileNormalize(
  double value,
  List<double> sortedValues, {
  double quantile = 0.9,
}) {
  if (value <= 0 || sortedValues.isEmpty) {
    return 0;
  }

  final positives = sortedValues.where((v) => v > 0).toList()..sort();
  if (positives.isEmpty) {
    return 0;
  }

  final cappedQuantile = quantile.clamp(0.5, 1.0);
  final pivot = _quantileValue(positives, cappedQuantile);
  if (pivot <= 0) {
    return 0;
  }

  final normalized = (value / pivot).clamp(0.0, 1.0);
  return normalized.toDouble();
}

double _quantileValue(List<double> sortedValues, double quantile) {
  if (sortedValues.length == 1) {
    return sortedValues.first;
  }

  final position = (sortedValues.length - 1) * quantile;
  final lowerIndex = position.floor();
  final upperIndex = position.ceil();
  if (lowerIndex == upperIndex) {
    return sortedValues[lowerIndex];
  }

  final lower = sortedValues[lowerIndex];
  final upper = sortedValues[upperIndex];
  final fraction = position - lowerIndex;
  return lower + (upper - lower) * fraction;
}

List<StatsHeatmapCell> aggregateHeatmapCells(
  List<TransactionEntry> entries,
  DateTime start,
  DateTime end,
) {
  final range = StatsDateRange.normalize(start, end);
  final byDay = <DateTime, double>{};

  for (final tx in entries) {
    if (tx.type != 'expense') continue;
    final occurred = tx.occurredAt;
    if (occurred.isBefore(range.start) || occurred.isAfter(range.end)) continue;

    final day = DateTime(occurred.year, occurred.month, occurred.day);
    // Step 8.2：跨币种流水按 fxRate 折算后再累加。
    byDay[day] = (byDay[day] ?? 0) + tx.amount * tx.fxRate;
  }

  final amounts = byDay.values.where((v) => v > 0).toList()..sort();
  final cells = <StatsHeatmapCell>[];

  for (
    var cursor = DateTime(range.start.year, range.start.month, range.start.day);
    !cursor.isAfter(range.end);
    cursor = cursor.add(const Duration(days: 1))
  ) {
    final amount = byDay[cursor] ?? 0;
    cells.add(StatsHeatmapCell(
      day: cursor,
      amount: amount,
      intensity: quantileNormalize(amount, amounts),
      isInRange: true,
    ));
  }

  return cells;
}

@Riverpod(keepAlive: true)
Future<List<StatsLinePoint>> statsLinePoints(Ref ref) async {
  final rangeState = ref.watch(statsRangeProvider);
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final repo = await ref.watch(transactionRepositoryProvider.future);

  final entries = await repo.listActiveByLedger(ledgerId);

  final start = rangeState.range.start;
  final end = rangeState.range.end;

  final byDay = <DateTime, _DayIncomeExpense>{};

  for (final tx in entries) {
    if (tx.type == 'transfer') continue;
    final occurred = tx.occurredAt;
    if (occurred.isBefore(start) || occurred.isAfter(end)) continue;

    final day = DateTime(occurred.year, occurred.month, occurred.day);
    final bucket = byDay.putIfAbsent(day, () => const _DayIncomeExpense());

    // Step 8.2：跨币种按 fxRate 折算后再累加到 income/expense。
    final converted = tx.amount * tx.fxRate;
    if (tx.type == 'income') {
      byDay[day] = bucket.copyWith(income: bucket.income + converted);
      continue;
    }
    if (tx.type == 'expense') {
      byDay[day] = bucket.copyWith(expense: bucket.expense + converted);
    }
  }

  final sortedDays = byDay.keys.toList()..sort((a, b) => a.compareTo(b));
  return sortedDays
      .map(
        (day) => StatsLinePoint(
          day: day,
          income: byDay[day]!.income,
          expense: byDay[day]!.expense,
        ),
      )
      .toList(growable: false);
}

class _DayIncomeExpense {
  const _DayIncomeExpense({
    this.income = 0,
    this.expense = 0,
  });

  final double income;
  final double expense;

  _DayIncomeExpense copyWith({
    double? income,
    double? expense,
  }) {
    return _DayIncomeExpense(
      income: income ?? this.income,
      expense: expense ?? this.expense,
    );
  }
}

@Riverpod(keepAlive: true)
class StatsRange extends _$StatsRange {
  StatsNow _now = DateTime.now;

  @override
  StatsRangeState build() {
    final now = _now();
    return StatsRangeState(
      preset: StatsRangePreset.thisMonth,
      range: StatsDateRange.month(now),
    );
  }

  @visibleForTesting
  void debugSetNow(StatsNow now) {
    _now = now;
    ref.invalidateSelf();
  }

  void setPreset(StatsRangePreset preset) {
    final now = _now();
    switch (preset) {
      case StatsRangePreset.thisMonth:
        state = state.copyWith(
          preset: preset,
          range: StatsDateRange.month(now),
        );
        break;
      case StatsRangePreset.lastMonth:
        state = state.copyWith(
          preset: preset,
          range: StatsDateRange.month(DateTime(now.year, now.month - 1, 1)),
        );
        break;
      case StatsRangePreset.thisYear:
        state = state.copyWith(
          preset: preset,
          range: StatsDateRange.year(now),
        );
        break;
      case StatsRangePreset.custom:
        state = state.copyWith(preset: preset);
        break;
    }
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      preset: StatsRangePreset.custom,
      range: StatsDateRange.normalize(start, end),
    );
  }
}

@Riverpod(keepAlive: true)
Future<List<StatsPieSlice>> statsPieSlices(Ref ref) async {
  final rangeState = ref.watch(statsRangeProvider);
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final catRepo = await ref.watch(categoryRepositoryProvider.future);

  final entries = await txRepo.listActiveByLedger(ledgerId);
  final allCategories = await catRepo.listActiveAll();
  final catMap = {for (final c in allCategories) c.id: c};

  return aggregatePieSlices(
    entries,
    catMap,
    rangeState.range.start,
    rangeState.range.end,
  );
}
class StatsRankItem {
  const StatsRankItem({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.amount,
    required this.percentage,
    required this.isIncome,
  });

  final String? categoryId;
  final String categoryName;
  final Color categoryColor;
  final double amount;
  final double percentage;
  final bool isIncome;
}

class _CategoryAgg {
  double amount = 0;
}

List<StatsRankItem> aggregateRankItems(
  List<TransactionEntry> entries,
  Map<String, Category> categoryMap,
  DateTime start,
  DateTime end,
) {
  final byCategory = <String, _CategoryAgg>{};
  double totalIncome = 0;
  double totalExpense = 0;

  for (final tx in entries) {
    if (tx.type == 'transfer') continue;
    final occurred = tx.occurredAt;
    if (occurred.isBefore(start) || occurred.isAfter(end)) continue;
    if (tx.categoryId == null) continue;

    final isIncome = tx.type == 'income';
    final key = '${tx.type}|${tx.categoryId}';
    final agg = byCategory.putIfAbsent(key, () => _CategoryAgg());
    // Step 8.2：跨币种按 fxRate 折算后再累加到分类合计。
    final converted = tx.amount * tx.fxRate;
    agg.amount += converted;

    if (isIncome) {
      totalIncome += converted;
    } else {
      totalExpense += converted;
    }
  }

  if (byCategory.isEmpty) return [];

  final items = <StatsRankItem>[];
  for (final entry in byCategory.entries) {
    final parts = entry.key.split('|');
    final isIncome = parts[0] == 'income';
    final catId = parts[1];
    final cat = categoryMap[catId];
    final total = isIncome ? totalIncome : totalExpense;

    items.add(StatsRankItem(
      categoryId: catId,
      categoryName: cat?.name ?? '未分类', // i18n-exempt: provider without BuildContext
      categoryColor:
          _parseHexColor(cat?.color) ?? _piePalette[items.length % _piePalette.length],
      amount: entry.value.amount,
      percentage: total > 0 ? entry.value.amount / total * 100 : 0,
      isIncome: isIncome,
    ));
  }

  items.sort((a, b) => b.amount.compareTo(a.amount));
  return items;
}

@Riverpod(keepAlive: true)
Future<List<StatsRankItem>> statsRankItems(Ref ref) async {
  final rangeState = ref.watch(statsRangeProvider);
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final catRepo = await ref.watch(categoryRepositoryProvider.future);

  final entries = await txRepo.listActiveByLedger(ledgerId);
  final allCategories = await catRepo.listActiveAll();
  final catMap = {for (final c in allCategories) c.id: c};

  return aggregateRankItems(
    entries,
    catMap,
    rangeState.range.start,
    rangeState.range.end,
  );
}

@Riverpod(keepAlive: true)
Future<List<StatsHeatmapCell>> statsHeatmapCells(Ref ref) async {
  final rangeState = ref.watch(statsRangeProvider);
  final ledgerId = await ref.watch(currentLedgerIdProvider.future);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);

  final entries = await txRepo.listActiveByLedger(ledgerId);
  return aggregateHeatmapCells(
    entries,
    rangeState.range.start,
    rangeState.range.end,
  );
}