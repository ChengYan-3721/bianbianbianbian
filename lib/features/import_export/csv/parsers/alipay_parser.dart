import '../../import_service.dart' show BackupImportCsvRow;
import 'generic_parser.dart';

/// 支付宝账单 CSV 解析器。
///
/// **来源**:支付宝 App → 我的 → 账单 → 开具交易流水证明 → 选 CSV → 邮箱。
/// 也可网页版导出。
///
/// **结构**:文件头说明 + header:
/// `交易号,商家订单号,交易创建时间,付款时间,最近修改时间,交易来源地,类型,
///  交易对方,商品名称,金额(元),收/支,交易状态,服务费(元),...`
///
/// **关键映射**(同 wechat 思路):
/// - 「类型」列(super 归到 `type`)移到 `category`;
/// - 「收/支」列保留在 `type`;
/// - account 固定为「支付宝」(账单本身没有账户列)。
class AlipayBillParser extends GenericBillParser {
  const AlipayBillParser();

  @override
  String get id => 'alipay_bill';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '支付宝账单';

  static const List<String> _headerSignals = [
    '交易号', '交易创建时间', '商品名称', '金额', '收/支',
  ];

  @override
  bool validateBillType(List<List<String>> rows) =>
      _findHeaderRowByKeywords(rows) >= 0;

  @override
  int findHeaderRow(List<List<String>> rows) {
    final idx = _findHeaderRowByKeywords(rows);
    return idx >= 0 ? idx : super.findHeaderRow(rows);
  }

  static int _findHeaderRowByKeywords(List<List<String>> rows) {
    final scanLimit = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 8) continue;
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
    final typeColIdx = indexOf('类型');
    final ioIdx = indexOf('收/支');
    if (typeColIdx != null) base['category'] = typeColIdx;
    if (ioIdx != null) base['type'] = ioIdx;
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

    final status = getBy('status') ?? '';
    if (status.contains('退款') ||
        status.contains('关闭') ||
        status.contains('失败')) {
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
      ledgerLabel: '',
      occurredAt: occurredAt,
      type: type,
      amount: amount,
      currency: 'CNY',
      primaryCategoryName: null,
      categoryName: getBy('category'),
      accountName: '支付宝',
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
