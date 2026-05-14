import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../sync/snapshot_serializer.dart';
import 'bbbak_codec.dart';

/// 导出格式：
/// - [csv]：Excel 友好，9 列中文表头，体积小，**不**含全量结构（不可 round-trip 完美还原）；
/// - [json]：结构化全量备份，Step 13.3 可直接导入还原；明文，谁拿到都能读；
/// - [bbbak]：JSON + AES-256-GCM 加密的二进制包（Step 13.2），密码丢失无法恢复。
enum BackupFormat { csv, json, bbbak }

/// 导出范围：当前账本 / 全部账本。
enum BackupScope { currentLedger, allLedgers }

/// 时间区间 [start, end]（闭区间）；任一为 null 视为不限。
///
/// 仅过滤流水的 `occurredAt`，**不**过滤 ledger / category / account / budget——
/// 这些字段是账本结构数据，应保持完整以保证 round-trip 时引用完整。
@immutable
class BackupDateRange {
  const BackupDateRange({this.start, this.end});

  /// 不限定区间的常量。
  static const BackupDateRange unbounded = BackupDateRange();

  final DateTime? start;
  final DateTime? end;

  /// 任一边界存在即视为限定。
  bool get isBounded => start != null || end != null;

  bool contains(DateTime t) {
    if (start != null && t.isBefore(start!)) return false;
    if (end != null && t.isAfter(end!)) return false;
    return true;
  }
}

/// 多账本备份快照——JSON 输出的顶层信封。
///
/// 之所以再包一层而不直接导出 `List<LedgerSnapshot>`：① 给版本号留位置；
/// ② Step 13.3 导入时可由顶层 version 决定走哪条解析路径；③ device_id +
/// exported_at 让用户能从备份文件本身判断来源。
///
/// **不持久化任何数据库**——仅用于导出/导入的内存表达。
@immutable
class MultiLedgerSnapshot {
  static const int kVersion = 1;

  const MultiLedgerSnapshot({
    required this.version,
    required this.exportedAt,
    required this.deviceId,
    required this.ledgers,
  });

  final int version;
  final DateTime exportedAt;
  final String deviceId;
  final List<LedgerSnapshot> ledgers;

  Map<String, dynamic> toJson() => {
        'version': version,
        'exported_at': exportedAt.toIso8601String(),
        'device_id': deviceId,
        'ledgers': ledgers.map((l) => l.toJson()).toList(),
      };

