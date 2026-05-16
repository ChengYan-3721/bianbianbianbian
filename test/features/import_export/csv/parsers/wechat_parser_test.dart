import 'package:bianbianbianbian/features/import_export/csv/parsers/wechat_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = WechatBillParser();

  test('header 签名识别', () {
    final rows = [
      ['以下为本人微信账单明细'],
      ['账单明细'],
      ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)',
        '支付方式', '当前状态', '交易单号', '商户单号', '备注'],
      ['2026-01-01 12:00:00', '商户消费', '星巴克', '咖啡', '支出', '30.00',
        '零钱', '支付成功', 'X', 'Y', '/'],
    ];
    expect(parser.validateBillType(rows), true);
    expect(parser.findHeaderRow(rows), 2);
  });

  test('parseRow:交易类型 → category;收/支 → type', () {
    final rows = [
      ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)',
        '支付方式', '当前状态'],
      ['2026-01-01 12:00:00', '商户消费', '星巴克', '咖啡', '支出', '30.00',
        '零钱', '支付成功'],
    ];
    final mapping = parser.mapColumns(rows[0]);
    expect(mapping['category'], 1, reason: '交易类型 → category');
    expect(mapping['type'], 4, reason: '收/支 → type');
    final row = parser.parseRow(rows[1], mapping);
    expect(row, isNotNull);
    expect(row!.type, 'expense');
    expect(row.categoryName, '商户消费');
    expect(row.accountName, '零钱');
  });

  test('退款 / 失败 / 关闭 / 未支付状态过滤', () {
    final header = ['交易时间', '交易类型', '交易对方', '商品', '收/支',
      '金额(元)', '支付方式', '当前状态'];
    final mapping = parser.mapColumns(header);
    final base = ['2026-01-01 12:00:00', '商户消费', 'X', 'Y',
      '支出', '10', '零钱'];
    expect(parser.parseRow([...base, '已全额退款'], mapping), isNull);
    expect(parser.parseRow([...base, '支付失败'], mapping), isNull);
    expect(parser.parseRow([...base, '已关闭'], mapping), isNull);
    expect(parser.parseRow([...base, '未支付'], mapping), isNull);
    expect(parser.parseRow([...base, '支付成功'], mapping), isNotNull);
  });

  test('「/」收支视为中性,跳过', () {
    final header = ['交易时间', '交易类型', '交易对方', '商品', '收/支',
      '金额(元)', '支付方式', '当前状态'];
    final mapping = parser.mapColumns(header);
    final row = ['2026-01-01 12:00:00', '零钱通转入', '零钱通', '/', '/', '100',
      '零钱通', '充值完成'];
    expect(parser.parseRow(row, mapping), isNull);
  });

  test('ledgerLabel 固定 = 「微信账单」', () {
    final header = ['交易时间', '交易类型', '交易对方', '商品', '收/支',
      '金额(元)', '支付方式', '当前状态'];
    final mapping = parser.mapColumns(header);
    final row = ['2026-01-01 12:00:00', '商户消费', 'X', 'Y', '支出', '10',
      '零钱', '支付成功'];
    final parsed = parser.parseRow(row, mapping);
    expect(parsed!.ledgerLabel, '微信账单');
  });
}
