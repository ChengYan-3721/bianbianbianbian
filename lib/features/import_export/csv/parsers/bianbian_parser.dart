import '../../import_service.dart' show BackupImportCsvRow;
import 'generic_parser.dart';

/// 本 App 自有 CSV 格式(10 列严匹配 + 旧 9 列向后兼容)。
///
/// 10 列:`账本,日期,类型,金额,币种,一级分类,分类,账户,转入账户,备注`(Step 13.5)
/// 9  列:`账本,日期,类型,金额,币种,分类,账户,转入账户,备注`           (Step 13.1)
class BianbianBillParser extends GenericBillParser {
  const BianbianBillParser();

  @override
  String get id => 'bianbian';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '本 App';

  static const List<String> _header10 = [
    '账本', '日期', '类型', '金额', '币种', '一级分类', '分类',
    '账户', '转入账户', '备注',
  ];
  static const List<String> _header9 = [
    '账本', '日期', '类型', '金额', '币种', '分类',
    '账户', '转入账户', '备注',
  ];

  @override
  bool validateBillType(List<List<String>> rows) {
    if (rows.isEmpty) return false;
    final h = rows.first.map((c) => c.trim()).toList();
    return _matches(h, _header10) || _matches(h, _header9);
  }

  static bool _matches(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  @override
  int findHeaderRow(List<List<String>> rows) => 0;

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final h = headerRow.map((c) => c.trim()).toList();
    if (_matches(h, _header10)) {
      return {
        'ledger': 0,
        'date': 1,
        'type': 2,
        'amount': 3,
        'currency': 4,
        'primary_category': 5,
        'category': 6,
        'account': 7,
        'to_account': 8,
        'note': 9,
      };
    }
    if (_matches(h, _header9)) {
      return {
        'ledger': 0,
        'date': 1,
        'type': 2,
        'amount': 3,
        'currency': 4,
        'category': 5,
        'account': 6,
        'to_account': 7,
        'note': 8,
      };
    }
    return {};
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

    final ledger = getBy('ledger');
    final dateStr = getBy('date');
    final typeStr = getBy('type');
    final amountStr = getBy('amount');
    final currency = getBy('currency') ?? 'CNY';
    if (ledger == null || dateStr == null || typeStr == null || amountStr == null) {
      return null;
    }
    // ignore: invalid_use_of_visible_for_testing_member
    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;
    final type = _typeFromChinese(typeStr);
    if (type == null) return null;
    // ignore: invalid_use_of_visible_for_testing_member
    final amount = parseAmount(amountStr);
    if (amount == null) return null;

    return BackupImportCsvRow(
      ledgerLabel: ledger,
      occurredAt: occurredAt,
      type: type,
      amount: amount.abs(),
      currency: currency,
      primaryCategoryName: getBy('primary_category'),
      categoryName: getBy('category'),
      accountName: getBy('account'),
      toAccountName: getBy('to_account'),
      note: getBy('note'),
    );
  }

  static String? _typeFromChinese(String s) {
    switch (s.trim()) {
      case '收入':
      case 'income':
        return 'income';
      case '支出':
      case 'expense':
        return 'expense';
      case '转账':
      case 'transfer':
        return 'transfer';
      default:
        return null;
    }
  }
}
