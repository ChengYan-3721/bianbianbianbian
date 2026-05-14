import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../settings/ai_input_settings_providers.dart';

// i18n-exempt: service error message (no BuildContext available)
// All Chinese strings in this file are thrown as AiEnhanceException and
// caught in the UI layer where they are localized via ARB keys.

/// Step 9.3：AI 增强返回的解析结果。
///
/// 与 [QuickParseResult] 的字段集刻意保持子集语义——LLM 的角色是"补救本地
/// 解析的低置信度结果"，不引入新维度。confidence 字段不再需要（LLM 命中即按 1.0 计）。
@immutable
class AiEnhanceResult {
  const AiEnhanceResult({
    this.amount,
    this.categoryParentKey,
    this.occurredAt,
    this.note,
  });

  final double? amount;

  /// 一级分类 key，与 `seeder.dart::categoriesByParent.keys` 同集。
  final String? categoryParentKey;

  /// LLM 返回的发生日期（解析为本地时区当天 00:00；时分由调用方补当前）。
  final DateTime? occurredAt;

  final String? note;

  @override
  String toString() {
    return 'AiEnhanceResult(amount: $amount, parent: $categoryParentKey, '
        'date: $occurredAt, note: $note)';
  }
}

/// Step 9.3：AI 增强失败的统一异常类型。UI 层捕获后展示 SnackBar
/// `'AI 解析失败：$message'`。
class AiEnhanceException implements Exception {
  const AiEnhanceException(this.message);
  final String message;

  @override
  String toString() => 'AiEnhanceException: $message';
}

/// Step 9.3：合法的一级分类 key 集——用于校验 LLM 返回的
/// `category_parent_key`。值越界（编 / 错拼）都视为非法，丢弃该字段。
///
/// 与 `seeder.dart::categoriesByParent.keys` / `quick_text_parser._parentKeyLabels`.keys
/// 同集；此处复制是 implementation-plan §9.3 验证 3 "响应的 JSON 不符合 schema
/// 时不崩溃（严格校验）" 的实现要点之一。
const Set<String> kValidParentKeys = {
  'income',
  'food',
  'shopping',
  'transport',
  'education',
  'entertainment',
  'social',
  'housing',
  'medical',
  'investment',
  'other',
};

/// Step 9.3：基于用户配置的 LLM endpoint 调用 Chat Completions 协议
/// 增强本地解析结果。
///
/// 设计要点（与 implementation-plan §9.3 三条验证一一对齐）：
/// 1. **没有配置 API 时按钮不显示**：服务层不直接负责按钮显隐——由
///    [AiInputSettings.hasMinimalConfig] 守门；调用方（[QuickConfirmCard]）watch
///    settings 后决定渲染。但服务的 [enhance] 仍兜底校验，缺配置抛
///    [AiEnhanceException]，避免被 UI 路径绕过。
/// 2. **网络失败回退本地结果**：HTTP / 超时 / 解析异常一律抛 [AiEnhanceException]，
///    UI 层 catch 后展示 SnackBar 不修改卡片字段——本地基线即兜底。
/// 3. **响应 JSON 不符合 schema 不崩溃**：[parseEnhanceJson] 严格校验
///    （类型 / 取值范围 / 日期格式），任意非法都抛 [AiEnhanceException]，绝不
///    向上层泄露解码异常。
class AiInputEnhanceService {
  AiInputEnhanceService({
    required this.settings,
    http.Client? httpClient,
    DateTime Function()? clock,
    Duration timeout = const Duration(seconds: 30),
  })  : _client = httpClient ?? http.Client(),
        _clock = clock ?? DateTime.now,
        _timeout = timeout;

  final AiInputSettings settings;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration _timeout;

