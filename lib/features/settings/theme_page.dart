import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/util/category_icon_packs.dart';
import 'settings_providers.dart';

/// Step 15.1 + 15.2 + 15.3：外观设置页——主题切换 + 字号选择 + 图标包。
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentKeyAsync = ref.watch(currentThemeKeyProvider);
    final currentKey = currentKeyAsync.valueOrNull ?? 'cream_bunny';
    final fontSizeKeyAsync = ref.watch(currentFontSizeKeyProvider);
    final fontSizeKey = fontSizeKeyAsync.valueOrNull ?? 'standard';
    final iconPackKeyAsync = ref.watch(currentIconPackKeyProvider);
    final iconPackKey = iconPackKeyAsync.valueOrNull ?? 'sticker';

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        children: [
          // ─── 主题区 ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '主题',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final theme in BianBianTheme.values)
            _ThemeCard(
              theme: theme,
              isSelected: theme.key == currentKey,
              onTap: () {
                ref.read(currentThemeKeyProvider.notifier).set(theme.key);
              },
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '切换后所有页面即时生效，包括图表与图标底色',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(0x60),
                  ),
            ),
          ),

          // ─── 字号区 ────────────────────────────────────────────
          const Divider(height: 32, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '字号',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<BianBianFontSize>(
              segments: [
                for (final fs in BianBianFontSize.values)
                  ButtonSegment(
                    value: fs,
                    label: Text(fs.label),
                  ),
              ],
              selected: {BianBianFontSize.fromKey(fontSizeKey)},
              onSelectionChanged: (selected) {
                ref
                    .read(currentFontSizeKeyProvider.notifier)
                    .set(selected.first.key);
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '大字号会在系统字号基础上再放大 15%，小字号缩小 15%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(0x60),
                  ),
            ),
          ),

          // ─── 图标包区 ──────────────────────────────────────────
          const Divider(height: 32, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '分类图标',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final pack in BianBianIconPack.values)
            _IconPackCard(
              pack: pack,
              isSelected: pack.key == iconPackKey,
              onTap: () {
                ref.read(currentIconPackKeyProvider.notifier).set(pack.key);
              },
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '切换后分类网格与流水列表图标即时更新；自定义图标不受影响',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(0x60),
                  ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final BianBianTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewTheme = buildAppTheme(theme);
    final cs = previewTheme.colorScheme;
    final semantics =
        previewTheme.extension<BianBianSemanticColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: cs.primary, width: 2.5)
                : Border.all(color: cs.onSurface.withAlpha(0x12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Text(
                    theme.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle, color: cs.primary, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              // 色板预览行
              Row(
                children: [
                  _ColorDot(cs.primary, label: '主色'),
                  const SizedBox(width: 8),
                  _ColorDot(cs.primaryContainer, label: '容器'),
                  const SizedBox(width: 8),
                  _ColorDot(cs.secondary, label: '辅助'),
                  const SizedBox(width: 8),
                  _ColorDot(semantics.success, label: '成功'),
                  const SizedBox(width: 8),
                  _ColorDot(semantics.warning, label: '警告'),
                  const SizedBox(width: 8),
                  _ColorDot(semantics.danger, label: '错误'),
                ],
              ),
              const SizedBox(height: 10),
              // 背景色块预览
              Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.onSurface.withAlpha(0x08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Aa',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_note,
                        size: 14,
                        color: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color, {required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(0x40),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPackCard extends StatelessWidget {
  const _IconPackCard({
    required this.pack,
    required this.isSelected,
    required this.onTap,
  });

  final BianBianIconPack pack;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final samples = samplePackIcons(pack);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: cs.primary, width: 2.5)
                : Border.all(color: cs.onSurface.withAlpha(0x12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 样本图标预览行
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final emoji in samples)
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: cs.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
