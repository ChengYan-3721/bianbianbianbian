import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/features/settings/reminder_page.dart';
import 'package:bianbianbianbian/features/settings/reminder_service.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';

/// Step 16.1：ReminderPage widget 测试。
void main() {
  List<Override> baseOverrides({
    _FakeReminderEnabled? enabled,
    _FakeReminderTime? time,
  }) =>
      [
        reminderEnabledProvider.overrideWith(
            () => enabled ?? _FakeReminderEnabled(false)),
        reminderTimeProvider
            .overrideWith(() => time ?? _FakeReminderTime(null)),
        reminderServiceProvider.overrideWithValue(_FakeReminderService()),
      ];

  testWidgets('shows switch and "未开启" when disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ReminderPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('每日记账提醒'), findsOneWidget);
    expect(find.text('未开启'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('shows time and test button when enabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          enabled: _FakeReminderEnabled(true),
          time: _FakeReminderTime(const TimeOfDay(hour: 20, minute: 0)),
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ReminderPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 提醒时间 ListTile
    expect(find.text('提醒时间'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    // 测试提醒
    expect(find.text('测试提醒'), findsOneWidget);
  });

  testWidgets('toggling switch on calls set on provider', (tester) async {
    final fakeEnabled = _FakeReminderEnabled(false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(enabled: fakeEnabled),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ReminderPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 点击 switch（开启）
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // _FakeReminderService.requestPermission 返回 false，
    // 所以开启流程被阻止——不会调 set(true)
    expect(fakeEnabled.lastSetValue, isNull);
  });

  testWidgets('toggling switch off calls set(false) and cancelReminder',
      (tester) async {
    final fakeEnabled = _FakeReminderEnabled(true);
    final fakeService = _FakeReminderService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderEnabledProvider.overrideWith(() => fakeEnabled),
          reminderTimeProvider
              .overrideWith(() => _FakeReminderTime(const TimeOfDay(hour: 20, minute: 0))),
          reminderServiceProvider.overrideWithValue(fakeService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ReminderPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 关闭 switch
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(fakeEnabled.lastSetValue, isFalse);
    expect(fakeService.cancelled, isTrue);
  });

  testWidgets('description text is visible when enabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          enabled: _FakeReminderEnabled(true),
          time: _FakeReminderTime(const TimeOfDay(hour: 20, minute: 0)),
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const ReminderPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 滚动到底部找描述文案
    final desc = find.textContaining('开启后，每天在设定时间');
    await tester.scrollUntilVisible(desc, 200.0,
        scrollable: find.byType(Scrollable));
    expect(desc, findsOneWidget);
  });
}

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _FakeReminderEnabled extends ReminderEnabled {
  bool _current;
  _FakeReminderEnabled(this._current);

  bool? lastSetValue;

  @override
  Future<bool> build() async => _current;

  @override
  Future<void> set(bool enabled) async {
    lastSetValue = enabled;
    _current = enabled;
    ref.invalidateSelf();
  }
}

class _FakeReminderTime extends ReminderTime {
  TimeOfDay? _current;
  _FakeReminderTime(this._current);

  @override
  Future<TimeOfDay?> build() async => _current;

  @override
  Future<void> set(TimeOfDay time) async {
    _current = time;
    ref.invalidateSelf();
  }

  @override
  Future<void> clear() async {
    _current = null;
    ref.invalidateSelf();
  }
}

class _FakeReminderService extends ReminderService {
  bool initialized = false;
  bool permissionGranted = false;
  bool cancelled = false;
  int? scheduledHour;
  int? scheduledMinute;
  bool testNotificationShown = false;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    return permissionGranted;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    scheduledHour = hour;
    scheduledMinute = minute;
  }

  @override
  Future<void> cancelReminder() async {
    cancelled = true;
  }

  @override
  Future<void> showTestNotification() async {
    testNotificationShown = true;
  }
}
