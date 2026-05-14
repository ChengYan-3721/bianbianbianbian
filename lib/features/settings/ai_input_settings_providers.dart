import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/local/app_database.dart';
import '../../data/local/providers.dart';
import '../record/ai_input_enhance_service.dart';

part 'ai_input_settings_providers.g.dart';

/// Step 9.3：AI 增强配置（不可变 ViewModel）。
///
/// 五个字段映射到 `user_pref` 同名列：
/// - [enabled] ↔ `ai_input_enabled`（master switch）
/// - [endpoint] ↔ `ai_api_endpoint`（OpenAI 兼容协议的 chat/completions URL）
/// - [apiKey] ↔ `ai_api_key_encrypted`（当前 V1 落 UTF-8 bytes，Phase 11 走 BianbianCrypto）
/// - [model] ↔ `ai_api_model`（如 `gpt-4o-mini`）
/// - [promptTemplate] ↔ `ai_api_prompt_template`（含 `{NOW}` / `{TEXT}` /
///   `{CATEGORIES}` 占位符；为空时使用 [kDefaultAiInputPromptTemplate] 兜底）
///
/// [hasMinimalConfig] 是 [QuickConfirmCard] 决定是否展示 "✨ AI 增强" 按钮的
/// 唯一开关——必须 enabled + endpoint/key/model 三件齐全才返回 true。
/// implementation-plan §9.3 第 1 条验收"没有配置 API 时按钮不显示"由此守护。
@immutable
class AiInputSettings {
  const AiInputSettings({
    this.enabled = false,
    this.endpoint,
    this.apiKey,
    this.model,
    this.promptTemplate,
  });

  final bool enabled;
  final String? endpoint;
  final String? apiKey;
  final String? model;
  final String? promptTemplate;

  bool get hasMinimalConfig =>
      enabled &&
      (endpoint?.trim().isNotEmpty ?? false) &&
      (apiKey?.trim().isNotEmpty ?? false) &&
      (model?.trim().isNotEmpty ?? false);

  /// 当前生效的 prompt 模板：用户填写则用其值，否则走 [kDefaultAiInputPromptTemplate]。
  String get effectivePromptTemplate {
    final tpl = promptTemplate?.trim() ?? '';
    return tpl.isEmpty ? kDefaultAiInputPromptTemplate : tpl;
  }

  AiInputSettings copyWith({
    bool? enabled,
    String? endpoint,
    String? apiKey,
    String? model,
    String? promptTemplate,
  }) {
    return AiInputSettings(
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      promptTemplate: promptTemplate ?? this.promptTemplate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiInputSettings &&
          other.enabled == enabled &&
          other.endpoint == endpoint &&
          other.apiKey == apiKey &&
          other.model == model &&
          other.promptTemplate == promptTemplate);

  @override
  int get hashCode =>
      Object.hash(enabled, endpoint, apiKey, model, promptTemplate);
}

/// Step 9.3：AI 增强配置 AsyncNotifier provider。
///
/// 数据源是 `user_pref` 5 列。读路径在 [build] 一次性 load；写路径走 [save]
/// 持久化后 `invalidateSelf()`，UI 通过 `ref.watch(aiInputSettingsProvider)`
/// 自动响应。
///
/// 写入策略：
/// - [save] 接收一份完整的 [AiInputSettings] 快照，五列**全量覆盖**——这是
///   配置页的"保存"按钮语义，避免局部更新让 controller 与 DB 不一致。
/// - 字符串字段空值（empty / whitespace-only）一律落 NULL，便于
///   [hasMinimalConfig] 用 `isNotEmpty` 判断。
/// - API key 当前 V1 落 UTF-8 bytes 到 BLOB 列；Phase 11 会改为 BianbianCrypto
///   加密（届时同一列名 `ai_api_key_encrypted` 才真的"encrypted"）。
@Riverpod(keepAlive: true)
class AiInputSettingsNotifier extends _$AiInputSettingsNotifier {
  @override
  Future<AiInputSettings> build() async {
    final db = ref.watch(appDatabaseProvider);
    final pref = await (db.select(db.userPrefTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (pref == null) return const AiInputSettings();
    return AiInputSettings(
      enabled: pref.aiInputEnabled == 1,
      endpoint: pref.aiApiEndpoint,
      apiKey: _decodeApiKey(pref.aiApiKeyEncrypted),
      model: pref.aiApiModel,
      promptTemplate: pref.aiApiPromptTemplate,
    );
  }

  Future<void> save(AiInputSettings settings) async {
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.userPrefTable)..where((t) => t.id.equals(1))).write(
      UserPrefTableCompanion(
        aiInputEnabled: Value(settings.enabled ? 1 : 0),
        aiApiEndpoint: Value(_normalize(settings.endpoint)),
        aiApiKeyEncrypted: Value(_encodeApiKey(settings.apiKey)),
        aiApiModel: Value(_normalize(settings.model)),
        aiApiPromptTemplate: Value(_normalize(settings.promptTemplate)),
      ),
    );
    ref.invalidateSelf();
  }
}

String? _normalize(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  return t.isEmpty ? null : t;
}

Uint8List? _encodeApiKey(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return null;
  return Uint8List.fromList(utf8.encode(t));
}

String? _decodeApiKey(Uint8List? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return utf8.decode(raw);
  } catch (_) {
    return null;
  }
}

