import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/attachment_meta_codec.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/attachment_meta.dart';
import '../../domain/entity/transaction_entry.dart';
import '../budget/budget_providers.dart';
import '../settings/settings_providers.dart';
import '../stats/stats_range_providers.dart';
import '../sync/sync_trigger.dart';
import 'record_providers.dart';

part 'record_new_providers.g.dart';

const _lastAccountKey = 'last_used_account_id';
const _maxAttachments = 3;

/// Step 11.2：单文件大小上限。超过后保存到本地时本应走 JPEG 压缩，但 V1
/// 不引入 `image` 包（pure-Dart 但体积偏大）；超限文件目前直接拒绝并提示
/// 用户。后续若需要无损压缩再引入 image 包，作为独立改动。
const int kMaxAttachmentBytes = 10 * 1024 * 1024;

/// 新建记账页的表单数据。
class RecordFormData {
  const RecordFormData({
    this.selectedParentKey = 'favorite',
    this.expression = '',
    this.amount,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    this.occurredAt,
    this.note = '',
    this.currency = 'CNY',
    this.editingEntryId,
    this.isTransfer = false,
    this.attachmentMetas = const <AttachmentMeta>[],
    this.categoryParentKey,
  });

  final String selectedParentKey;
  final String? categoryParentKey;
  final String expression;
  final double? amount;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId;
  final DateTime? occurredAt;
  final String note;
  final String currency;
  final String? editingEntryId;
  final bool isTransfer;

  /// Step 11.2 起：从 `List<String>` 升级为 `List<AttachmentMeta>`。
  ///
  /// 选图后立即落到 `<docs>/attachments/<txId>/...` 并构造一个仅有
  /// [AttachmentMeta.localPath] 的 meta，[AttachmentMeta.remoteKey] 与
  /// [AttachmentMeta.sha256] 为 null——下次同步时由
  /// `AttachmentUploader.uploadPending` 计算并回填。
  final List<AttachmentMeta> attachmentMetas;

  bool get canSave {
    final hasAmount = amount != null && amount! > 0;
    if (!hasAmount) return false;
    if (isTransfer) {
      return accountId != null &&
          toAccountId != null &&
          accountId != toAccountId;
    }
    return categoryId != null;
  }

  RecordFormData copyWith({
    String? selectedParentKey,
    String? expression,
    double? amount,
    String? Function()? categoryId,
    String? Function()? accountId,
    String? Function()? toAccountId,
    DateTime? Function()? occurredAt,
    String? note,
    String? currency,
    String? Function()? editingEntryId,
    bool? isTransfer,
    List<AttachmentMeta>? attachmentMetas,
    String? Function()? categoryParentKey,
  }) {
    return RecordFormData(
      selectedParentKey: selectedParentKey ?? this.selectedParentKey,
      expression: expression ?? this.expression,
      amount: amount ?? this.amount,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      accountId: accountId != null ? accountId() : this.accountId,
      toAccountId: toAccountId != null ? toAccountId() : this.toAccountId,
      occurredAt: occurredAt != null ? occurredAt() : this.occurredAt,
      note: note ?? this.note,
      currency: currency ?? this.currency,
      editingEntryId: editingEntryId != null ? editingEntryId() : this.editingEntryId,
      isTransfer: isTransfer ?? this.isTransfer,
      attachmentMetas: attachmentMetas ?? this.attachmentMetas,
      categoryParentKey: categoryParentKey != null ? categoryParentKey() : this.categoryParentKey,
    );
  }

  String get inferredType {
    if (isTransfer) return 'transfer';
    final effectiveParent = categoryParentKey ?? selectedParentKey;
    return effectiveParent == 'income' ? 'income' : 'expense';
  }
}

/// 简易表达式求值器——支持 `+`、`-` 的浮点运算。
///
/// 递归找到最后一个 `+`/`-` 作为分割点，左右分别求值后组合。
/// 无运算符的 token 直接 parseDouble，非法输入返回 `null`。
double? _parseExpr(String expr) {
  if (expr.isEmpty) return null;
  final numRe = RegExp(r'^\d+\.?\d*$');
  if (numRe.hasMatch(expr)) return double.tryParse(expr);

  int? splitAt;
  for (int i = expr.length - 1; i > 0; i--) {
    if (expr[i] == '+' || expr[i] == '-') {
      splitAt = i;
      break;
    }
  }
  if (splitAt == null) return null;

  final left = _parseExpr(expr.substring(0, splitAt));
  final right = _parseExpr(expr.substring(splitAt + 1));
  if (left == null || right == null) return null;

  return expr[splitAt] == '+' ? left + right : left - right;
}

@Riverpod(keepAlive: true)
class RecordForm extends _$RecordForm {
  @override
  RecordFormData build() => const RecordFormData();

  void setParentKey(String parentKey) {
    state = state.copyWith(
      selectedParentKey: parentKey,
      categoryId: () => null,
      categoryParentKey: () => null,
    );
  }

