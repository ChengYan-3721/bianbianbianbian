import 'dart:typed_data';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/local/providers.dart';
import 'package:bianbianbianbian/features/settings/ai_input_settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 9.3：[AiInputSettingsNotifier] + [AiInputSettings] 单元测试。
///
/// 覆盖：
/// 1. 默认值（user_pref 单行已存在但 ai_* 列均为 NULL/0）→ AiInputSettings(enabled=false)。
/// 2. save → 持久化到 user_pref → 下次 build 能读回。
/// 3. hasMinimalConfig 边界（开关 / endpoint / api key / model 任一缺失即 false）。
/// 4. effectivePromptTemplate 在用户为空时回退到 [kDefaultAiInputPromptTemplate]。
/// 5. API key BLOB 编码：UTF-8 bytes 往返。
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // user_pref 单行（CHECK(id=1)）
    await db.into(db.userPrefTable).insert(
          UserPrefTableCompanion.insert(deviceId: 'device-test'),
        );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('AiInputSettings 数据类', () {
    test('默认空 → enabled=false / 全字段 null / hasMinimalConfig=false', () {
      const s = AiInputSettings();
      expect(s.enabled, false);
      expect(s.endpoint, isNull);
      expect(s.apiKey, isNull);
      expect(s.model, isNull);
      expect(s.promptTemplate, isNull);
      expect(s.hasMinimalConfig, false);
    });

    test('hasMinimalConfig 必须四件齐全（enabled + endpoint + key + model）', () {
      // 缺 enabled
      expect(
        const AiInputSettings(
          endpoint: 'x',
          apiKey: 'y',
          model: 'z',
        ).hasMinimalConfig,
        false,
      );
      // 缺 endpoint
      expect(
        const AiInputSettings(
          enabled: true,
          apiKey: 'y',
          model: 'z',
        ).hasMinimalConfig,
        false,
      );
      // 缺 apiKey
      expect(
        const AiInputSettings(
          enabled: true,
          endpoint: 'x',
          model: 'z',
        ).hasMinimalConfig,
        false,
      );
      // 缺 model
      expect(
        const AiInputSettings(
          enabled: true,
          endpoint: 'x',
          apiKey: 'y',
        ).hasMinimalConfig,
        false,
      );
      // 字段是空白也不算
      expect(
        const AiInputSettings(
          enabled: true,
          endpoint: '   ',
          apiKey: 'y',
          model: 'z',
        ).hasMinimalConfig,
        false,
      );
      // 全齐 → true
      expect(
        const AiInputSettings(
          enabled: true,
          endpoint: 'https://x',
          apiKey: 'sk',
          model: 'm',
        ).hasMinimalConfig,
        true,
      );
    });

    test('effectivePromptTemplate：用户值优先，否则走默认', () {
      expect(
        const AiInputSettings().effectivePromptTemplate,
        kDefaultAiInputPromptTemplate,
      );
      expect(
        const AiInputSettings(promptTemplate: '').effectivePromptTemplate,
        kDefaultAiInputPromptTemplate,
      );
      expect(
        const AiInputSettings(promptTemplate: '   ').effectivePromptTemplate,
        kDefaultAiInputPromptTemplate,
      );
      expect(
        const AiInputSettings(promptTemplate: 'CUSTOM').effectivePromptTemplate,
        'CUSTOM',
      );
    });

    test('==/hashCode 五字段全部参与', () {
      const a = AiInputSettings(
        enabled: true,
        endpoint: 'x',
        apiKey: 'y',
        model: 'z',
      );
      const b = AiInputSettings(
        enabled: true,
        endpoint: 'x',
        apiKey: 'y',
        model: 'z',
      );
      const c = AiInputSettings(
        enabled: true,
        endpoint: 'x',
        apiKey: 'y2',
        model: 'z',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == c, false);
    });

    test('copyWith 仅修改指定字段', () {
      const base = AiInputSettings(
        enabled: false,
        endpoint: 'x',
        apiKey: 'y',
        model: 'z',
      );
      final next = base.copyWith(enabled: true);
      expect(next.enabled, true);
      expect(next.endpoint, 'x');
      expect(next.apiKey, 'y');
      expect(next.model, 'z');
    });
  });

  group('AiInputSettingsNotifier - DB 集成', () {
    test('build：user_pref 默认值（无 AI 配置）→ 全空 settings', () async {
      final result =
          await container.read(aiInputSettingsNotifierProvider.future);
      expect(result.enabled, false);
      expect(result.endpoint, isNull);
      expect(result.apiKey, isNull);
      expect(result.model, isNull);
      expect(result.promptTemplate, isNull);
    });

    test('save → 持久化到 user_pref → invalidate → 重建读到新值', () async {
      final notifier =
          container.read(aiInputSettingsNotifierProvider.notifier);
      await notifier.save(
        const AiInputSettings(
          enabled: true,
          endpoint: 'https://api.example.com/v1/chat/completions',
          apiKey: 'sk-abc',
          model: 'gpt-4o-mini',
          promptTemplate: 'TPL: {TEXT}',
        ),
      );

      // 直接查 DB 验证持久化
      final pref = await (db.select(db.userPrefTable)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(pref.aiInputEnabled, 1);
      expect(pref.aiApiEndpoint, 'https://api.example.com/v1/chat/completions');
      expect(pref.aiApiModel, 'gpt-4o-mini');
      expect(pref.aiApiPromptTemplate, 'TPL: {TEXT}');
      // API key 以 UTF-8 bytes 存储
      expect(pref.aiApiKeyEncrypted, isNotNull);
      expect(
        Uint8List.fromList(pref.aiApiKeyEncrypted!),
        Uint8List.fromList('sk-abc'.codeUnits),
      );

      // 通过 provider 再读一次（已 invalidateSelf 重建）
      final settings =
          await container.read(aiInputSettingsNotifierProvider.future);
      expect(settings.enabled, true);
      expect(settings.endpoint, 'https://api.example.com/v1/chat/completions');
      expect(settings.apiKey, 'sk-abc');
      expect(settings.model, 'gpt-4o-mini');
      expect(settings.promptTemplate, 'TPL: {TEXT}');
      expect(settings.hasMinimalConfig, true);
    });

    test('save：空白字段一律落 NULL（保证 hasMinimalConfig 判断准确）', () async {
      final notifier =
          container.read(aiInputSettingsNotifierProvider.notifier);
      await notifier.save(
        const AiInputSettings(
          enabled: true,
          endpoint: '   ',
          apiKey: '',
          model: 'm',
          promptTemplate: null,
        ),
      );

      final pref = await (db.select(db.userPrefTable)
            ..where((t) => t.id.equals(1)))
          .getSingle();
      expect(pref.aiApiEndpoint, isNull);
      expect(pref.aiApiKeyEncrypted, isNull);
      expect(pref.aiApiModel, 'm');

      final s = await container.read(aiInputSettingsNotifierProvider.future);
      expect(s.endpoint, isNull);
      expect(s.apiKey, isNull);
      expect(s.hasMinimalConfig, false);
    });

    test('save：API key 含中文 / emoji 也能 UTF-8 往返', () async {
      final notifier =
          container.read(aiInputSettingsNotifierProvider.notifier);
      const tricky = 'sk-中文🔑密钥-test';
      await notifier.save(
        const AiInputSettings(
          enabled: true,
          endpoint: 'x',
          apiKey: tricky,
          model: 'm',
        ),
      );
      final s = await container.read(aiInputSettingsNotifierProvider.future);
      expect(s.apiKey, tricky);
    });

    test('user_pref 不存在的极端情况 → 走兜底空 settings 不崩溃', () async {
      // 删除 user_pref 单行（虽然生产路径不会出现，但 build() 必须容错）
      await db.delete(db.userPrefTable).go();
      // 重新创建 container 以避免缓存
      container.dispose();
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      final s = await container.read(aiInputSettingsNotifierProvider.future);
      expect(s.enabled, false);
      expect(s.endpoint, isNull);
    });
  });
}