/// Step 9.3：默认 prompt 模板。
///
/// 当用户在配置页未填写 prompt 模板（或留空）时使用本兜底值。
///
/// 占位符（[AiInputEnhanceService] 替换）：
/// - `{NOW}` → 当前时间（`yyyy-MM-dd HH:mm`，本地时区，无秒）
/// - `{TEXT}` → 用户在快速输入条输入的原文
/// - `{CATEGORIES}` → 一级分类 key 列表（与 `seeder.dart::categoriesByParent.keys`
///   同集，避免 LLM 返回非法 parent_key）
///
/// 设计要点：
/// - 强调"只输出 JSON"——降低用户配置的 model 在响应中夹带额外文本的概率。
/// - 强调字段允许 null——服务层对 amount=null 的兜底是"沿用本地解析金额"，
///   避免 LLM 在不确定时随便编造数字。
/// - 字段名使用 snake_case（`category_parent_key` / `occurred_at`），与
///   design-document §7.1 DDL 列名一致，便于用户/开发者直观理解。
// i18n-exempt: LLM prompt template, not user-facing UI text
const String kDefaultAiInputPromptTemplate = '''你是一个中文记账文本解析助手。请分析以下文本，提取记账信息后以严格 JSON 格式回复。

允许字段：
- amount (number, 必填)：金额数值
- category_parent_key (string, 可选)：一级分类 key
- occurred_at (string, 可选)：发生日期，YYYY-MM-DD 格式
- note (string, 可选)：备注文本，剥离已识别的金额/分类/时间后

无法识别的字段请返回 null。category_parent_key 取值范围（仅限以下值）：
{CATEGORIES}

当前时间：{NOW}

只输出 JSON，不要任何其他文字。

用户输入：{TEXT}''';

/// Step 9.3：AI 增强服务 provider。`keepAlive` 保证同一 settings 期内
/// 服务实例稳定（不每帧新建 http.Client）。settings 变更（用户在配置页保
/// 存）会自动重建本 provider，[QuickConfirmCard] 看到的是新配置。
///
/// 测试可通过 `aiInputEnhanceServiceProvider.overrideWithValue(fakeService)`
/// 注入伪造服务（避免真实 HTTP 请求）。
@Riverpod(keepAlive: true)
AiInputEnhanceService aiInputEnhanceService(Ref ref) {
  final settings = ref.watch(aiInputSettingsNotifierProvider).valueOrNull ??
      const AiInputSettings();
  return AiInputEnhanceService(settings: settings);
}