  void onKeyTap(String key) {
    final expr = state.expression;
    switch (key) {
      case '⌫':
        if (expr.isNotEmpty) {
          final next = expr.substring(0, max(0, expr.length - 1));
          final parsed = _parseExpr(next);
          state = state.copyWith(expression: next, amount: next.isEmpty ? 0 : parsed);
        }
        return;
      default:
        final isOp = key == '+' || key == '-';
        final last = expr.isNotEmpty ? expr[expr.length - 1] : null;
        final lastIsOp = last == '+' || last == '-';

        // 禁止连续运算符：若末尾已是 +/-, 再输入 +/-
        // 则替换末尾符号而不是追加。
        final next = isOp && lastIsOp
            ? '${expr.substring(0, expr.length - 1)}$key'
            : expr + key;

        state = state.copyWith(expression: next, amount: _parseExpr(next));
        return;
    }
  }

  bool get hasOperator =>
      state.expression.contains('+') || state.expression.contains('-');

  bool get canAction {
    if (hasOperator) {
      return _parseExpr(state.expression) != null;
    }
    return state.canSave;
  }

  void onActionTap() {
    if (hasOperator) {
      final v = _parseExpr(state.expression);
      if (v == null) return;
      final normalized = v.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
      state = state.copyWith(expression: normalized, amount: v);
      return;
    }
  }

  void toggleCurrency() {
    state = state.copyWith(currency: state.currency == 'CNY' ? 'USD' : 'CNY');
  }

  /// Step 8.2：直接设置当前选中的币种 code。供币种下拉选择器调用。
  void setCurrency(String code) {
    state = state.copyWith(currency: code);
  }

  /// Step 8.2：把表单的 currency 字段填为当前账本的默认币种。
  ///
  /// 新建模式开页时调用一次（FAB → reset → initDefaultCurrency）。
  /// `preloadFromEntry` 路径不调，编辑/复制使用 entry 自带的 currency。
  /// 已设置非 'CNY' 时不再覆盖（避免 reset 后的中途覆写争用）。
  Future<void> initDefaultCurrency() async {
    if (state.currency != 'CNY') return;
    final ledgerCurrency =
        await ref.read(currentLedgerDefaultCurrencyProvider.future);
    state = state.copyWith(currency: ledgerCurrency);
  }

  void setCategory(String? id, {String? parentKey}) =>
      state = state.copyWith(
        categoryId: () => id,
        categoryParentKey: () => id != null ? parentKey : null,
      );

  void setTransferMode(bool isTransfer) {
    state = state.copyWith(
      isTransfer: isTransfer,
      selectedParentKey: isTransfer ? 'other' : state.selectedParentKey,
      categoryId: isTransfer ? () => null : null,
      toAccountId: isTransfer ? () => null : null,
    );
  }

  void setAccount(String? id) => state = state.copyWith(accountId: () => id);

  void setToAccount(String? id) => state = state.copyWith(toAccountId: () => id);