  factory MultiLedgerSnapshot.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version > kVersion) {
      throw FormatException('Unsupported backup version: $version');
    }
    return MultiLedgerSnapshot(
      version: version,
      exportedAt: DateTime.parse(json['exported_at'] as String),
      deviceId: json['device_id'] as String,
      ledgers: (json['ledgers'] as List<dynamic>)
          .map((e) => LedgerSnapshot.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

const _csvBom = '\uFEFF';

/// CSV 列头——固定 9 列（账本 + 8 数据字段）。
///
/// **始终带账本列**——即使单账本导出也带：① 让 Step 13.3 round-trip 能识别归属；
/// ② 用户合并多份备份到同一文件时不至于丢失账本边界。这与 `stats_export_service`
/// 的 8 列 CSV 故意不同——那个是 ledger-scoped 的统计视图导出，本文件是跨账本备份。
// i18n-exempt: CSV column header for V1 Chinese format
const List<String> _backupCsvHeader = <String>[
  '账本',
  '日期',
  '类型',
  '金额',
  '币种',
  '分类',
  '账户',
  '转入账户',
  '备注',
];

// i18n-exempt: CSV format keyword
String _typeLabel(String type) {
  switch (type) {
    case 'income':
      return '收入';
    case 'expense':
      return '支出';
    case 'transfer':
      return '转账';
    default:
      return type;
  }
}

String _escapeField(String raw) {
  final needsQuote = raw.contains(',') ||
      raw.contains('"') ||
      raw.contains('\n') ||
      raw.contains('\r');
  final escaped = raw.replaceAll('"', '""');
  return needsQuote ? '"$escaped"' : escaped;
}

/// 按区间过滤快照内的流水，**不动**ledger / category / account / budget。
///
/// `range` 不限定时直接返回原对象；限定时构造一个新的 `LedgerSnapshot`，
/// 其余字段引用原对象（实体均为不可变）——零拷贝。
///
/// 这是公开 API（同时被 [ExportPage] 与单元测试消费），故无 `@visibleForTesting`。
LedgerSnapshot filterSnapshotByRange(
  LedgerSnapshot snap,
  BackupDateRange range,
) {
  if (!range.isBounded) return snap;
  return LedgerSnapshot(
    version: snap.version,
    exportedAt: snap.exportedAt,
    deviceId: snap.deviceId,
    ledger: snap.ledger,
    categories: snap.categories,
    accounts: snap.accounts,
    transactions: snap.transactions
        .where((tx) => range.contains(tx.occurredAt))
        .toList(growable: false),
    budgets: snap.budgets,
  );
}

/// 编码多账本快照为 CSV 字符串（UTF-8 BOM + 中文列头 + RFC4180 转义）。
///
/// 行序：先按 `snapshots` 顺序，组内按 `occurredAt` 升序。
/// 每个 snapshot 内的 transactions **必须已被调用方过滤过区间**——本函数不重复过滤。
@visibleForTesting
String encodeBackupCsv({required List<LedgerSnapshot> snapshots}) {
  final buffer = StringBuffer(_csvBom);
  buffer.writeln(_backupCsvHeader.map(_escapeField).join(','));

  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final amountFmt = NumberFormat('0.00');

  for (final snap in snapshots) {
    final coverEmoji = snap.ledger.coverEmoji;
    final ledgerLabel = (coverEmoji != null && coverEmoji.isNotEmpty)
        ? '$coverEmoji ${snap.ledger.name}'
        : snap.ledger.name;
    final categoryMap = <String, Category>{
      for (final c in snap.categories) c.id: c,
    };
    final accountMap = <String, Account>{
      for (final a in snap.accounts) a.id: a,
    };

    final entries = snap.transactions
        .where((tx) =>
            tx.type == 'income' ||
            tx.type == 'expense' ||
            tx.type == 'transfer')
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    for (final tx in entries) {
      final categoryName = tx.categoryId == null
          ? ''
          : (categoryMap[tx.categoryId!]?.name ?? '');
      final accountName = tx.accountId == null
          ? ''
          : (accountMap[tx.accountId!]?.name ?? '');
      final toAccountName = tx.toAccountId == null
          ? ''
          : (accountMap[tx.toAccountId!]?.name ?? '');

      final row = <String>[
        ledgerLabel,
        dateFmt.format(tx.occurredAt),
        _typeLabel(tx.type),
        amountFmt.format(tx.amount),
        tx.currency,
        categoryName,
        accountName,
        toAccountName,
        tx.tags ?? '',
      ];

      buffer.writeln(row.map(_escapeField).join(','));
    }
  }

  return buffer.toString();
}

/// 编码多账本快照为 JSON 字符串（unindented，体积优先；用户用文本编辑器看时需自己 pretty）。
@visibleForTesting
String encodeBackupJson(MultiLedgerSnapshot snapshot) =>
    jsonEncode(snapshot.toJson());

/// 构造导出文件名：`bianbian_backup_<scope>_<rangeStart>_<rangeEnd>_<timestamp>.<ext>`。
/// 不限定时间区间时省略两个 range 段。
@visibleForTesting
String buildBackupFileName({
  required String prefix,
  required String extension,
  required DateTime now,
  required BackupScope scope,
  required BackupDateRange range,
}) {
  final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
  final scopeTag = scope == BackupScope.currentLedger ? 'current' : 'all';
  if (range.isBounded) {
    final df = DateFormat('yyyyMMdd');
    final start = range.start != null ? df.format(range.start!) : 'min';
    final end = range.end != null ? df.format(range.end!) : 'max';
    return '${prefix}_${scopeTag}_${start}_${end}_$ts.$extension';
  }
  return '${prefix}_${scopeTag}_$ts.$extension';
}

/// 应用沙盒文档目录提供器（测试可注入）。
typedef BackupDocumentsDirProvider = Future<Directory> Function();

/// share_plus 注入接口（测试可注入）。
typedef BackupShareXFilesFn = Future<ShareResult> Function(
  List<XFile> files, {
  String? subject,
  String? text,
});

/// 备份导出服务——只承担"编码 + 落盘 + 分享"，数据收集由调用方负责。
///
/// 与 `stats_export_service.dart` 形态对称，但作用域不同：
/// - StatsExportService：当前账本 + 区间，CSV 8 列，附带 PNG 截图。
/// - BackupExportService：可跨账本，CSV 9 列（含账本），同时支持 JSON round-trip。
class BackupExportService {
  BackupExportService({
    BackupDocumentsDirProvider? documentsDirProvider,
    BackupShareXFilesFn? shareXFiles,
    DateTime Function()? now,
  })  : _documentsDirProvider =
            documentsDirProvider ?? getApplicationDocumentsDirectory,
        _shareXFiles = shareXFiles ?? _defaultShare,
        _now = now ?? DateTime.now;

  final BackupDocumentsDirProvider _documentsDirProvider;
  final BackupShareXFilesFn _shareXFiles;
  final DateTime Function() _now;

  static Future<ShareResult> _defaultShare(
    List<XFile> files, {
    String? subject,
    String? text,
  }) {
    return Share.shareXFiles(files, subject: subject, text: text);
  }

  /// `<documents>/exports/` 子目录写盘。与 StatsExportService 共享同一目录——
  /// 用户视角下"导出"是一个统一的概念，路径细分不带价值。
  Future<File> writeExportFile(String filename, List<int> bytes) async {
    final docs = await _documentsDirProvider();
    final exportsDir = Directory(p.join(docs.path, 'exports'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final file = File(p.join(exportsDir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// 导出 CSV：编码 + 落盘。返回写入的 File。
  Future<File> exportCsv({
    required List<LedgerSnapshot> snapshots,
    required BackupScope scope,
    required BackupDateRange range,
  }) async {
    final csv = encodeBackupCsv(snapshots: snapshots);
    final filename = buildBackupFileName(
      prefix: 'bianbian_backup',
      extension: 'csv',
      now: _now(),
      scope: scope,
      range: range,
    );
    return writeExportFile(filename, utf8.encode(csv));
  }

  /// 导出 JSON：编码 + 落盘。返回写入的 File。
  Future<File> exportJson({
    required MultiLedgerSnapshot multiSnapshot,
    required BackupScope scope,
    required BackupDateRange range,
  }) async {
    final json = encodeBackupJson(multiSnapshot);
    final filename = buildBackupFileName(
      prefix: 'bianbian_backup',
      extension: 'json',
      now: _now(),
      scope: scope,
      range: range,
    );
    return writeExportFile(filename, utf8.encode(json));
  }

  /// 导出 `.bbbak`：JSON 编码 → [BbbakCodec.encode] 加密 → 落盘。
  ///
  /// [password] 为用户在 UI 表单输入的"一次性密码"——本服务**不**持久化它，
  /// 调用方在拿到返回值后必须立即清除（如 `controller.clear()`）。
  ///
  /// 故意把密码作为参数注入而非 Service 字段：① 服务无状态便于测试；
  /// ② 避免长生命周期对象意外持有密码字符串导致内存常驻。
  Future<File> exportBbbak({
    required MultiLedgerSnapshot multiSnapshot,
    required String password,
    required BackupScope scope,
    required BackupDateRange range,
  }) async {
    final json = encodeBackupJson(multiSnapshot);
    final encrypted = await BbbakCodec.encode(
      Uint8List.fromList(utf8.encode(json)),
      password,
    );
    final filename = buildBackupFileName(
      prefix: 'bianbian_backup',
      extension: 'bbbak',
      now: _now(),
      scope: scope,
      range: range,
    );
    return writeExportFile(filename, encrypted);
  }

  /// 唤起系统 Share Sheet 分享文件。
  Future<void> shareFile(File file, {String? subject, String? text}) async {
    await _shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: text,
    );
  }
}
