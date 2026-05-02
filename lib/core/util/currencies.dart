/// 内置币种常量与汇率快照（Step 8.1）。
///
/// design-document §5.7 列出 V1 的 11 种内置币种：
/// CNY / USD / EUR / JPY / KRW / HKD / TWD / GBP / SGD / CAD / AUD。
///
/// 汇率以 **CNY 为基准**：[kFxRateSnapshot] 中每个值表示
/// `1 单位该币种 == 多少 CNY`，即 `rate_to_cny`。这是开发者在 V1 阶段
/// 写死的"合理快照"，Step 8.3 引入联网刷新时由实际 API 覆盖。
library;

class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  /// ISO 4217 三字符代码，例如 `CNY` / `USD`。
  final String code;

  /// 显示符号，例如 `¥` / `$` / `€`。
  final String symbol;

  /// 中文名称，例如 `人民币` / `美元`。
  final String name;
}

/// V1 内置币种列表（顺序即"我的 → 多币种"页与记账页下拉的展示顺序）。
const List<Currency> kBuiltInCurrencies = [
  Currency(code: 'CNY', symbol: '¥', name: '人民币'),
  Currency(code: 'USD', symbol: r'$', name: '美元'),
  Currency(code: 'EUR', symbol: '€', name: '欧元'),
  Currency(code: 'JPY', symbol: 'JP¥', name: '日元'),
  Currency(code: 'KRW', symbol: '₩', name: '韩元'),
  Currency(code: 'HKD', symbol: r'HK$', name: '港币'),
  Currency(code: 'TWD', symbol: r'NT$', name: '新台币'),
  Currency(code: 'GBP', symbol: '£', name: '英镑'),
  Currency(code: 'SGD', symbol: r'S$', name: '新元'),
  Currency(code: 'CAD', symbol: r'C$', name: '加元'),
  Currency(code: 'AUD', symbol: r'A$', name: '澳元'),
];

/// 写死的初始汇率快照：`code → 1 单位该币种值多少 CNY`。
///
/// 数值是 2026-05 的"合理参考"，不需要精准——Step 8.3 联网刷新会覆盖；
/// 用户也可通过"我的 → 多币种"手动覆盖某币种汇率。
const Map<String, double> kFxRateSnapshot = {
  'CNY': 1.0,
  'USD': 7.20,
  'EUR': 7.85,
  'JPY': 0.048,
  'KRW': 0.0055,
  'HKD': 0.92,
  'TWD': 0.23,
  'GBP': 9.10,
  'SGD': 5.40,
  'CAD': 5.30,
  'AUD': 4.80,
};
