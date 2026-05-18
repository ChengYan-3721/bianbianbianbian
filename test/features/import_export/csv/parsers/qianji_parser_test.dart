import 'package:bianbianbianbian/features/import_export/csv/parsers/qianji_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = QianjiBillParser();

  test('8 列格式识别', () {
    final rows = [
      ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
      ['2026-01-01 12:00', '支出', '30', '饮食', '午餐', '现金', '', '吃饭'],
    ];
    expect(parser.validateBillType(rows), true);
  });

  test('6 列格式识别', () {
    final rows = [
      ['日期', '分类', '子分类', '账户', '金额', '备注'],
      ['2026-01-01', '饮食', '午餐', '现金', '30', '吃饭'],
    ];
    expect(parser.validateBillType(rows), true);
  });

  test('含「账本」/「币种」必须不命中(护栏)', () {
    final rows = [
      ['账本', '日期', '类型', '金额', '币种', '分类', '账户', '转入账户', '备注'],
      ['生活', '2026-01-01', '支出', '30', 'CNY', '午餐', '现金', '', ''],
    ];
    expect(parser.validateBillType(rows), false);
  });

  test('parseRow 8 列:一级 + 二级直接取值', () {
    final rows = [
      ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
      ['2026-01-01 12:00', '支出', '30', '饮食', '午餐', '现金', '', '吃饭'],
    ];
    final mapping = parser.mapColumns(rows[0]);
    final row = parser.parseRow(rows[1], mapping);
    expect(row, isNotNull);
    expect(row!.primaryCategoryName, '饮食');
    expect(row.categoryName, '午餐');
    expect(row.accountName, '现金');
  });

  test('amount 永远 abs()', () {
    final rows = [
      ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
      ['2026-01-01 12:00', '支出', '-30', '饮食', '午餐', '现金', '', ''],
    ];
    final mapping = parser.mapColumns(rows[0]);
    final row = parser.parseRow(rows[1], mapping);
    expect(row!.amount, 30.0);
  });

  test('转账行:类型=转账,账户1→from,账户2→to', () {
    final rows = [
      ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
      ['2026-01-01 12:00', '转账', '100', '', '', '现金', '银行卡', ''],
    ];
    final mapping = parser.mapColumns(rows[0]);
    final row = parser.parseRow(rows[1], mapping);
    expect(row!.type, 'transfer');
    expect(row.accountName, '现金');
    expect(row.toAccountName, '银行卡');
  });
}