  /// 自动填入默认账户：上次使用的 → 第一个活跃账户（现金）。
  Future<void> initDefaultAccount() async {
    if (state.accountId != null) return;
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_lastAccountKey);
    if (lastId != null) {
      setAccount(lastId);
      return;
    }
    final accRepo = await ref.read(accountRepositoryProvider.future);
    final accounts = await accRepo.listActive();
    if (accounts.isNotEmpty) {
      setAccount(accounts.first.id);
    }
  }

  void setOccurredAt(DateTime? dt) =>
      state = state.copyWith(occurredAt: () => dt);

  void setNote(String note) => state = state.copyWith(note: note);

  bool get canAddAttachment => state.attachmentMetas.length < _maxAttachments;

  Future<String?> pickAndAttachFromGallery() async {
    if (!canAddAttachment) return '最多只能选择$_maxAttachments张图片';
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return _attachPickedFile(picked);
  }

  Future<String?> pickAndAttachFromCamera() async {
    if (!canAddAttachment) return '最多只能选择$_maxAttachments张图片';
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return null;
    return _attachPickedFile(picked);
  }

  void removeAttachmentAt(int index) {
    final metas = [...state.attachmentMetas];
    if (index < 0 || index >= metas.length) return;
    metas.removeAt(index);
    state = state.copyWith(attachmentMetas: metas);
  }

  Future<String?> _attachPickedFile(XFile picked) async {
    final txId = state.editingEntryId ?? const Uuid().v4();
    if (state.editingEntryId == null) {
      state = state.copyWith(editingEntryId: () => txId);
    }

    final src = File(picked.path);
    final srcBytes = await src.readAsBytes();

    if (srcBytes.length > kMaxAttachmentBytes) {
      // V1：超过 10MB 直接拒绝。后续可引入 image 包做 JPEG 压缩。
      return '单张图片不能超过 10MB';
    }

    final srcHash = base64Encode(srcBytes);

    // 去重：同内容图片重复选择时直接提示（兼容系统返回不同临时路径）。
    for (final existing in state.attachmentMetas) {
      final localPath = existing.localPath;
      if (localPath == null) continue;
      final existingFile = File(localPath);
      if (!await existingFile.exists()) continue;
      final existingBytes = await existingFile.readAsBytes();
      final existingHash = base64Encode(existingBytes);
      if (existingHash == srcHash) {
        return '同一张图片不能重复添加';
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'attachments', txId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final originalName = p.basename(picked.path);
    final ext = p.extension(picked.path).toLowerCase();
    final normalizedExt = ext.isEmpty ? '.jpg' : ext;
    final filename = '${DateTime.now().microsecondsSinceEpoch}$normalizedExt';
    final targetPath = p.join(dir.path, filename);
    await src.copy(targetPath);

    final mime =
        lookupMimeType(targetPath) ?? 'application/octet-stream';
    final meta = AttachmentMeta(
      size: srcBytes.length,
      originalName: originalName.isEmpty ? filename : originalName,
      mime: mime,
      localPath: targetPath,
    );
    state = state.copyWith(
      attachmentMetas: [...state.attachmentMetas, meta],
    );
    return null;
  }

  Future<void> preloadFromEntry(
    TransactionEntry entry, {
    required String parentKey,
    bool asEdit = true,
  }) async {
    final amount = entry.amount;
    final normalized = amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');

    String? categoryParentKey;
    if (entry.categoryId != null) {
      final catRepo = await ref.read(categoryRepositoryProvider.future);
      final cats = await catRepo.listActiveAll();
      categoryParentKey = cats.where((c) => c.id == entry.categoryId).firstOrNull?.parentKey;
    }

    state = state.copyWith(
      selectedParentKey: parentKey,
      expression: normalized,
      amount: amount,
      categoryId: () => entry.categoryId,
      accountId: () => entry.accountId,
      toAccountId: () => entry.toAccountId,
      occurredAt: () => asEdit ? entry.occurredAt : DateTime.now(),
      note: entry.tags ?? '',
      currency: entry.currency,
      editingEntryId: () => asEdit ? entry.id : const Uuid().v4(),
      isTransfer: entry.type == 'transfer',
      attachmentMetas:
          AttachmentMetaCodec.decode(entry.attachmentsEncrypted),
      categoryParentKey: () => categoryParentKey,
    );
    await initDefaultAccount();
  }

  void reset() {
    state = const RecordFormData();
  }

  /// Step 11.2：BLOB 编解码统一走 [AttachmentMetaCodec]，保证 v9 新 shape 与
  /// 历史 v8 旧 shape（字符串数组）兼容——decode 端会把旧 string 自动包装成
  /// [AttachmentMeta]，encode 端永远输出 v9 形态。

  /// 保存流水。返回 `true` 表示成功。
  Future<bool> save() async {
    if (!state.canSave) return false;
    final d = state;

    final txRepo = await ref.read(transactionRepositoryProvider.future);
    final ledgerId = await ref.read(currentLedgerIdProvider.future);
    // Step 8.2：保存时计算"该币种 → 账本默认币种"的换算因子并连同 currency
    // 一起持久化到 transaction_entry.fx_rate。同币种 → 1.0，简化统计聚合
    // （`amount * fxRate` 始终是账本默认币种下的金额）。
    final ledgerCurrency =
        await ref.read(currentLedgerDefaultCurrencyProvider.future);
    final rates = await ref.read(fxRatesProvider.future);
    final fxRate = computeFxRate(d.currency, ledgerCurrency, rates);

    final tx = TransactionEntry(
      id: d.editingEntryId ?? const Uuid().v4(),
      ledgerId: ledgerId,
      type: d.inferredType,
      amount: d.amount!,
      currency: d.currency,
      fxRate: fxRate,
      categoryId: d.isTransfer ? null : d.categoryId,
      accountId: d.accountId,
      toAccountId: d.isTransfer ? d.toAccountId : null,
      occurredAt: d.occurredAt ?? DateTime.now(),
      tags: d.note.isEmpty ? null : d.note,
      attachmentsEncrypted: AttachmentMetaCodec.encode(d.attachmentMetas),
      updatedAt: DateTime.now(),
      deviceId: '', // repo 会覆写
    );

    await txRepo.save(tx);
    ref.invalidate(recordMonthSummaryProvider);
    ref.invalidate(statsLinePointsProvider);
    ref.invalidate(statsPieSlicesProvider);
    ref.invalidate(statsRankItemsProvider);
    ref.invalidate(statsHeatmapCellsProvider);
    ref.invalidate(budgetProgressForProvider);

    // Step 10.7：记账后 5 秒静默防抖触发同步。连续保存只触发最后一次。
    // SyncTrigger 内置「未配置云服务则跳过」保护——本地模式下相当于 no-op。
    // ignore: avoid_manual_providers_as_generated_provider_dependency
    ref.read(syncTriggerProvider.notifier).scheduleDebounced();

    // 持久化本次使用的钱包
    if (d.accountId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastAccountKey, d.accountId!);
    }

    return true;
  }
}
