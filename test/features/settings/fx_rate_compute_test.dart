import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/features/settings/settings_providers.dart';

/// Step 8.2：[computeFxRate] 纯函数行为。
///
/// 数学语义：fx_rate 表存"该币种 → CNY"的因子（rate_to_cny）。从币种 A 到
/// 币种 B 的换算 = `ratesToCny[A] / ratesToCny[B]`。CNY 自身 = 1.0。
void main() {
  group('computeFxRate', () {
    const rates = <String, double>{
      'CNY': 1.0,
      'USD': 7.20,
      'EUR': 7.85,
      'JPY': 0.048,
    };

    test('同币种 → 1.0', () {
      expect(computeFxRate('CNY', 'CNY', rates), 1.0);
      expect(computeFxRate('USD', 'USD', rates), 1.0);
    });

    test('USD → CNY = 7.20', () {
      expect(computeFxRate('USD', 'CNY', rates), 7.20);
    });

    test('CNY → USD = 1 / 7.20', () {
      expect(computeFxRate('CNY', 'USD', rates), closeTo(1 / 7.20, 1e-9));
    });

    test('USD → EUR = 7.20 / 7.85', () {
      expect(computeFxRate('USD', 'EUR', rates),
          closeTo(7.20 / 7.85, 1e-9));
    });

    test('保存时金额×fxRate 即账本默认币种金额（USD 10、rate 7.2 → CNY 72）', () {
      final fx = computeFxRate('USD', 'CNY', rates);
      const amount = 10.0;
      expect(amount * fx, closeTo(72.0, 1e-9));
    });

    test('源币种缺失 → 兜底 1.0（避免崩溃）', () {
      expect(computeFxRate('XXX', 'CNY', rates), 1.0);
    });

    test('目标币种缺失 → 兜底 1.0', () {
      expect(computeFxRate('USD', 'XXX', rates), 1.0);
    });

    test('目标币种汇率为 0 → 兜底 1.0（保护除零）', () {
      const broken = {'CNY': 1.0, 'USD': 7.2, 'BUG': 0.0};
      expect(computeFxRate('USD', 'BUG', broken), 1.0);
    });
  });
}
