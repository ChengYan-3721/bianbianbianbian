import '../../import_service.dart' show BackupImportCsvRow;
import 'generic_parser.dart';

/// 微信支付账单 CSV 解析器。
///
/// **来源**:微信支付 → 账单 → 申请账单 → 邮箱接收 → 解压 ZIP → CSV。
///
/// **结构**:文件头 16 行说明,然后一行 header:
/// `交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,
///  交易单号,商户单号,备注`
///
/// **关键映射**(本 parser 在 mapColumns 中覆盖 super):
/// - 「交易类型」列被 super 归到 `type`,本 parser 把它移到 `category`
///   (微信的「交易类型」语义上是分类,例「商户消费」/「转账」/「红包」);
/// - 「收/支」列(super 也归到 `type`)保留在 `type`(覆盖前一步)。
class WechatBillParser extends GenericBillParser {
  const WechatBillParser();

  @override
  String get id => 'wechat_bill';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '微信账单';

  static const List<String> _headerSignals = [
    '交易时间', '交易类型', '交易对方', '收/支',
  ];

  @override
  bool validateBillType(List<List<String>> rows) {
    return _findHeaderRowByKeywords(rows) >= 0;
  }

  @override
  int findHeaderRow(List<List<String>> rows) {
    final idx = _findHeaderRowByKeywords(rows);
    return idx >= 0 ? idx : super.findHeaderRow(rows);
  }

  static int _findHeaderRowByKeywords(List<List<String>> rows) {
    final scanLimit = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 6) continue;
      final joined = row.join('|');
      if (_headerSignals.every(joined.contains)) return i;
    }
    return -1;
  }

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final base = super.mapColumns(headerRow);
    int? indexOf(String name) {
      for (var i = 0; i < headerRow.length; i++) {
        if (headerRow[i].trim() == name) return i;
      }
      return null;
    }
    final txTypeIdx = indexOf('交易类型');
    final ioIdx = indexOf('收/支');
    final paymentMethodIdx = indexOf('支付方式');
    if (txTypeIdx != null) base['category'] = txTypeIdx;
    if (ioIdx != null) base['type'] = ioIdx; // 覆盖
    if (paymentMethodIdx != null) base['account'] = paymentMethodIdx;
    return base;
  }

  @override
  BackupImportCsvRow? parseRow(
    List<String> row,
    Map<String, int> columnMapping,
  ) {
    String? getBy(String key) {
      final idx = columnMapping[key];
      if (idx == null || idx >= row.length) return null;
      final v = row[idx].trim();
      return v.isEmpty ? null : v;
    }

    // 状态过滤
    final status = getBy('status') ?? '';
    if (status.contains('退款') ||
        status.contains('失败') ||
        status.contains('关闭') ||
        status.contains('未支付')) {
      return null;
    }

    final dateStr = getBy('date');
    if (dateStr == null) return null;
    // ignore: invalid_use_of_visible_for_testing_member
    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;

    final amountStr = getBy('amount');
    if (amountStr == null) return null;
    // ignore: invalid_use_of_visible_for_testing_member
    final amount = parseAmount(amountStr);
    if (amount == null || amount <= 0) return null;

    final type = _typeFromIoFlag(getBy('type') ?? '');
    if (type == null) return null;

    return BackupImportCsvRow(
      ledgerLabel: displayName,
      occurredAt: occurredAt,
      type: type,
      amount: amount,
      currency: 'CNY',
      primaryCategoryName: null,
      categoryName: getBy('category'),
      accountName: getBy('account'),
      toAccountName: null,
      note: getBy('note'),
    );
  }

  static String? _typeFromIoFlag(String flag) {
    final t = flag.trim();
    if (t == '支出') return 'expense';
    if (t == '收入') return 'income';
    return null;
  }
}
