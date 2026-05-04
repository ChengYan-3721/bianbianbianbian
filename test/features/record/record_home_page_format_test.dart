import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/record/record_home_page.dart';

/// Step 8.2 验收：流水详情展示"USD 10.00（≈ ¥72.00）"格式。
///
/// 这里只测纯函数 [formatTxAmountForDetail]——它是 `_RecordDetailSheet` 与
/// 后续可能的列表 tile 等 widget 共享的拼装逻辑。Widget 层的 SnapShot 通过
/// `record_new_page_test.dart` 与 `widget_test.dart` 已有的 record_home_page
/// 用例覆盖。
TransactionEntry _makeTx({
  String type = 'expense',
  double amount = 10,
  String currency = 'USD',
  double fxRate = 7.2,
}) {
  return TransactionEntry(
    id: 'tx-1',
    ledgerId: 'led-1',
    type: type,
    amount: amount,
    currency: currency,
    fxRate: fxRate,
    occurredAt: DateTime(2026, 4, 15),
    updatedAt: DateTime(2026, 4, 15),
    deviceId: 'dev',
  );
}

void main() {
  group('formatTxAmountForDetail', () {
    test('USD 10、fxRate 7.2、账本 CNY → "-USD 10.00（≈ ¥72.00）"', () {
      final s = formatTxAmountForDetail(
        _makeTx(type: 'expense'),
        'CNY',
      );
      expect(s, '-USD 10.00（≈ ¥72.00）');
    });

    test('收入 USD 10、账本 CNY → "+USD 10.00（≈ ¥72.00）"', () {
      final s = formatTxAmountForDetail(
        _makeTx(type: 'income'),
        'CNY',
      );
      expect(s, '+USD 10.00（≈ ¥72.00）');
    });

    test('转账 USD 10、账本 CNY → 无符号 "USD 10.00（≈ ¥72.00）"', () {
      final s = formatTxAmountForDetail(
        _makeTx(type: 'transfer'),
        'CNY',
      );
      expect(s, 'USD 10.00（≈ ¥72.00）');
    });

    test('同币种 CNY 50、账本 CNY → 不展示括号折合', () {
      final s = formatTxAmountForDetail(
        _makeTx(amount: 50, currency: 'CNY', fxRate: 1.0, type: 'expense'),
        'CNY',
      );
      expect(s, '-¥50.00');
    });

    test('CNY 50 → USD 账本：" -CNY 50.00（≈ \$X.XX）"', () {
      // 1 / 7.2 ≈ 0.13888...，50 / 7.2 ≈ 6.94444...
      final s = formatTxAmountForDetail(
        _makeTx(amount: 50, currency: 'CNY', fxRate: 1 / 7.2, type: 'expense'),
        'USD',
      );
      expect(s, '-CNY 50.00（≈ \$6.94）');
    });

    test('JPY 1500、fxRate 0.048、账本 CNY → "-JPY 1,500.00（≈ ¥72.00）"（千分位逗号）', () {
      final s = formatTxAmountForDetail(
        _makeTx(amount: 1500, currency: 'JPY', fxRate: 0.048, type: 'expense'),
        'CNY',
      );
      expect(s, '-JPY 1,500.00（≈ ¥72.00）');
    });
  });
}
