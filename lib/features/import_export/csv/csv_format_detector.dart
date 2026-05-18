import 'bill_parser.dart';
import 'parsers/alipay_parser.dart';
import 'parsers/bianbian_parser.dart';
import 'parsers/generic_parser.dart';
import 'parsers/qianji_parser.dart';
import 'parsers/wechat_parser.dart';

/// CSV 格式探测注册表——按顺序逐一 [BillParser.validateBillType],命中第一个返回。
///
/// 顺序敏感:
/// - **Bianbian 最前**:本 App 自有 10 列严匹配最具体,避免被 Generic 抢走解析权。
/// - **Wechat / Alipay 接着**:header 关键字签名强,放在钱迹之前免被钱迹弱签名误命中。
/// - **Qianji 倒数第二**:弱签名(金额+分类+时间),放后面。
/// - **Generic 兜底**:总是返回 true,接受所有列数一致的 CSV。
const List<BillParser> kAllParsers = [
  BianbianBillParser(),
  WechatBillParser(),
  AlipayBillParser(),
  QianjiBillParser(),
  GenericBillParser(),
];

/// 探测主入口。空 rows 返回 null。
BillParser? detectBillParser(List<List<String>> rows) {
  if (rows.isEmpty) return null;
  for (final p in kAllParsers) {
    if (p.validateBillType(rows)) return p;
  }
  return null; // 不会发生,Generic 兜底永真
}
