import 'dart:convert';
import 'dart:typed_data';

/// 流水（交易条目）领域实体——`transaction_entry` 表的纯 Dart 镜像（设计文档 §7.1）。
///
/// **不依赖 drift**。drift 数据类**故意**叫 `TransactionEntryRow`（见
/// `transaction_entry_table.dart` 的 `@DataClassName` 注解），把 `TransactionEntry`
/// 这个名字留给本领域实体。
///
/// ## 类型收紧
/// - `fxRate`：drift 层 `double?`（默认 1.0）；实体层非空默认 `1.0`。
/// - `amount`：drift 层 `double` 非空；实体层沿用。**`amount` 始终为正数**，
///   方向由 `type` 决定（`expense` 支出 / `income` 收入 / `transfer` 转账）。
/// - `occurredAt`, `updatedAt`, `deletedAt`：drift 层 `int` epoch ms，实体层
///   `DateTime`。
///
/// ## `noteEncrypted` / `attachmentsEncrypted`
/// drift 层是 `Uint8List?`（BLOB），实体层也是 `Uint8List?`——Phase 11 才会
/// 放密文，Step 3.5 之前可以先塞明文 JSON（Phase 2/3 不消费这两列）。**注意
/// `Uint8List` 在 Dart 中是 ***引用相等***，所以本类的 `==` / `hashCode`
/// 走 [_bytesEqual] / [_bytesHash] 做深比较**；否则 roundtrip 测试会假阴。
///
/// ## JSON 格式
/// 同 [Ledger] 一样走 snake_case + ISO8601。`note_encrypted` /
/// `attachments_encrypted` 走 **base64** 字符串——JSON 本身不支持二进制，
/// base64 能原样 roundtrip，且与 Phase 10 Supabase bytea 列的 PostgREST
/// 编码一致。
class TransactionEntry {
  const TransactionEntry({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.amount,
    required this.currency,
    this.fxRate = 1.0,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    required this.occurredAt,
    this.noteEncrypted,
    this.attachmentsEncrypted,
    this.tags,
    this.contentHash,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
  });

  final String id;
  final String ledgerId;
  final String type; // income | expense | transfer
  final double amount;
  final String currency;
  final double fxRate;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId; // 仅 transfer 时非空
  final DateTime occurredAt;
  final Uint8List? noteEncrypted;
  final Uint8List? attachmentsEncrypted;
  final String? tags; // 逗号分隔
  final String? contentHash;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;

  TransactionEntry copyWith({
    String? id,
    String? ledgerId,
    String? type,
    double? amount,
    String? currency,
    double? fxRate,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    DateTime? occurredAt,
    Uint8List? noteEncrypted,
    Uint8List? attachmentsEncrypted,
    String? tags,
    String? contentHash,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deviceId,
  }) {
    return TransactionEntry(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      fxRate: fxRate ?? this.fxRate,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      noteEncrypted: noteEncrypted ?? this.noteEncrypted,
      attachmentsEncrypted: attachmentsEncrypted ?? this.attachmentsEncrypted,
      tags: tags ?? this.tags,
      contentHash: contentHash ?? this.contentHash,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledger_id': ledgerId,
        'type': type,
        'amount': amount,
        'currency': currency,
        'fx_rate': fxRate,
        'category_id': categoryId,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'occurred_at': occurredAt.toIso8601String(),
        'note_encrypted':
            noteEncrypted == null ? null : base64Encode(noteEncrypted!),
        'attachments_encrypted': attachmentsEncrypted == null
            ? null
            : base64Encode(attachmentsEncrypted!),
        'tags': tags,
        'content_hash': contentHash,
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'device_id': deviceId,
      };

  factory TransactionEntry.fromJson(Map<String, dynamic> json) =>
      TransactionEntry(
        id: json['id'] as String,
        ledgerId: json['ledger_id'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        fxRate: (json['fx_rate'] as num?)?.toDouble() ?? 1.0,
        categoryId: json['category_id'] as String?,
        accountId: json['account_id'] as String?,
        toAccountId: json['to_account_id'] as String?,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        noteEncrypted: json['note_encrypted'] == null
            ? null
            : base64Decode(json['note_encrypted'] as String),
        attachmentsEncrypted: json['attachments_encrypted'] == null
            ? null
            : base64Decode(json['attachments_encrypted'] as String),
        tags: json['tags'] as String?,
        contentHash: json['content_hash'] as String?,
        updatedAt: DateTime.parse(json['updated_at'] as String),
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at'] as String),
        deviceId: json['device_id'] as String,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionEntry &&
        other.id == id &&
        other.ledgerId == ledgerId &&
        other.type == type &&
        other.amount == amount &&
        other.currency == currency &&
        other.fxRate == fxRate &&
        other.categoryId == categoryId &&
        other.accountId == accountId &&
        other.toAccountId == toAccountId &&
        other.occurredAt == occurredAt &&
        _bytesEqual(other.noteEncrypted, noteEncrypted) &&
        _bytesEqual(other.attachmentsEncrypted, attachmentsEncrypted) &&
        other.tags == tags &&
        other.contentHash == contentHash &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        ledgerId,
        type,
        amount,
        currency,
        fxRate,
        categoryId,
        accountId,
        toAccountId,
        occurredAt,
        _bytesHash(noteEncrypted),
        _bytesHash(attachmentsEncrypted),
        tags,
        contentHash,
        updatedAt,
        Object.hash(deletedAt, deviceId),
      );

  @override
  String toString() => 'TransactionEntry(id: $id, ledgerId: $ledgerId, '
      'type: $type, amount: $amount, currency: $currency, fxRate: $fxRate, '
      'categoryId: $categoryId, accountId: $accountId, '
      'toAccountId: $toAccountId, occurredAt: $occurredAt, '
      'noteEncrypted: ${noteEncrypted?.length ?? 0}B, '
      'attachmentsEncrypted: ${attachmentsEncrypted?.length ?? 0}B, '
      'tags: $tags, contentHash: $contentHash, updatedAt: $updatedAt, '
      'deletedAt: $deletedAt, deviceId: $deviceId)';
}

bool _bytesEqual(Uint8List? a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _bytesHash(Uint8List? bytes) {
  if (bytes == null) return 0;
  return Object.hashAll(bytes);
}
