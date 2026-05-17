import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:intl/intl.dart';

import '../../import_service.dart' show BackupImportCsvRow;
import '../bill_parser.dart';

/// 通用 CSV 账单解析器(BeeCount 同构)。
///
/// 识别策略:
/// - [validateBillType] 永远 true(兜底兜住所有列数一致的 CSV)。
/// - [findHeaderRow] 走「列数一致性」:在前 30 行中找一行,其列数 ≥ 3 且
///   后续 10 行内至少有 5 行列数与之一致;否则回 0。
/// - [mapColumns] 用 [normalizeToKey] 把任意中英文列名规范化到 11 个字段 key。
///
/// 子类(微信 / 支付宝 / 钱迹 / Bianbian)继承本类,通常仅覆写
/// [findHeaderRow] / [validateBillType] / [mapColumns];[parseRow] 多数情况
/// 沿用父类即可。
class GenericBillParser extends BillParser {
  const GenericBillParser();

  @override
  String get id => 'generic';

  @override
  // i18n-exempt: needs refactoring for l10n
  String get displayName => '通用 CSV';

  @override
  bool validateBillType(List<List<String>> rows) => true;

  @override
  int findHeaderRow(List<List<String>> rows) {
    if (rows.isEmpty) return -1;
    final byConsistency = _findHeaderByColumnConsistency(rows);
    if (byConsistency >= 0) return byConsistency;
    return 0; // 兜底
  }

