import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_ext.dart';
import 'settings_providers.dart';

/// Step 16.1：「我的 → 提醒」设置页。
///
/// 两类操作：
/// 1. 启用 / 关闭每日记账提醒——[SwitchListTile]：
///    - 开启时先请求通知权限（Android 13+ / iOS），被拒绝则弹 SnackBar
///      告知并不同步开关状态；
///    - 开启后展示时间选择器（默认 20:00），选定后立即调度通知；
///    - 关闭时取消通知 + 清除 DB 中的 reminder_time。
/// 2. 修改提醒时间——点击当前时间跳转 [showTimePicker]，确认后重新调度。
class ReminderPage extends ConsumerWidget {
  const ReminderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(reminderEnabledProvider);
    final timeAsync = ref.watch(reminderTimeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reminderTitle)),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.readFailedWithError(e.toString()))),
        data: (enabled) => timeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(context.l10n.readFailedWithError(e.toString()))),
          data: (time) => _Body(enabled: enabled, time: time),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.enabled, required this.time});

  final bool enabled;
  final TimeOfDay? time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(context.l10n.reminderDailyTitle),
          subtitle: Text(
            enabled
                ? context.l10n.reminderDailyOn(_formatTime(time ?? const TimeOfDay(hour: 20, minute: 0)))
                : context.l10n.reminderOff,
          ),
          value: enabled,
          onChanged: (next) => _onToggle(context, ref, next),
        ),
        if (enabled) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: Text(context.l10n.reminderTime),
            trailing: Text(
              _formatTime(time ?? const TimeOfDay(hour: 20, minute: 0)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _pickTime(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(context.l10n.reminderTest),
            subtitle: Text(context.l10n.reminderTestHint),
            onTap: () => _showTest(context, ref),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              context.l10n.reminderEnableHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onToggle(BuildContext context, WidgetRef ref, bool next) async {
    if (next) {
      // 开启：先请求权限，再选时间，再调度。
      final service = ref.read(reminderServiceProvider);
      await service.initialize();
      final granted = await service.requestPermission();
      if (!granted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.reminderPermissionDenied)),
        );
        return;
      }
      // 选时间——默认 20:00。
      if (!context.mounted) return;
      final picked = await showTimePicker(
        context: context,
        initialTime: time ?? const TimeOfDay(hour: 20, minute: 0),
        helpText: context.l10n.reminderSelectTime,
        builder: (context, child) => _themeTimePicker(context, child),
      );
      if (picked == null) {
        // 用户取消——不开。
        return;
      }
      await ref.read(reminderTimeProvider.notifier).set(picked);
      await ref.read(reminderEnabledProvider.notifier).set(true);
      await service.scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reminderEnabledAt(_formatTime(picked)))),
      );
    } else {
      // 关闭：取消通知 + 清 DB。
      final service = ref.read(reminderServiceProvider);
      await service.cancelReminder();
      await ref.read(reminderEnabledProvider.notifier).set(false);
      await ref.read(reminderTimeProvider.notifier).clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reminderDisabled)),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time ?? const TimeOfDay(hour: 20, minute: 0),
      helpText: context.l10n.reminderSelectTime,
      builder: (context, child) => _themeTimePicker(context, child),
    );
    if (picked == null) return;
    await ref.read(reminderTimeProvider.notifier).set(picked);
    final service = ref.read(reminderServiceProvider);
    await service.scheduleDailyReminder(
      hour: picked.hour,
      minute: picked.minute,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.reminderTimeUpdated(_formatTime(picked)))),
    );
  }

  Future<void> _showTest(BuildContext context, WidgetRef ref) async {
    final service = ref.read(reminderServiceProvider);
    await service.showTestNotification();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.reminderTestSent)),
    );
  }

  /// 让 TimePicker 跟随 App 主题色。
  Widget _themeTimePicker(BuildContext context, Widget? child) {
    final cs = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(
        timePickerTheme: TimePickerThemeData(
          hourMinuteColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? cs.primary
                : cs.surfaceContainerHighest,
          ),
          dialHandColor: cs.primary,
          dialBackgroundColor: cs.surfaceContainerHighest,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
}
