import 'package:bianbianbianbian/features/settings/ai_input_settings_page.dart';
import 'package:bianbianbianbian/features/settings/ai_input_settings_providers.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 9.3：AI 增强配置页 widget 测试。
///
/// 覆盖：
/// 1. 入页根据当前 settings 预填字段；
/// 2. 切换开关 + 修改字段 → 保存 → notifier.save 收到完整 settings；
/// 3. API key 默认遮蔽，按显示按钮可切换；
/// 4. SnackBar 提示保存成功。
class _RecordingNotifier extends AiInputSettingsNotifier {
  _RecordingNotifier(this._initial);
  final AiInputSettings _initial;
  AiInputSettings? lastSaved;

  @override
  Future<AiInputSettings> build() async => _initial;

  @override
  Future<void> save(AiInputSettings settings) async {
    lastSaved = settings;
    state = AsyncValue.data(settings);
  }
}

Widget _wrap(_RecordingNotifier notifier) {
  return ProviderScope(
    overrides: [
      aiInputSettingsNotifierProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: const AiInputSettingsPage(),
    ),
  );
}

void main() {
  testWidgets('入页根据当前 settings 预填 5 个字段', (tester) async {
    final notifier = _RecordingNotifier(const AiInputSettings(
      enabled: true,
      endpoint: 'https://api.example.com/v1/chat/completions',
      apiKey: 'sk-secret',
      model: 'gpt-4o-mini',
      promptTemplate: 'PROMPT',
    ));

    await tester.pumpWidget(_wrap(notifier));
    await tester.pumpAndSettle();

    // 开关 ON
    final sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('ai_input_enabled_switch')),
    );
    expect(sw.value, true);

    // endpoint
    final endpoint = tester.widget<TextField>(
      find.byKey(const Key('ai_input_endpoint_field')),
    );
    expect(
      endpoint.controller!.text,
      'https://api.example.com/v1/chat/completions',
    );

    // model
    final model = tester.widget<TextField>(
      find.byKey(const Key('ai_input_model_field')),
    );
    expect(model.controller!.text, 'gpt-4o-mini');

    // prompt
    final prompt = tester.widget<TextField>(
      find.byKey(const Key('ai_input_prompt_field')),
    );
    expect(prompt.controller!.text, 'PROMPT');

    // api key controller 内容已填，但 obscureText=true → 视觉遮蔽
    final apiKey = tester.widget<TextField>(
      find.byKey(const Key('ai_input_api_key_field')),
    );
    expect(apiKey.controller!.text, 'sk-secret');
    expect(apiKey.obscureText, true);
  });

  testWidgets('切换开关 + 修改字段 + 点保存 → notifier.save 收到完整 settings', (tester) async {
    final notifier = _RecordingNotifier(const AiInputSettings());

    await tester.pumpWidget(_wrap(notifier));
    await tester.pumpAndSettle();

    // 默认开关 OFF
    expect(
      tester
          .widget<SwitchListTile>(
              find.byKey(const Key('ai_input_enabled_switch')))
          .value,
      false,
    );

    // 切开关
    await tester.tap(find.byKey(const Key('ai_input_enabled_switch')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai_input_endpoint_field')),
      'https://api.openai.com/v1/chat/completions',
    );
    await tester.enterText(
      find.byKey(const Key('ai_input_api_key_field')),
      'sk-xyz',
    );
    await tester.enterText(
      find.byKey(const Key('ai_input_model_field')),
      'gpt-4o-mini',
    );
    await tester.enterText(
      find.byKey(const Key('ai_input_prompt_field')),
      '{TEXT} 请解析',
    );

    await tester.tap(find.byKey(const Key('ai_input_save_button')));
    await tester.pumpAndSettle();

    expect(notifier.lastSaved, isNotNull);
    final saved = notifier.lastSaved!;
    expect(saved.enabled, true);
    expect(saved.endpoint, 'https://api.openai.com/v1/chat/completions');
    expect(saved.apiKey, 'sk-xyz');
    expect(saved.model, 'gpt-4o-mini');
    expect(saved.promptTemplate, '{TEXT} 请解析');
    expect(saved.hasMinimalConfig, true);

    // SnackBar
    expect(find.text('AI 增强配置已保存'), findsOneWidget);
  });

  testWidgets('点击显示按钮 → API key obscureText 切换为 false', (tester) async {
    final notifier = _RecordingNotifier(
      const AiInputSettings(apiKey: 'sk-visible-test'),
    );
    await tester.pumpWidget(_wrap(notifier));
    await tester.pumpAndSettle();

    // 初始遮蔽
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai_input_api_key_field')))
          .obscureText,
      true,
    );

    await tester.tap(find.byKey(const Key('ai_input_show_api_key')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai_input_api_key_field')))
          .obscureText,
      false,
    );

    // 再点切回
    await tester.tap(find.byKey(const Key('ai_input_show_api_key')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai_input_api_key_field')))
          .obscureText,
      true,
    );
  });
}
