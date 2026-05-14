import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_ext.dart';

import 'ai_input_settings_providers.dart';

/// Step 9.3：AI 增强配置页（"我的 → 快速输入 · AI 增强"）。
///
/// 五个字段：开关 / endpoint / api key（默认遮蔽，可显示）/ model /
/// prompt 模板（多行，留空时使用 [kDefaultAiInputPromptTemplate]）。
///
/// 保存策略：底部"保存"按钮收集 controller 当前值 → 构造 [AiInputSettings] →
/// `aiInputSettingsNotifierProvider.notifier.save(...)` 持久化 + invalidateSelf
/// → SnackBar 提示。无"撤销"——用户在页面内未点保存的编辑会被下次进入丢弃。
class AiInputSettingsPage extends ConsumerStatefulWidget {
  const AiInputSettingsPage({super.key});

  @override
  ConsumerState<AiInputSettingsPage> createState() =>
      _AiInputSettingsPageState();
}

class _AiInputSettingsPageState extends ConsumerState<AiInputSettingsPage> {
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _promptController;
  bool _enabled = false;
  bool _showApiKey = false;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _promptController = TextEditingController();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  /// 首次拿到 settings 时一次性写入 controller；后续 settings 变更（保存后
  /// 自身 invalidate）由本组件不再覆盖——controller 已是用户编辑后的最新值。
  void _hydrate(AiInputSettings settings) {
    if (_hydrated) return;
    _hydrated = true;
    _enabled = settings.enabled;
    _endpointController.text = settings.endpoint ?? '';
    _apiKeyController.text = settings.apiKey ?? '';
    _modelController.text = settings.model ?? '';
    _promptController.text = settings.promptTemplate ?? '';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(aiInputSettingsNotifierProvider.notifier);
    try {
      await notifier.save(
        AiInputSettings(
          enabled: _enabled,
          endpoint: _endpointController.text,
          apiKey: _apiKeyController.text,
          model: _modelController.text,
          promptTemplate: _promptController.text,
        ),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.aiInputSaved)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.saveFailedWithError(e.toString()))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(aiInputSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aiInputTitle)),
      body: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(context.l10n.readFailedWithError(e.toString()), textAlign: TextAlign.center)),
        data: (settings) {
          _hydrate(settings);
          return _buildBody(context);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                SwitchListTile(
                  key: const Key('ai_input_enabled_switch'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: Text(context.l10n.aiInputEnable),
                  subtitle: Text(
                    context.l10n.aiInputEnableHint,
                  ),
                  secondary: const Icon(Icons.auto_awesome),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    context.l10n.aiInputApiConfig,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    context.l10n.aiInputApiHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const Key('ai_input_endpoint_field'),
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      labelText: 'Endpoint URL',
                      hintText:
                          'https://api.openai.com/v1/chat/completions',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const Key('ai_input_api_key_field'),
                    controller: _apiKeyController,
                    obscureText: !_showApiKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        key: const Key('ai_input_show_api_key'),
                        icon: Icon(_showApiKey
                            ? Icons.visibility_off
                            : Icons.visibility),
                        tooltip: _showApiKey ? context.l10n.aiInputHidden : context.l10n.aiInputShown,
                        onPressed: () =>
                            setState(() => _showApiKey = !_showApiKey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const Key('ai_input_model_field'),
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      hintText: 'gpt-4o-mini',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    context.l10n.aiInputPromptTemplate,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    context.l10n.aiInputPromptPlaceholderHint('{NOW}', '{TEXT}', '{CATEGORIES}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const Key('ai_input_prompt_field'),
                    controller: _promptController,
                    minLines: 6,
                    maxLines: 12,
                    decoration: InputDecoration(
                      labelText: context.l10n.aiInputPromptTemplateLabel,
                      hintText: kDefaultAiInputPromptTemplate,
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('ai_input_save_button'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.save),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
