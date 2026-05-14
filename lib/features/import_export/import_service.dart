import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/entity_mappers.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/category.dart';
import '../../domain/entity/transaction_entry.dart';
import 'bbbak_codec.dart';
import 'export_service.dart';
import 'templates/third_party_template.dart';

/// 导入文件类型——按文件后缀分流（用户选文件后立刻识别决定 UI 文案）。
///
/// - [json]：本 App 导出的 JSON 备份；顶层 `MultiLedgerSnapshot`，无密码。
/// - [bbbak]：本 App 导出的 `.bbbak` 加密备份；外壳是 [BbbakCodec] 二进制，
///   解密后是同 [json] 的字节流。
/// - [csv]：本 App 导出的 9 列 CSV（账本 / 日期 / 类型 / 金额 / 币种 / 分类
///   / 账户 / 转入账户 / 备注）；不含 ID，作为「全部新记录」导入。
enum BackupImportFileType { json, bbbak, csv }

/// 流水级去重策略（仅 `json` / `bbbak` 路径有意义；`csv` 由于无 ID
/// 强制走 [asNew]）。
enum BackupDedupeStrategy {
  /// 用 `transaction.id` 比对；该 id 在 DB 已存在则**整行跳过**（计入 skipped）。
  ///
  /// 适用：用户多次导入同一份 JSON / `.bbbak`，避免出现重复流水。
  skip,

  /// 用 `transaction.id` 比对；已有 id 走 `insertOrReplace` 整行覆盖。
  ///
  /// 适用：用户在不同设备各改了部分字段，希望以备份文件为准。**不**清空账本
  /// 其他流水——与 `importLedgerSnapshot`（Phase 10 同步那条路径）的「先 wipe
  /// 再 upsert」语义不同。
  overwrite,

  /// 给每条流水生成新 UUID v4，永不冲突。
  ///
  /// 适用：把别人的备份合并到自己账本（保留所有数据，不在意重复）。
  asNew,
}

/// 解析层错误——文件结构 / 编码 / 字段缺失等。**不**承载加密层错误（密码错
/// 由 [DecryptionFailure] 上抛；UI 层分流文案）。
class BackupImportException implements Exception {
  const BackupImportException(this.message);

  final String message;

  @override
  String toString() => 'BackupImportException: $message';
}

/// CSV 单行解析中间结果——保留**原始名称**（账本 / 分类 / 账户），应用阶段
/// 才与 DB 现有实体做 name → id 解析。
@immutable
class BackupImportCsvRow {
  const BackupImportCsvRow({
    required this.ledgerLabel,
    required this.occurredAt,
    required this.type,
    required this.amount,
    required this.currency,
    this.categoryName,
    this.accountName,
    this.toAccountName,
    this.note,
  });

  /// CSV「账本」列原值——可能是 `📒 生活` / `工作` 等；resolve 时去除 emoji + 空格。
  final String ledgerLabel;

  final DateTime occurredAt;

  /// 已规范化为 `'income'` / `'expense'` / `'transfer'`。
  final String type;
  final double amount;
  final String currency;
  final String? categoryName;
  final String? accountName;
  final String? toAccountName;
  final String? note;
}

/// UI 预览行——已字符串化，避免 UI 层重复格式化。
@immutable
class BackupImportPreviewRow {
  const BackupImportPreviewRow({
    this.ledgerLabel,
    required this.date,
    required this.type,
    required this.amount,
    required this.currency,
    this.category,
    this.account,
    this.toAccount,
    this.note,
  });

  final String? ledgerLabel;
  final String date;
  final String type;
  final String amount;
  final String currency;
  final String? category;
  final String? account;
  final String? toAccount;
  final String? note;
}