  /// 列数一致性算法(BeeCount 同款):
  /// 在前 30 行中,找首个列数 ≥ 3 且后续 10 行内 ≥ 5 行列数与之相等的行。
  int _findHeaderByColumnConsistency(List<List<String>> rows) {
    final maxRows = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < maxRows; i++) {
      final cols = rows[i].length;
      if (cols < 3) continue;
      var consistent = 0;
      final checkEnd = rows.length < i + 11 ? rows.length : i + 11;
      for (var j = i + 1; j < checkEnd; j++) {
        if (rows[j].length == cols) consistent++;
      }
      if (consistent >= 5) return i;
    }
    return -1;
  }

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final mapping = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final key = normalizeToKey(headerRow[i]);
      if (key != null) {
        mapping.putIfAbsent(key, () => i);
      }
    }
    return mapping;
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
    final amountStr = getBy('amount');
    if (dateStr == null || amountStr == null) return null;

    final occurredAt = parseFlexibleDate(dateStr);
    if (occurredAt == null) return null;

    final amount = parseAmount(amountStr);
    if (amount == null) return null;

    final typeRaw = getBy('type');
    final type = _typeFromAnyLabel(typeRaw);
    if (type == null) return null;

    // 如果 CSV 中有账本列，使用其值；否则使用 displayName
    final ledgerLabel = getBy('ledger') ?? displayName;

    return BackupImportCsvRow(
      ledgerLabel: ledgerLabel,
      occurredAt: occurredAt,
      type: type,
      amount: amount.abs(),
      currency: getBy('currency') ?? 'CNY',
      primaryCategoryName: getBy('primary_category'),
      categoryName: getBy('category'),
      accountName: getBy('account') ?? getBy('from_account'),
      toAccountName: getBy('to_account'),
      note: getBy('note'),
    );
  }

  /// 把任意中英文列名规范化为 11 个字段 key 之一;不识别返回 null。
  ///
  /// **顺序敏感**:必须先匹配更长 / 更具体的中文词,再匹配宽泛词。
  /// 公开为 static + `@visibleForTesting` 供单元测试 + 子类直接调用。
  @visibleForTesting
  static String? normalizeToKey(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    final noSpace = lower.replaceAll(RegExp(r'\s+'), '');

    // 英文(精确)
    if (noSpace == 'date' ||
        noSpace == 'time' ||
        noSpace == 'datetime') {
      return 'date';
    }
    if (noSpace == 'type' ||
        noSpace == 'inout' ||
        noSpace == 'direction') {
      return 'type';
    }
    if (noSpace == 'amount' ||
        noSpace == 'money' ||
        noSpace == 'price' ||
        noSpace == 'value') {
      return 'amount';
    }
    if (noSpace == 'currency') {
      return 'currency';
    }
    if (noSpace == 'primarycategory' ||
        noSpace == 'parentcategory') {
      return 'primary_category';
    }
    if (noSpace == 'subcategory' ||
        noSpace == 'subcat' ||
        noSpace == 'category' ||
        noSpace == 'cate' ||
        noSpace == 'subject' ||
        noSpace == 'tag') {
      return 'category';
    }
    if (noSpace == 'note' ||
        noSpace == 'memo' ||
        noSpace == 'desc' ||
        noSpace == 'description' ||
        noSpace == 'remark' ||
        noSpace == 'title') {
      return 'note';
    }
    if (noSpace == 'fromaccount') {
      return 'from_account';
    }
    if (noSpace == 'toaccount') {
      return 'to_account';
    }
    if (noSpace == 'account') {
      return 'account';
    }
    if (noSpace == 'status') {
      return 'status';
    }

    // 中文(顺序敏感子串匹配)
    // 优先识别复合词,再处理短词
    if (_containsAny(s, ['账本'])) {
      return 'ledger';
    }
    if (_containsAny(s, ['一级分类', '父分类', '主分类'])) {
      return 'primary_category';
    }
    if (_containsAny(s, ['二级分类', '子分类', '次分类'])) {
      return 'category';
    }
    if (_containsAny(s, ['当前状态', '交易状态'])) {
      return 'status';
    }
    if (_containsAny(s, ['转出账户'])) {
      return 'from_account';
    }
    if (_containsAny(s, ['转入账户'])) {
      return 'to_account';
    }
    if (_containsAny(s, ['账户'])) {
      return 'account';
    }
    if (_containsAny(s, ['日期', '时间', '交易时间', '账单时间', '创建时间'])) {
      return 'date';
    }
    if (_containsAny(s, ['金额', '交易金额', '变动金额', '收支金额'])) {
      return 'amount';
    }
    if (_containsAny(s, ['币种', '货币'])) {
      return 'currency';
    }
    if (_containsAny(s, ['分类', '类别', '账目名称', '科目'])) {
      return 'category';
    }
    if (_containsAny(s, ['类型', '收支', '收/支', '方向'])) {
      return 'type';
    }
    if (_containsAny(s, ['备注', '说明', '标题', '摘要', '附言', '商品名称',
        '商品说明', '商品', '交易对方', '商家'])) {
      return 'note';
    }

    // 明确忽略
    if (_containsAny(s, ['账目编号', '编号', '单号', '流水号', '交易号',
        '相关图片', '图片', '交易单号', '订单号'])) {
      return null;
    }

    return null;
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  /// 「收/支」/「类型」原始值 → `income / expense / transfer`;
  /// 「/」/ 空 / 未识别返回 null(调用方决定跳过该行)。
  static String? _typeFromAnyLabel(String? label) {
    if (label == null) {
      return null;
    }
    final t = label.trim().toLowerCase();
    if (t == '收入' || t == '收' || t == 'income') {
      return 'income';
    }
    if (t == '支出' || t == '支' || t == '消费' || t == 'expense' ||
        t == 'spending') {
      return 'expense';
    }
    if (t == '转账' || t == 'transfer') {
      return 'transfer';
    }
    return null;
  }
}

/// 去除 `¥` / `￥` / `$` / 千位分隔逗号 / 引号包裹,再 [double.tryParse]。
/// 失败返回 null。
@visibleForTesting
double? parseAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll('¥', '').replaceAll('￥', '').replaceAll(r'$', '').trim();
  s = s.replaceAll(',', '').replaceAll('"', '').trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// 多格式日期解析(账单 vs 钱迹格式有差异)。失败返回 null。
@visibleForTesting
DateTime? parseFlexibleDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  const formats = [
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    'yyyy-MM-dd',
    'yyyy/MM/dd HH:mm:ss',
    'yyyy/MM/dd HH:mm',
    'yyyy/MM/dd',
  ];
  for (final f in formats) {
    try {
      return DateFormat(f).parseStrict(s);
    } on FormatException {
      // try next
    }
  }
  return null;
}

/// 把候选文本数组拼为单行备注,去除 null / 空 / 仅斜杠的项。
String? composeNote(List<String?> parts) {
  final keep = <String>[];
  for (final p in parts) {
    if (p == null) continue;
    final t = p.trim();
    if (t.isEmpty || t == '/') continue;
    keep.add(t);
  }
  return keep.isEmpty ? null : keep.join(' · ');
}