  /// 调用 LLM 增强；输入只需 raw text，prompt 模板内的占位符在本方法内替换。
  ///
  /// 失败语义：所有失败都抛 [AiEnhanceException]，调用方（[QuickConfirmCard]）
  /// 用 `try/catch` 套一层 SnackBar 即可。
  Future<AiEnhanceResult> enhance(String rawText) async {
    if (!settings.hasMinimalConfig) {
      throw const AiEnhanceException('未配置 AI 增强（需启用并填写 endpoint / key / model）');
    }

    final url = Uri.tryParse(settings.endpoint!.trim());
    if (url == null || !url.hasAbsolutePath) {
      throw AiEnhanceException('endpoint 不是合法 URL：${settings.endpoint}');
    }

    final prompt = _buildPrompt(rawText);
    final body = jsonEncode({
      'model': settings.model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0,
      'response_format': {'type': 'json_object'},
    });

    http.Response resp;
    try {
      resp = await _client
          .post(
            url,
            headers: {
              'Authorization': 'Bearer ${settings.apiKey!.trim()}',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiEnhanceException('网络请求超时');
    } catch (e) {
      throw AiEnhanceException('网络请求失败：$e');
    }

    if (resp.statusCode != 200) {
      throw AiEnhanceException('LLM 返回 HTTP ${resp.statusCode}');
    }

    final content = _extractMessageContent(resp.body);
    return parseEnhanceJson(content);
  }

  /// 替换 prompt 模板中的占位符。public-ish via @visibleForTesting，
  /// 便于测试断言"占位符是否被实际替换"。
  @visibleForTesting
  String buildPromptForTesting(String rawText) => _buildPrompt(rawText);

  String _buildPrompt(String rawText) {
    final tpl = settings.effectivePromptTemplate;
    final now = _clock();
    final nowStr =
        '${now.year}-${_pad2(now.month)}-${_pad2(now.day)} ${_pad2(now.hour)}:${_pad2(now.minute)}';
    final cats = kValidParentKeys.join(' / ');
    return tpl
        .replaceAll('{NOW}', nowStr)
        .replaceAll('{TEXT}', rawText)
        .replaceAll('{CATEGORIES}', cats);
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// 从 OpenAI Chat Completions 响应中抽取 `choices[0].message.content`。
  /// 任何字段缺失 / 类型不符直接抛 [AiEnhanceException]。
  String _extractMessageContent(String responseBody) {
    dynamic root;
    try {
      root = jsonDecode(responseBody);
    } catch (e) {
      throw AiEnhanceException('LLM 响应不是合法 JSON：$e');
    }
    if (root is! Map) {
      throw const AiEnhanceException('LLM 响应根不是 JSON 对象');
    }
    final choices = root['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiEnhanceException('LLM 响应缺少 choices');
    }
    final first = choices.first;
    if (first is! Map) throw const AiEnhanceException('LLM 响应 choice 非对象');
    final msg = first['message'];
    if (msg is! Map) throw const AiEnhanceException('LLM 响应缺少 message');
    final content = msg['content'];
    if (content is! String || content.isEmpty) {
      throw const AiEnhanceException('LLM 响应 content 非字符串');
    }
    return content;
  }
}

/// Step 9.3：严格解析 LLM 返回的 JSON 字符串为 [AiEnhanceResult]。
///
/// **可见性**：顶层 + `@visibleForTesting`，便于测试覆盖各种"非法 schema"分支。
/// 生产路径只通过 [AiInputEnhanceService.enhance] 间接调用。
///
/// 校验规则（任一不通过即抛 [AiEnhanceException]，不返回部分解析结果）：
/// - 必须是 JSON 对象；
/// - `amount`：number 或 null；非 null 时必须 > 0 且 isFinite；
/// - `category_parent_key`：string 或 null；非 null 时必须在 [kValidParentKeys] 内；
/// - `occurred_at`：string（YYYY-MM-DD 格式）或 null；非 null 时必须能 [DateTime.parse]；
/// - `note`：string 或 null；空字符串视为 null。
///
/// 缺失字段（key 不存在）等价于 null。
@visibleForTesting
AiEnhanceResult parseEnhanceJson(String jsonStr) {
  dynamic decoded;
  try {
    decoded = jsonDecode(jsonStr);
  } catch (e) {
    throw AiEnhanceException('LLM 返回的 content 不是合法 JSON：$e');
  }
  if (decoded is! Map) {
    throw const AiEnhanceException('LLM 返回 content 根不是 JSON 对象');
  }

  // amount
  double? amount;
  final rawAmount = decoded['amount'];
  if (rawAmount != null) {
    if (rawAmount is! num) {
      throw AiEnhanceException('amount 字段类型非法：${rawAmount.runtimeType}');
    }
    final v = rawAmount.toDouble();
    if (!v.isFinite || v <= 0) {
      throw AiEnhanceException('amount 不是有效正数：$v');
    }
    amount = v;
  }

  // category_parent_key
  String? categoryParentKey;
  final rawCat = decoded['category_parent_key'];
  if (rawCat != null && rawCat != '') {
    if (rawCat is! String) {
      throw AiEnhanceException(
        'category_parent_key 字段类型非法：${rawCat.runtimeType}',
      );
    }
    if (!kValidParentKeys.contains(rawCat)) {
      throw AiEnhanceException('category_parent_key 取值非法：$rawCat');
    }
    categoryParentKey = rawCat;
  }

  // occurred_at
  DateTime? occurredAt;
  final rawDate = decoded['occurred_at'];
  if (rawDate != null && rawDate != '') {
    if (rawDate is! String) {
      throw AiEnhanceException('occurred_at 字段类型非法：${rawDate.runtimeType}');
    }
    try {
      final parsed = DateTime.parse(rawDate);
      occurredAt = DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      throw AiEnhanceException('occurred_at 不是合法 ISO 日期：$rawDate');
    }
  }

  // note
  String? note;
  final rawNote = decoded['note'];
  if (rawNote != null) {
    if (rawNote is! String) {
      throw AiEnhanceException('note 字段类型非法：${rawNote.runtimeType}');
    }
    final t = rawNote.trim();
    if (t.isNotEmpty) note = t;
  }

  return AiEnhanceResult(
    amount: amount,
    categoryParentKey: categoryParentKey,
    occurredAt: occurredAt,
    note: note,
  );
}
