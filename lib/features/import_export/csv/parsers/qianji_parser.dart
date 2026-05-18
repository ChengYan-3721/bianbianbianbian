import '../../import_service.dart' show BackupImportCsvRow;
import 'generic_parser.dart';

/// 钱迹 (Qianji) 账单 CSV 解析器。
///
/// **来源**:钱迹 App → 我的 → 备份 → 导出 CSV。
///
/// **支持两种格式**:
/// 1. 8 列:`时间, 类型, 金额, 一级分类, 二级分类, 账户1, 账户2, 备注`
/// 2. 6 列:`日期, 分类, 子分类, 账户, 金额, 备注`
///
/// **关键护栏**:[validateBillType] 必须排除「账本」/「币种」列——本 App 9/10 列
/// CSV 含这两列,否则会被钱迹弱签名抢占。
class QianjiBillParser extends GenericBillParser {
  const QianjiBillParser();

  @override
  String get id => 'qianji';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '钱迹';

  @override
  bool validateBillType(List<List<String>> rows) =>
      _findHeaderRowByKeywords(rows) >= 0;

  @override
  int findHeaderRow(List<List<String>> rows) {
    final idx = _findHeaderRowByKeywords(rows);
    return idx >= 0 ? idx : super.findHeaderRow(rows);
  }

  static int _findHeaderRowByKeywords(List<List<String>> rows) {
    final scanLimit = rows.length < 10 ? rows.length : 10;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 4) continue;
      final cols = row.map((c) => c.trim()).toList();
      final joined = cols.join('|');
      final hasAmount = joined.contains('金额');
      final hasCat = joined.contains('分类') || joined.contains('类别');
      final hasDate = joined.contains('时间') || joined.contains('日期');
      if (!(hasAmount && hasCat && hasDate)) continue;
      // 排除本 App 9/10 列 CSV
      if (cols.contains('账本') || cols.contains('币种')) continue;
      return i;
    }
    return -1;
  }

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final base = super.mapColumns(headerRow);
    // 钱迹 8 列:账户1 → account;账户2 → to_account
    int? indexOf(String name) {
      for (var i = 0; i < headerRow.length; i++) {
        if (headerRow[i].trim() == name) return i;
      }
      return null;
    }
    final a1 = indexOf('账户1');
    final a2 = indexOf('账户2');
    if (a1 != null) base['account'] = a1;
    if (a2 != null) base['to_account'] = a2;
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

    final dateStr = getBy('date');
    if (dateStr == null) return null;
    // ignore: invalid_use_of_visible_for_testing_member
    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;

    final amountStr = getBy('amount');
    if (amountStr == null) return null;
    // ignore: invalid_use_of_visible_for_testing_member
    final amount = parseAmount(amountStr);
    if (amount == null) return null;
    if (amount == 0) return null; // 0 元跳过

    String type;
    final typeLabel = getBy('type');
    if (typeLabel != null) {
      final parsed = _typeFromQianjiLabel(typeLabel);
      if (parsed == null) return null;
      type = parsed;
    } else {
      type = 'expense'; // 6 列格式无独立类型列,兜底支出
    }

    final primary = getBy('primary_category');
    final category = getBy('category');

    final accountFrom = getBy('account') ?? getBy('from_account');
    final accountTo = getBy('to_account');

    return BackupImportCsvRow(
      ledgerLabel: '',
      occurredAt: occurredAt,
      type: type,
      amount: amount.abs(),
      currency: 'CNY',
      primaryCategoryName: primary,
      categoryName: category,
      accountName: accountFrom,
      toAccountName: type == 'transfer' ? accountTo : null,
      note: getBy('note'),
    );
  }

  static String? _typeFromQianjiLabel(String label) {
    final t = label.trim();
    if (t == '支出') return 'expense';
    if (t == '收入') return 'income';
    if (t == '转账') return 'transfer';
    return null;
  }
}
