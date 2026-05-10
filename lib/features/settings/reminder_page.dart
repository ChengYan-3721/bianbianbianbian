import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('提醒')),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取提醒状态失败：$e')),
        data: (enabled) => timeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('读取提醒时间失败：$e')),
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
          title: const Text('每日记账提醒'),
          subtitle: Text(
            enabled
                ? '每天 ${_formatTime(time ?? const TimeOfDay(hour: 20, minute: 0))} 提醒你记一笔'
                : '未开启',
          ),
          value: enabled,
          onChanged: (next) => _onToggle(context, ref, next),
        ),
        if (enabled) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('提醒时间'),
            trailing: Text(
              _formatTime(time ?? const TimeOfDay(hour: 20, minute: 0)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _pickTime(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('测试提醒'),
            subtitle: const Text('立即发送一条测试通知'),
            onTap: () => _showTest(context, ref),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '开启后，每天在设定时间会收到一条可爱的记账提醒 🐻\n'
              '如果通知没有按时出现，请检查系统通知权限设置。',
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
          const SnackBar(content: Text('通知权限被拒绝，无法开启提醒')),
        );
        return;
      }
      // 选时间——默认 20:00。
      if (!context.mounted) return;
      final picked = await showTimePicker(
        context: context,
        initialTime: time ?? const TimeOfDay(hour: 20, minute: 0),
        helpText: '选择提醒时间',
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
        SnackBar(content: Text('已开启，每天 ${_formatTime(picked)} 提醒你')),
      );
    } else {
      // 关闭：取消通知 + 清 DB。
      final service = ref.read(reminderServiceProvider);
      await service.cancelReminder();
      await ref.read(reminderEnabledProvider.notifier).set(false);
      await ref.read(reminderTimeProvider.notifier).clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已关闭每日提醒')),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time ?? const TimeOfDay(hour: 20, minute: 0),
      helpText: '选择提醒时间',
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
      SnackBar(content: Text('提醒时间已更新为 ${_formatTime(picked)}')),
    );
  }

  Future<void> _showTest(BuildContext context, WidgetRef ref) async {
    final service = ref.read(reminderServiceProvider);
    await service.showTestNotification();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('测试通知已发送 🐻')),
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
