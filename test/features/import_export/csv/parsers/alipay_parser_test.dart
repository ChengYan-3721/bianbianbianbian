import 'package:bianbianbianbian/features/import_export/csv/parsers/alipay_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = AlipayBillParser();

  test('header 签名识别', () {
    final rows = [
      ['支付宝账单查询信息'],
      ['交易号', '商家订单号', '交易创建时间', '付款时间', '类型',
        '交易对方', '商品名称', '金额（元）', '收/支', '交易状态'],
      ['X', 'Y', '2026-01-01 12:00:00', '2026-01-01 12:00:00', '餐饮美食',
        '某餐厅', '午饭', '30.00', '支出', '交易成功'],
    ];
    expect(parser.validateBillType(rows), true);
  });

  test('parseRow:类型 → category;收/支 → type;account 固定支付宝', () {
    final rows = [
      ['交易号', '商家订单号', '交易创建时间', '付款时间', '类型',
        '交易对方', '商品名称', '金额（元）', '收/支', '交易状态'],
      ['X', 'Y', '2026-01-01 12:00:00', '2026-01-01 12:00:00', '餐饮美食',
        '某餐厅', '午饭', '30.00', '支出', '交易成功'],
    ];
    final mapping = parser.mapColumns(rows[0]);
    final row = parser.parseRow(rows[1], mapping);
    expect(row, isNotNull);
    expect(row!.type, 'expense');
    expect(row.categoryName, '餐饮美食');
    expect(row.accountName, '支付宝');
  });

  test('退款 / 关闭 / 失败 过滤', () {
    final header = ['交易号', '商家订单号', '交易创建时间', '付款时间', '类型',
      '交易对方', '商品名称', '金额（元）', '收/支', '交易状态'];
    final mapping = parser.mapColumns(header);
    final base = ['X', 'Y', '2026-01-01 12:00:00', '2026-01-01 12:00:00',
      '日用百货', 'A', 'B', '50', '支出'];
    expect(parser.parseRow([...base, '退款成功'], mapping), isNull);
    expect(parser.parseRow([...base, '交易关闭'], mapping), isNull);
    expect(parser.parseRow([...base, '支付失败'], mapping), isNull);
    expect(parser.parseRow([...base, '交易成功'], mapping), isNotNull);
  });
}
