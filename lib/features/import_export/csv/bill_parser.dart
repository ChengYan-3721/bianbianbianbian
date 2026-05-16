import 'package:flutter/foundation.dart' show immutable;

import '../import_service.dart' show BackupImportCsvRow;

/// CSV 账单解析器抽象(BeeCount 同构 + 本项目数据模型适配)。
///
/// 每个具体 parser 负责:
/// - [validateBillType]:扫前若干行判断是否能识别这个 CSV 的 header 签名。
/// - [findHeaderRow]:返回 header 行号(0-indexed),没有返回 -1。
/// - [mapColumns]:把 header 行转成「字段 key → 列索引」映射。
/// - [parseRow]:按 columnMapping 把单行解析为 [BackupImportCsvRow];
///   返回 null 表示该行应被跳过(空行 / 状态异常 / 无法解析的核心字段)。
///
/// 字段 key 集合(11 个):
/// `date / type / amount / currency / primary_category / category /
///  account / from_account / to_account / note / status`
abstract class BillParser {
  const BillParser();

  /// 唯一标识(不展示给用户)。
  String get id;

  /// 用户可见名称(导入页「识别为:xxx」显示)。
  String get displayName;

  /// 是否能识别此 CSV。
  bool validateBillType(List<List<String>> rows);

  /// header 行号;未找到返回 -1。
  int findHeaderRow(List<List<String>> rows);

  /// 字段 key → 列索引;未识别列被跳过。
  Map<String, int> mapColumns(List<String> headerRow);

  /// 解析单行。返回 null = 跳过该行。
  BackupImportCsvRow? parseRow(List<String> row, Map<String, int> columnMapping);
}

/// 解析结果(供 csv_format_detector 返回)。
@immutable
class ParseResult {
  const ParseResult({
    required this.parser,
    required this.rows,
  });

  final BillParser parser;
  final List<BackupImportCsvRow> rows;
}
