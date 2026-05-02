import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';
import 'stats_range_providers.dart';

const _csvBom = '\uFEFF';

const _csvHeader = <String>[
  '日期',
  '类型',
  '金额',
  '币种',
  '分类',
  '账户',
  '转入账户',
  '备注',
];

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
  final needsQuote =
      raw.contains(',') || raw.contains('"') || raw.contains('\n') || raw.contains('\r');
  final escaped = raw.replaceAll('"', '""');
  return needsQuote ? '"$escaped"' : escaped;
}

@visibleForTesting
String encodeStatsCsv({
  required List<TransactionEntry> entries,
  required Map<String, Category> categoryMap,
  required Map<String, Account> accountMap,
  required StatsDateRange range,
}) {
  final buffer = StringBuffer(_csvBom);
  buffer.writeln(_csvHeader.map(_escapeField).join(','));

  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final amountFmt = NumberFormat('0.00');

  final filtered = entries.where((tx) {
    if (tx.type == 'transfer') return true;
    return tx.type == 'income' || tx.type == 'expense';
  }).where((tx) {
    final t = tx.occurredAt;
    return !t.isBefore(range.start) && !t.isAfter(range.end);
  }).toList()
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  for (final tx in filtered) {
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

  return buffer.toString();
}

@visibleForTesting
String buildExportFileName({
  required String prefix,
  required String extension,
  required DateTime now,
  required StatsDateRange range,
}) {
  final df = DateFormat('yyyyMMdd');
  final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
  final start = df.format(range.start);
  final end = df.format(range.end);
  return '${prefix}_${start}_${end}_$ts.$extension';
}

typedef DocumentsDirProvider = Future<Directory> Function();
typedef ShareXFilesFn = Future<ShareResult> Function(
  List<XFile> files, {
  String? subject,
  String? text,
});

class StatsExportService {
  StatsExportService({
    DocumentsDirProvider? documentsDirProvider,
    ShareXFilesFn? shareXFiles,
    DateTime Function()? now,
  })  : _documentsDirProvider =
            documentsDirProvider ?? getApplicationDocumentsDirectory,
        _shareXFiles = shareXFiles ?? _defaultShare,
        _now = now ?? DateTime.now;

  final DocumentsDirProvider _documentsDirProvider;
  final ShareXFilesFn _shareXFiles;
  final DateTime Function() _now;

  static Future<ShareResult> _defaultShare(
    List<XFile> files, {
    String? subject,
    String? text,
  }) {
    return Share.shareXFiles(files, subject: subject, text: text);
  }

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

  Future<File> exportCsv({
    required List<TransactionEntry> entries,
    required Map<String, Category> categoryMap,
    required Map<String, Account> accountMap,
    required StatsDateRange range,
  }) async {
    final csv = encodeStatsCsv(
      entries: entries,
      categoryMap: categoryMap,
      accountMap: accountMap,
      range: range,
    );
    final filename = buildExportFileName(
      prefix: 'bianbian_stats',
      extension: 'csv',
      now: _now(),
      range: range,
    );
    return writeExportFile(filename, utf8.encode(csv));
  }

  Future<Uint8List> capturePng(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
  }) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('boundary.toImage returned null bytes');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<File> exportPng({
    required RenderRepaintBoundary boundary,
    required StatsDateRange range,
    double pixelRatio = 3.0,
  }) async {
    final bytes = await capturePng(boundary, pixelRatio: pixelRatio);
    final filename = buildExportFileName(
      prefix: 'bianbian_stats',
      extension: 'png',
      now: _now(),
      range: range,
    );
    return writeExportFile(filename, bytes);
  }

  Future<void> shareFile(File file, {String? subject, String? text}) async {
    await _shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: text,
    );
  }
}
