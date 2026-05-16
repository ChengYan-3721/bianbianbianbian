import 'package:bianbianbianbian/features/import_export/csv/parsers/bianbian_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BianbianBillParser();

  test('10 列严匹配 — parseRow 返回非空', () {
    final rows = [
      ['账本', '日期', '类型', '金额', '币种', '一级分类', '分类', '账户', '转入账户', '备注'],
      ['📒 生活', '2026-01-01 12:00', '支出', '10.00', 'CNY', '饮食', '早餐', '现金', '', '吃饭'],
    ];
    expect(parser.validateBillType(rows), true);
    expect(parser.findHeaderRow(rows), 0);
    final mapping = parser.mapColumns(rows[0]);
    expect(mapping['primary_category'], 5);
    expect(mapping['category'], 6);
    final row = parser.parseRow(rows[1], mapping);
    expect(row, isNotNull);
    // Task 12 之前 BackupImportCsvRow 还没有 primaryCategoryName 字段;
    // 仅验证 categoryName / accountName 等已存在字段。
    expect(row!.categoryName, '早餐');
    expect(row.accountName, '现金');
  });

  test('旧 9 列兼容(无一级分类列)', () {
    final rows = [
      ['账本', '日期', '类型', '金额', '币种', '分类', '账户', '转入账户', '备注'],
      ['生活', '2026-01-01 12:00', '支出', '10.00', 'CNY', '早餐', '现金', '', '吃饭'],
    ];
    expect(parser.validateBillType(rows), true);
    final mapping = parser.mapColumns(rows[0]);
    expect(mapping['primary_category'], isNull); // 9 列无 primary_category
    expect(mapping['category'], 5);
    final row = parser.parseRow(rows[1], mapping);
    expect(row, isNotNull);
    expect(row!.categoryName, '早餐');
  });

  test('非本 App header 不匹配', () {
    final rows = [
      ['Date', 'Type', 'Amount'],
      ['2026-01-01', '支出', '10'],
    ];
    expect(parser.validateBillType(rows), false);
  });
}