/// 文件预览总览——提供给 UI 渲染「前 20 行 + 元数据」+ 给 [BackupImportService.apply]
/// 当作不可变输入。
///
/// 字段职责：
/// - [fileType]：UI 文案分支 + apply 路径分流。
/// - [snapshot]：仅 `json` / `bbbak` 路径非空——含**全量**已解析数据，apply
///   时直接写库，无需重读文件。
/// - [csvRows]：仅 `csv` 路径非空——含**全量**解析行，apply 时按 fallback
///   ledger 写入；与 [snapshot] 互斥。
/// - [sampleRows]：UI 表格显示用，最多 20 行；与 [snapshot] / [csvRows] 是数据
///   重复但格式化过——避免 UI 层每次 build 都重格式化。
@immutable
class BackupImportPreview {
  const BackupImportPreview({
    required this.fileType,
    required this.ledgerCount,
    required this.transactionCount,
    required this.sampleRows,
    this.snapshot,
    this.csvRows,
    this.exportedAt,
    this.sourceDeviceId,
    this.thirdPartyTemplateId,
    this.thirdPartyTemplateName,
    this.unmappedCategoryCount = 0,
  });

  final BackupImportFileType fileType;

  /// 备份内含账本数。CSV 路径下统计**唯一 ledgerLabel** 的数量。
  final int ledgerCount;

  /// 备份内含流水总数（不限单账本）。
  final int transactionCount;

  /// 最多 20 行示例——UI 渲染表格用。
  final List<BackupImportPreviewRow> sampleRows;

  /// JSON / `.bbbak` 路径下持有的全量快照；CSV 路径下为 null。
  final MultiLedgerSnapshot? snapshot;

  /// CSV 路径下持有的全量解析行；JSON / `.bbbak` 路径下为 null。
  final List<BackupImportCsvRow>? csvRows;

  /// 备份导出时的时间戳（仅 JSON / `.bbbak` 有；CSV 无元数据）。
  final DateTime? exportedAt;

  /// 备份导出设备的 device_id（同上）。
  final String? sourceDeviceId;

  /// 命中的三方模板 id（如 `wechat_bill`），仅 CSV 路径且命中模板时非空。
  final String? thirdPartyTemplateId;

  /// 三方模板用户可见名（如「微信账单」）；UI 显示用。
  final String? thirdPartyTemplateName;

  /// 三方模板路径下，关键词→分类映射未命中归"其他"的行数；UI 用作提示。
  final int unmappedCategoryCount;
}

/// 导入应用结果——给 UI 显示「成功消息：写入 X 条流水，跳过 Y 条」。
@immutable
class BackupImportResult {
  const BackupImportResult({
    this.ledgersWritten = 0,
    this.categoriesWritten = 0,
    this.accountsWritten = 0,
    this.transactionsWritten = 0,
    this.transactionsSkipped = 0,
    this.budgetsWritten = 0,
    this.unresolvedLedgerLabels = const <String>{},
  });

  final int ledgersWritten;
  final int categoriesWritten;
  final int accountsWritten;
  final int transactionsWritten;
  final int transactionsSkipped;
  final int budgetsWritten;

  /// CSV 路径下，账本名 resolve 失败、走 fallback 的标签集合（提示用户）。
  final Set<String> unresolvedLedgerLabels;
}

/// 导入服务——只承担「解析 + 写库」，文件 IO（picker / 读字节）由调用方负责。
///
/// 与 `BackupExportService` 形态对称：
/// - export：`数据 → 编码 → 落盘 → 分享`；
/// - import：`读字节 → 解析 → 应用到 DB`。
///
/// **故意不直接消费 Repository**——repository 的 `save` 会写 sync_op 队列，
/// 导入瞬间灌入大量记录会立刻把 sync_op 撑满，下次同步触发就把刚导入的数据
/// 全量上传。本服务直接走 `db.batch + InsertMode.insertOrReplace`，与
/// `importLedgerSnapshot`（Phase 10 同步那条路径）一致——同步层用快照模型，
/// 整体覆盖时也不写 sync_op。
class BackupImportService {
  BackupImportService({
    Uuid? uuid,
    DateTime Function() clock = DateTime.now,
  })  : _uuid = uuid ?? const Uuid(),
        _clock = clock;

  final Uuid _uuid;
  final DateTime Function() _clock;

