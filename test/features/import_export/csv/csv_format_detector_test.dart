import 'package:bianbianbianbian/features/import_export/csv/csv_format_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectBillParser', () {
    test('本 App 10 列 CSV → BianbianBillParser', () {
      final rows = [
        ['账本', '日期', '类型', '金额', '币种', '一级分类', '分类',
          '账户', '转入账户', '备注'],
        ['生活', '2026-01-01 12:00', '支出', '10', 'CNY', '饮食', '早餐',
          '现金', '', ''],
      ];
      final p = detectBillParser(rows);
      expect(p?.id, 'bianbian');
    });

    test('微信账单 → WechatBillParser', () {
      final rows = [
        ['说明'],
        ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)',
          '支付方式', '当前状态'],
        ['2026-01-01 12:00:00', '商户消费', 'X', 'Y', '支出', '10', '零钱',
          '支付成功'],
      ];
      expect(detectBillParser(rows)?.id, 'wechat_bill');
    });

    test('钱迹 CSV → QianjiBillParser', () {
      final rows = [
        ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
        ['2026-01-01 12:00', '支出', '30', '饮食', '午餐', '现金', '', ''],
      ];
      expect(detectBillParser(rows)?.id, 'qianji');
    });

    test('本 App 9 列(无一级分类) → BianbianBillParser(向后兼容)', () {
      final rows = [
        ['账本', '日期', '类型', '金额', '币种', '分类', '账户', '转入账户', '备注'],
        ['生活', '2026-01-01', '支出', '10', 'CNY', '早餐', '现金', '', ''],
      ];
      expect(detectBillParser(rows)?.id, 'bianbian');
    });

    test('任意 3 列 CSV → GenericBillParser 兜底', () {
      final rows = [
        ['date', 'amount', 'note'],
        ['2026-01-01', '10', 'X'],
        ['2026-01-02', '20', 'Y'],
        ['2026-01-03', '30', 'Z'],
        ['2026-01-04', '40', 'W'],
        ['2026-01-05', '50', 'V'],
        ['2026-01-06', '60', 'U'],
      ];
      expect(detectBillParser(rows)?.id, 'generic');
    });

    test('空 rows → null', () {
      expect(detectBillParser([]), isNull);
    });
  });
}
