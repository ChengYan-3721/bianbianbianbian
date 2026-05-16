import 'package:bianbianbianbian/features/import_export/csv/parsers/generic_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = GenericBillParser();

  group('normalizeToKey', () {
    test('英文 date 别名', () {
      expect(GenericBillParser.normalizeToKey('Date'), 'date');
      expect(GenericBillParser.normalizeToKey('  TIME '), 'date');
      expect(GenericBillParser.normalizeToKey('datetime'), 'date');
    });

    test('英文 amount 别名', () {
      expect(GenericBillParser.normalizeToKey('amount'), 'amount');
      expect(GenericBillParser.normalizeToKey('Money'), 'amount');
      expect(GenericBillParser.normalizeToKey('Value'), 'amount');
    });

    test('中文 date 含子串', () {
      expect(GenericBillParser.normalizeToKey('交易时间'), 'date');
      expect(GenericBillParser.normalizeToKey('账单日期'), 'date');
    });

    test('中文 primary_category 优先于 category', () {
      expect(GenericBillParser.normalizeToKey('一级分类'), 'primary_category');
      expect(GenericBillParser.normalizeToKey('父分类'), 'primary_category');
    });

    test('中文 category(二级)优先于 type', () {
      expect(GenericBillParser.normalizeToKey('二级分类'), 'category');
      expect(GenericBillParser.normalizeToKey('子分类'), 'category');
      expect(GenericBillParser.normalizeToKey('分类'), 'category');
    });

    test('收支符号识别为 type', () {
      expect(GenericBillParser.normalizeToKey('收/支'), 'type');
      expect(GenericBillParser.normalizeToKey('收支'), 'type');
    });

    test('账户列别名', () {
      expect(GenericBillParser.normalizeToKey('账户'), 'account');
      expect(GenericBillParser.normalizeToKey('转出账户'), 'from_account');
      expect(GenericBillParser.normalizeToKey('转入账户'), 'to_account');
    });

    test('状态列', () {
      expect(GenericBillParser.normalizeToKey('当前状态'), 'status');
      expect(GenericBillParser.normalizeToKey('交易状态'), 'status');
    });

    test('忽略的列返回 null', () {
      expect(GenericBillParser.normalizeToKey('交易号'), null);
      expect(GenericBillParser.normalizeToKey('订单号'), null);
      expect(GenericBillParser.normalizeToKey(''), null);
    });
  });

  group('findHeaderRow', () {
    test('列数一致性发现 header', () {
      // 前 2 行说明(列数不一致),第 3 行起 6 行 4 列数据
      final rows = [
        ['这是说明'],
        ['第二行说明'],
        ['日期', '类型', '金额', '分类'],
        ['2026-01-01', '支出', '10', '餐饮'],
        ['2026-01-02', '支出', '20', '餐饮'],
        ['2026-01-03', '支出', '30', '餐饮'],
        ['2026-01-04', '支出', '40', '餐饮'],
        ['2026-01-05', '支出', '50', '餐饮'],
        ['2026-01-06', '支出', '60', '餐饮'],
      ];
      expect(parser.findHeaderRow(rows), 2);
    });

    test('没有一致结构返回 0(兜底)', () {
      final rows = [
        ['a', 'b'],
        ['c'],
      ];
      expect(parser.findHeaderRow(rows), 0);
    });
  });

  group('validateBillType', () {
    test('总是返回 true(兜底)', () {
      expect(parser.validateBillType([['a']]), true);
      expect(parser.validateBillType([]), true);
    });
  });
}