  /// 按文件名后缀识别类型。**不**读字节——给 UI 「选完文件立刻显示文件类型」用。
  ///
  /// 大小写不敏感；不识别的后缀抛 [BackupImportException]，由 UI 提示用户。
  static BackupImportFileType detectFileType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.bbbak')) return BackupImportFileType.bbbak;
    if (lower.endsWith('.json')) return BackupImportFileType.json;
    if (lower.endsWith('.csv')) return BackupImportFileType.csv;
    // i18n-exempt: needs refactoring for l10n
    throw BackupImportException(
      '不支持的文件类型：$fileName（仅支持 .json / .csv / .bbbak）',
    );
  }

  /// 解析文件 → 预览。**不写库**。
  ///
  /// - `json` / `bbbak`：解析为 [MultiLedgerSnapshot]，预览前 20 条流水。
  /// - `bbbak`：先 [BbbakCodec.decode] 解密（密码错抛 [DecryptionFailure]），
  ///   然后走 JSON 同路径。
  /// - `csv`：UTF-8 解码（带 BOM 兼容）→ RFC 4180 分行 → 9 列 header 校验
  ///   → 每行解析为 [BackupImportCsvRow]。
  ///
  /// 调用方负责把 [bytes]（来自文件）跟 [fileType]（来自 [detectFileType]）
  /// 配对传入；密码仅 `bbbak` 路径需要——其他路径传 null 即可。
  ///
  /// [bbbakIterations] 仅 `.bbbak` 路径用于 PBKDF2——生产保持默认；测试可降到
  /// 1 让套件保持秒级（语义已由 `bianbian_crypto_test.dart` KAT 套件保证）。
  Future<BackupImportPreview> preview({
    required Uint8List bytes,
    required BackupImportFileType fileType,
    String? password,
    int? bbbakIterations,
  }) async {
    switch (fileType) {
      case BackupImportFileType.bbbak:
        // i18n-exempt: needs refactoring for l10n
        if (password == null || password.isEmpty) {
          throw const BackupImportException('密码不能为空');
        }
        final decrypted = bbbakIterations == null
            ? await BbbakCodec.decode(bytes, password)
            : await BbbakCodec.decode(
                bytes,
                password,
                iterations: bbbakIterations,
              );
        return _previewJsonBytes(decrypted, BackupImportFileType.bbbak);
      case BackupImportFileType.json:
        return _previewJsonBytes(bytes, BackupImportFileType.json);
      case BackupImportFileType.csv:
        return _previewCsvBytes(bytes);
    }
  }

  /// 应用预览结果到数据库。
  ///
  /// - JSON / `.bbbak` 路径：按 [strategy] 决定流水级去重；categories /
  ///   accounts / ledgers / budgets 一律 upsert（这些是结构数据，不存在「跳过
  ///   重复」语义）。
  /// - CSV 路径：[strategy] 被忽略——CSV 无 ID，强制走 [BackupDedupeStrategy.asNew]。
  ///   ledger 名解析失败时回落到 [fallbackLedgerId]；分类 / 账户名 resolve
  ///   失败时该字段置 null（流水仍写入，只是引用空）。
  ///
  /// 在单个 [AppDatabase.transaction] 内完成——任一行失败回滚全部。
  Future<BackupImportResult> apply({
    required BackupImportPreview preview,
    required BackupDedupeStrategy strategy,
    required AppDatabase db,
    required String currentDeviceId,
    String? fallbackLedgerId,
  }) async {
    if (preview.fileType == BackupImportFileType.csv) {
      final rows = preview.csvRows;
      if (rows == null) {
        throw const BackupImportException('CSV 预览缺少 csvRows');
      }
      if (fallbackLedgerId == null) {
        throw const BackupImportException('CSV 导入需要 fallbackLedgerId');
      }
      return _applyCsv(
        rows: rows,
        db: db,
        currentDeviceId: currentDeviceId,
        fallbackLedgerId: fallbackLedgerId,
      );
    }
    final snap = preview.snapshot;
    if (snap == null) {
      throw const BackupImportException('JSON 预览缺少 snapshot');
    }
    return _applySnapshot(
      snapshot: snap,
      strategy: strategy,
      db: db,
      currentDeviceId: currentDeviceId,
    );
  }

  // ── JSON / .bbbak 路径 ─────────────────────────────────────────────────

    // i18n-exempt: needs refactoring for l10n
    BackupImportPreview _previewJsonBytes(
    Uint8List bytes,
    BackupImportFileType fileType,
  ) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException catch (e) {
      throw BackupImportException('JSON 文件不是合法 UTF-8：${e.message}');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw BackupImportException('JSON 解析失败：${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupImportException(
          'JSON 顶层不是对象（期望 MultiLedgerSnapshot）');
    }
    final MultiLedgerSnapshot snap;
    try {
      snap = MultiLedgerSnapshot.fromJson(decoded);
    } on FormatException catch (e) {
      throw BackupImportException('备份格式不识别：${e.message}');
    } on TypeError catch (e) {
      throw BackupImportException('备份字段类型不匹配：$e');
    }

    // 拼前 20 行预览
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final amountFmt = NumberFormat('0.00');
    final samples = <BackupImportPreviewRow>[];
    var totalTx = 0;
    for (final ls in snap.ledgers) {
      final coverEmoji = ls.ledger.coverEmoji;
      final ledgerLabel = (coverEmoji != null && coverEmoji.isNotEmpty)
          ? '$coverEmoji ${ls.ledger.name}'
          : ls.ledger.name;
      final categoryMap = <String, Category>{
        for (final c in ls.categories) c.id: c,
      };
      final accountMap = <String, Account>{
        for (final a in ls.accounts) a.id: a,
      };
      // 每个账本内按 occurredAt 升序，与 CSV 导出一致
      final entries = ls.transactions.toList()
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      for (final tx in entries) {
        totalTx++;
        if (samples.length >= 20) continue;
        samples.add(BackupImportPreviewRow(
          ledgerLabel: ledgerLabel,
          date: dateFmt.format(tx.occurredAt),
          type: _typeLabel(tx.type),
          amount: amountFmt.format(tx.amount),
          currency: tx.currency,
          category: tx.categoryId == null
              ? null
              : categoryMap[tx.categoryId!]?.name,
          account:
              tx.accountId == null ? null : accountMap[tx.accountId!]?.name,
          toAccount: tx.toAccountId == null
              ? null
              : accountMap[tx.toAccountId!]?.name,
          note: tx.tags,
        ));
      }
    }
    return BackupImportPreview(
      fileType: fileType,
      ledgerCount: snap.ledgers.length,
      transactionCount: totalTx,
      sampleRows: List.unmodifiable(samples),
      snapshot: snap,
      exportedAt: snap.exportedAt,
      sourceDeviceId: snap.deviceId,
    );
  }

  Future<BackupImportResult> _applySnapshot({
    required MultiLedgerSnapshot snapshot,
    required BackupDedupeStrategy strategy,
    required AppDatabase db,
    required String currentDeviceId,
  }) async {
    var ledgersWritten = 0;
    var categoriesWritten = 0;
    var accountsWritten = 0;
    var transactionsWritten = 0;
    var transactionsSkipped = 0;
    var budgetsWritten = 0;

    await db.transaction(() async {
      for (final ls in snapshot.ledgers) {
        // 1. 账本本体（始终 upsert——不存在跳过/覆盖区分）
        await db
            .into(db.ledgerTable)
            .insertOnConflictUpdate(ledgerToCompanion(ls.ledger));
        ledgersWritten++;

        // 2. 全局 categories / accounts upsert
        for (final c in ls.categories) {
          await db
              .into(db.categoryTable)
              .insertOnConflictUpdate(categoryToCompanion(c));
          categoriesWritten++;
        }
        for (final a in ls.accounts) {
          await db
              .into(db.accountTable)
              .insertOnConflictUpdate(accountToCompanion(a));
          accountsWritten++;
        }

        // 3. 流水按策略写入
        Set<String> existingIds = const <String>{};
        if (strategy == BackupDedupeStrategy.skip) {
          // 仅 skip 模式才需要预拉 id 集合——overwrite 走 upsert，asNew 必新生成。
          final rows = await (db.select(db.transactionEntryTable)
                ..where((t) => t.ledgerId.equals(ls.ledger.id)))
              .get();
          existingIds = rows.map((r) => r.id).toSet();
        }

        for (final tx in ls.transactions) {
          switch (strategy) {
            case BackupDedupeStrategy.skip:
              if (existingIds.contains(tx.id)) {
                transactionsSkipped++;
                break;
              }
              await db.into(db.transactionEntryTable).insert(
                    transactionEntryToCompanion(tx),
                    mode: InsertMode.insertOrAbort,
                  );
              transactionsWritten++;
              break;
            case BackupDedupeStrategy.overwrite:
              await db
                  .into(db.transactionEntryTable)
                  .insertOnConflictUpdate(transactionEntryToCompanion(tx));
              transactionsWritten++;
              break;
            case BackupDedupeStrategy.asNew:
              final reidentified = _reidTransaction(
                tx,
                newId: _uuid.v4(),
                deviceId: currentDeviceId,
                now: _clock(),
              );
              await db.into(db.transactionEntryTable).insert(
                    transactionEntryToCompanion(reidentified),
                    mode: InsertMode.insertOrAbort,
                  );
              transactionsWritten++;
              break;
          }
        }

        // 4. budgets 一律 upsert（无去重选项；预算 id 冲突即覆盖）
        for (final b in ls.budgets) {
          await db
              .into(db.budgetTable)
              .insertOnConflictUpdate(budgetToCompanion(b));
          budgetsWritten++;
        }
      }
    });

    return BackupImportResult(
      ledgersWritten: ledgersWritten,
      categoriesWritten: categoriesWritten,
      accountsWritten: accountsWritten,
      transactionsWritten: transactionsWritten,
      transactionsSkipped: transactionsSkipped,
      budgetsWritten: budgetsWritten,
    );
  }

  /// 重新身份化一条流水（asNew 模式专用）：换 id / 刷新 updatedAt / 改 deviceId
  /// / 清 deletedAt（即便源是软删流水也作为新 live 流水导入）。
  ///
  /// 不能直接用 `copyWith` —— 它的 `?? this.foo` 语义无法把 `deletedAt` 清空；
  /// 必须显式构造。
  static TransactionEntry _reidTransaction(
    TransactionEntry tx, {
    required String newId,
    required String deviceId,
    required DateTime now,
  }) =>
      TransactionEntry(
        id: newId,
        ledgerId: tx.ledgerId,
        type: tx.type,
        amount: tx.amount,
        currency: tx.currency,
        fxRate: tx.fxRate,
        categoryId: tx.categoryId,
        accountId: tx.accountId,
        toAccountId: tx.toAccountId,
        occurredAt: tx.occurredAt,
        noteEncrypted: tx.noteEncrypted,
        attachmentsEncrypted: tx.attachmentsEncrypted,
        tags: tx.tags,
        contentHash: tx.contentHash,
        updatedAt: now,
        deletedAt: null,
        deviceId: deviceId,
      );

  // ── CSV 路径 ───────────────────────────────────────────────────────────

    // i18n-exempt: needs refactoring for l10n
    BackupImportPreview _previewCsvBytes(Uint8List bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException catch (e) {
      throw BackupImportException('CSV 文件不是合法 UTF-8：${e.message}');
    }
    final stripped = stripUtf8Bom(text);
    final rows = parseCsvRows(stripped);
    if (rows.isEmpty) {
      throw const BackupImportException('CSV 文件为空');
    }

    // 优先尝试三方模板（钱迹 / 微信 / 支付宝）——header 签名命中即接管解析。
    // 未命中再走本 App 9 列 CSV。
    final thirdPartyMatch = detectThirdPartyTemplate(rows);
    if (thirdPartyMatch != null) {
      return _previewFromThirdPartyMatch(thirdPartyMatch);
    }

    final header = rows.first;
    if (!_isExpectedHeader(header)) {
      throw BackupImportException(
        'CSV 列头不识别（期望 9 列：${_kBackupCsvHeader.join(",")}；'
        '实际：${header.join(",")}）',
      );
    }
    final csvRows = <BackupImportCsvRow>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length == 1 && row[0].isEmpty) continue; // 空行跳过
      if (row.length != header.length) {
        throw BackupImportException(
          '第 ${i + 1} 行字段数不匹配（期望 ${header.length}，实际 ${row.length}）',
        );
      }
      try {
        csvRows.add(_parseCsvRow(row));
      } on FormatException catch (e) {
        throw BackupImportException('第 ${i + 1} 行解析失败：${e.message}');
      }
    }

    // 预览前 20 行 + 唯一账本标签计数
    final ledgerLabels = <String>{for (final r in csvRows) r.ledgerLabel};
    final amountFmt = NumberFormat('0.00');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final samples = <BackupImportPreviewRow>[];
    for (final r in csvRows.take(20)) {
      samples.add(BackupImportPreviewRow(
        ledgerLabel: r.ledgerLabel,
        date: dateFmt.format(r.occurredAt),
        type: _typeLabel(r.type),
        amount: amountFmt.format(r.amount),
        currency: r.currency,
        category: r.categoryName,
        account: r.accountName,
        toAccount: r.toAccountName,
        note: r.note,
      ));
    }
    return BackupImportPreview(
      fileType: BackupImportFileType.csv,
      ledgerCount: ledgerLabels.length,
      transactionCount: csvRows.length,
      sampleRows: List.unmodifiable(samples),
      csvRows: List.unmodifiable(csvRows),
    );
  }

  /// 三方模板路径——把 [ThirdPartyMatch.rows] 包成 [BackupImportPreview]。
  ///
  /// 字段语义：
  /// - `ledgerCount` 强制为 1：模板把所有流水写到 `displayName` 这个虚拟账本名，
  ///   apply 阶段会 unresolved → fallback 到当前账本。
  /// - `unmappedCategoryCount`：关键词命中"其他"的行数（提示用户精度）。
  BackupImportPreview _previewFromThirdPartyMatch(ThirdPartyMatch match) {
    final csvRows = match.rows;
    final amountFmt = NumberFormat('0.00');
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    var unmapped = 0;
    final samples = <BackupImportPreviewRow>[];
    for (final r in csvRows) {
      if (r.categoryName == kFallbackCategoryName) {
        unmapped++;
      }
      if (samples.length < 20) {
        samples.add(BackupImportPreviewRow(
          ledgerLabel: r.ledgerLabel,
          date: dateFmt.format(r.occurredAt),
          type: _typeLabel(r.type),
          amount: amountFmt.format(r.amount),
          currency: r.currency,
          category: r.categoryName,
          account: r.accountName,
          toAccount: r.toAccountName,
          note: r.note,
        ));
      }
    }
    return BackupImportPreview(
      fileType: BackupImportFileType.csv,
      ledgerCount: 1,
      transactionCount: csvRows.length,
      sampleRows: List.unmodifiable(samples),
      csvRows: List.unmodifiable(csvRows),
      thirdPartyTemplateId: match.template.id,
      thirdPartyTemplateName: match.template.displayName,
      unmappedCategoryCount: unmapped,
    );
  }

  Future<BackupImportResult> _applyCsv({
    required List<BackupImportCsvRow> rows,
    required AppDatabase db,
    required String currentDeviceId,
    required String fallbackLedgerId,
  }) async {
    // 预拉 ledger / category / account 列表用于 name → id 解析。
    final ledgers = await db.ledgerDao.listActive();
    final categories = await db.categoryDao.listActiveAll();
    final accounts = await db.accountDao.listActive();

    String? resolveLedgerId(String label) {
      final name = stripLedgerEmoji(label);
      for (final l in ledgers) {
        if (l.name == name) return l.id;
      }
      return null;
    }

    String? resolveCategoryId(String? name) {
      if (name == null || name.isEmpty) return null;
      for (final c in categories) {
        if (c.name == name) return c.id;
      }
      return null;
    }

    String? resolveAccountId(String? name) {
      if (name == null || name.isEmpty) return null;
      for (final a in accounts) {
        if (a.name == name) return a.id;
      }
      return null;
    }

    final unresolvedLabels = <String>{};
    var transactionsWritten = 0;
    await db.transaction(() async {
      for (final row in rows) {
        var ledgerId = resolveLedgerId(row.ledgerLabel);
        if (ledgerId == null) {
          ledgerId = fallbackLedgerId;
          unresolvedLabels.add(row.ledgerLabel);
        }
        final tx = TransactionEntry(
          id: _uuid.v4(),
          ledgerId: ledgerId,
          type: row.type,
          amount: row.amount,
          currency: row.currency,
          categoryId: resolveCategoryId(row.categoryName),
          accountId: resolveAccountId(row.accountName),
          toAccountId: resolveAccountId(row.toAccountName),
          occurredAt: row.occurredAt,
          tags: (row.note != null && row.note!.isNotEmpty) ? row.note : null,
          updatedAt: _clock(),
          deviceId: currentDeviceId,
        );
        await db.into(db.transactionEntryTable).insert(
              transactionEntryToCompanion(tx),
              mode: InsertMode.insertOrAbort,
            );
        transactionsWritten++;
      }
    });
    return BackupImportResult(
      transactionsWritten: transactionsWritten,
      unresolvedLedgerLabels: unresolvedLabels,
    );
  }

  // ── 静态 helper（@visibleForTesting 的对外工具）──────────────────────────

  // i18n-exempt: needs refactoring for l10n
  bool _isExpectedHeader(List<String> header) {
    if (header.length != _kBackupCsvHeader.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (header[i].trim() != _kBackupCsvHeader[i]) return false;
    }
    return true;
  }

  // i18n-exempt: format parsing error message
  BackupImportCsvRow _parseCsvRow(List<String> row) {
    // 9 列：账本,日期,类型,金额,币种,分类,账户,转入账户,备注
    final ledgerLabel = row[0].trim();
    final dateStr = row[1].trim();
    final typeLabel = row[2].trim();
    final amountStr = row[3].trim();
    final currency = row[4].trim();
    final categoryName = row[5].trim();
    final accountName = row[6].trim();
    final toAccountName = row[7].trim();
    final note = row[8];

    if (ledgerLabel.isEmpty) {
      throw const FormatException('账本列为空');
    }
    if (dateStr.isEmpty) {
      throw const FormatException('日期列为空');
    }
    final occurredAt = _parseCsvDate(dateStr);

    final type = _typeFromLabel(typeLabel);
    if (type == null) {
      throw FormatException('类型无法识别：$typeLabel');
    }
    final amount = double.tryParse(amountStr);
    if (amount == null) {
      throw FormatException('金额无法解析：$amountStr');
    }
    if (currency.isEmpty) {
      throw const FormatException('币种列为空');
    }

    return BackupImportCsvRow(
      ledgerLabel: ledgerLabel,
      occurredAt: occurredAt,
      type: type,
      amount: amount,
      currency: currency,
      categoryName: categoryName.isEmpty ? null : categoryName,
      accountName: accountName.isEmpty ? null : accountName,
      toAccountName: toAccountName.isEmpty ? null : toAccountName,
      note: note.isEmpty ? null : note,
    );
  }

  // i18n-exempt: format parsing error message
  static DateTime _parseCsvDate(String s) {
    // 主格式：yyyy-MM-dd HH:mm（与 export 一致）
    // 兼容：yyyy-MM-dd（兜底）
    try {
      return DateFormat('yyyy-MM-dd HH:mm').parseStrict(s);
    } on FormatException {
      // 尝试兼容
    }
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(s);
    } on FormatException {
      throw FormatException('日期格式不识别（期望 yyyy-MM-dd HH:mm）：$s');
    }
  }

  // i18n-exempt: format parsing keyword
  static String? _typeFromLabel(String label) {
    switch (label) {
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

  // i18n-exempt: format parsing error message
  static String _typeLabel(String type) {
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
}

/// CSV 列头常量——与 [encodeBackupCsv] 字节级一致；任何一边改了另一边必须同步。
// i18n-exempt: CSV column header for V1 Chinese format
const List<String> _kBackupCsvHeader = <String>[
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

/// 去掉 UTF-8 BOM（`\uFEFF`）。CSV 导出时显式带 BOM 让 Excel 识别中文，导入
/// 时必须先剥离否则 header 行第一列会变成 `\uFEFF账本`。
@visibleForTesting
String stripUtf8Bom(String s) =>
    s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF ? s.substring(1) : s;

/// 去掉账本标签前的 emoji 前缀。
///
/// 导出时 `LedgerSnapshot.ledger.coverEmoji != null` 会拼成 `📒 生活`；导入
/// 时按"原 ledger.name"匹配 DB，故需把 emoji + 后续空格剥离。
///
/// 策略：从首字符开始向后扫，跳过所有 surrogate pair / 非 ASCII 非 CJK 字符
/// + 空白；遇到第一个 ASCII 字母数字 / CJK 字符即停。**不**做严格 emoji 表
/// 匹配——以防遗漏新 emoji；用「不是文本字符」做判定足够实用。
@visibleForTesting
String stripLedgerEmoji(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return trimmed;
  final runes = trimmed.runes.toList();
  var skip = 0;
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    if (_isLikelyTextChar(r)) {
      break;
    }
    skip++;
  }
  if (skip == 0) return trimmed;
  final remaining = String.fromCharCodes(runes.skip(skip));
  return remaining.trimLeft();
}

/// 「文本字符」判定：ASCII 字母数字 / 中文 / 常见标点。其他（emoji /
/// 私用区 / surrogate）一律视作"装饰前缀"。
bool _isLikelyTextChar(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return true; // 0-9
  if (rune >= 0x41 && rune <= 0x5A) return true; // A-Z
  if (rune >= 0x61 && rune <= 0x7A) return true; // a-z
  if (rune == 0x5F || rune == 0x2D) return true; // _ -
  if (rune >= 0x4E00 && rune <= 0x9FFF) return true; // CJK 基本块
  if (rune >= 0x3400 && rune <= 0x4DBF) return true; // CJK 扩展 A
  if (rune >= 0x20000 && rune <= 0x2A6DF) return true; // CJK 扩展 B
  return false;
}

/// RFC 4180 行解析——支持双引号包裹 / 双引号转义（`""`）/ 字段内换行。
///
/// 与 Dart 标准库无关——故意不引 `csv` package，本项目只需要双向 RFC 4180，
/// 自带的 50 行实现足够覆盖。
@visibleForTesting
List<List<String>> parseCsvRows(String input) {
  final rows = <List<String>>[];
  final cells = <String>[];
  final buf = StringBuffer();
  var inQuote = false;
  var i = 0;
  void endCell() {
    cells.add(buf.toString());
    buf.clear();
  }

  void endRow() {
    endCell();
    rows.add(List<String>.unmodifiable(cells));
    cells.clear();
  }

  while (i < input.length) {
    final c = input[i];
    if (inQuote) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          buf.write('"');
          i += 2;
          continue;
        }
        inQuote = false;
        i++;
        continue;
      }
      buf.write(c);
      i++;
    } else {
      if (c == '"') {
        inQuote = true;
        i++;
      } else if (c == ',') {
        endCell();
        i++;
      } else if (c == '\r') {
        // \r\n / \r 都视为行尾
        endRow();
        if (i + 1 < input.length && input[i + 1] == '\n') {
          i += 2;
        } else {
          i++;
        }
      } else if (c == '\n') {
        endRow();
        i++;
      } else {
        buf.write(c);
        i++;
      }
    }
  }
  // 末尾未以换行结束的最后一行
  if (buf.isNotEmpty || cells.isNotEmpty) {
    endRow();
  }
  return rows;
}
