import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Step 16.1：每日记账提醒通知服务。
///
/// 封装 [FlutterLocalNotificationsPlugin] 的初始化、调度、取消逻辑。
/// UI 通过 provider 拿到本 service 实例，调用 [scheduleDailyReminder] /
/// [cancelReminder] / [showTestNotification]。
///
/// **平台差异**：
/// - Android：需要 `RECEIVE_BOOT_COMPLETED` 权限 + `ScheduledNotificationReceiver`
///   以保证重启后通知仍能触发；Android 13+ 需要 requestNotificationsPermission()。
/// - iOS：本地通知无需额外权限，但首次调 `requestPermissions` 会弹系统对话框。
/// - 桌面（Windows/macOS/Linux）：`flutter_local_notifications` 不支持调度通知，
///   [initialize] 静默跳过不崩溃。
class ReminderService {
  ReminderService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// 通知 channel ID / name（Android O+ 必需）。
  static const _channelId = 'daily_reminder';
  static const _channelName = '每日记账提醒';
  static const _channelDesc = '每天定时提醒你记一笔';

  /// 调度通知的固定 ID——每天只用一个，新调度覆盖旧调度。
  static const _notificationId = 0;

  /// 可爱风提醒文案池——每天随机选一条，避免千篇一律。
  static const _messages = [
    '今天还没记一笔呢 🐻',
    '记账时间到啦 🐰',
    '快来记一笔吧，别忘啦 🧸',
    '你的账本想你了 🐷',
    '今天花了多少？记一下吧 🍯',
    '别让小钱溜走，记一笔 🐱',
    '记账小助手提醒你 🐼',
  ];

  /// 初始化通知插件。App 启动时调一次即可，重复调是空操作。
  Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return;
    }
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const macOsSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOsSettings,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
  }

  /// 请求通知权限（Android 13+ / iOS 首次）。
  ///
  /// 返回 true 表示用户授权。桌面平台直接返回 false（不支持调度通知）。
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    // iOS / macOS：请求 alert + sound。
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, sound: true);
      return granted ?? false;
    }
    final macOs = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macOs != null) {
      final granted =
          await macOs.requestPermissions(alert: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  /// 调度每日定时通知。
  ///
  /// [hour] / [minute] 为本地时间（24 小时制）。内部用 [tz.TZDateTime]
  /// 构造下一个命中时刻，配合 `matchDateTimeComponents: DateTimeComponents.time`
  /// 让系统每天重复触发。
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final message = _messages[DateTime.now().millisecond % _messages.length];

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: '边边记账',
      body: message,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('[ReminderService] scheduled daily at $hour:$minute');
  }

  /// 取消已调度的每日通知。
  Future<void> cancelReminder() async {
    if (!_initialized) await initialize();
    await _plugin.cancel(id: _notificationId);
    debugPrint('[ReminderService] cancelled');
  }

  /// 立即展示一条测试通知——供设置页"测试提醒"按钮使用。
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    const message = '这是一条测试提醒 🐻 记账时间到啦！';
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
    await _plugin.show(
      id: _notificationId + 1,
      title: '边边记账',
      body: message,
      notificationDetails: details,
    );
    debugPrint('[ReminderService] test notification shown');
  }

  /// 通知点击回调——当前仅打印日志，未来可跳转到记账页。
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('[ReminderService] notification tapped: ${response.id}');
  }
}
