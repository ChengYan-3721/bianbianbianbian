import 'package:bianbianbianbian/features/lock/app_lock_providers.dart';
import 'package:bianbianbianbian/features/lock/app_lock_settings_page.dart';
import 'package:bianbianbianbian/features/lock/biometric_authenticator.dart';
import 'package:bianbianbianbian/features/lock/pin_credential.dart';
import 'package:bianbianbianbian/features/lock/pin_setup_page.dart';
import 'package:bianbianbianbian/features/lock/pin_unlock_page.dart';
import 'package:bianbianbianbian/features/lock/privacy_mode_service.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for Step 14.1 + 14.2 UI surfaces.
///
/// 五个层面：
/// 1. [PinSetupPage]：两步输入 + 不一致回到第一步；
/// 2. [PinUnlockPage] PIN 路径：3 次错误进入冷却 + 倒计时按钮文案；
/// 3. [PinUnlockPage] 14.2 生物识别路径：自动弹一次 + cancelled 降级 + success 成
///    功 pop；
/// 4. [AppLockSettingsPage] PIN 主流程：开关默认关闭 + 开启需要 PIN setup → enabled
///    变为 true + 忘记 PIN；
/// 5. [AppLockSettingsPage] 14.2 生物识别开关：硬件不支持置灰 / 已录入可拨开 / 系
///    统取消保持关闭。

class _Clock {
  DateTime current;
  _Clock(this.current);
  DateTime call() => current;
}

List<Override> _baseOverrides({
  required PinCredentialStore store,
  required _Clock clock,
  BiometricAuthenticator? auth,
  PrivacyModeService? privacyService,
}) =>
    [
      pinCredentialStoreProvider.overrideWithValue(store),
      appLockClockProvider.overrideWithValue(clock.call),
      if (auth != null) biometricAuthenticatorProvider.overrideWithValue(auth),
      if (privacyService != null)
        privacyModeServiceProvider.overrideWithValue(privacyService),
    ];

/// Step 14.4 起 settings page 出现 3 个 SwitchListTile（启用应用锁 / 生物识别 /
/// 隐私模式），且生物识别在"硬件不支持 / 未录入"时降级为普通 ListTile —— 通过
/// title 文本反查 ListTile（SwitchListTile 内部本身嵌一个 ListTile，普通 ListTile
/// 也是 ListTile），再 descendant 拿 trailing 的 Switch。同一查找路径覆盖两种形态。
Finder _switchOf(String titleText) => find.descendant(
      of: find.ancestor(
        of: find.text(titleText),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(Switch),
    );

/// Wraps [child] in a [MaterialApp] configured with l10n delegates so that
/// `AppLocalizations.of(context)` works in widget tests.
MaterialApp _l10nApp({required Widget home}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: home,
    );

void main() {
  group('PinSetupPage', () {
    testWidgets('两步一致 → setupPin 写入凭据 + pop(true)', (tester) async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      bool? popResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    popResult = await Navigator.of(ctx).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const PinSetupPage(mode: PinSetupMode.setup),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 第一步：输入 1234 → 下一步
      await tester.enterText(
          find.byKey(const ValueKey('pin_input_enter')), '1234');
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 第二步：再次输入 1234 → 保存
      await tester.enterText(
          find.byKey(const ValueKey('pin_input_confirm')), '1234');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(popResult, isTrue);
      // store 中已有凭据 + enabled=true
      expect(await store.load(), isNotNull);
      expect(await store.readEnabled(), isTrue);
    });

    testWidgets('两步不一致 → 回退到第一步并展示错误', (tester) async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock),
          child: _l10nApp(home: const PinSetupPage(mode: PinSetupMode.setup)),
        ),
      );

      await tester.enterText(
          find.byKey(const ValueKey('pin_input_enter')), '1234');
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('pin_input_confirm')), '5678');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.textContaining('两次输入不一致'), findsOneWidget);
      // 回到第一步——确认第一步输入框被清空。
      expect(find.byKey(const ValueKey('pin_input_enter')), findsOneWidget);
      expect(await store.load(), isNull,
          reason: '两次不一致不应触发 setupPin');
    });

    testWidgets('PIN 长度过短被拒绝在第一步', (tester) async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock),
          child: _l10nApp(home: const PinSetupPage(mode: PinSetupMode.setup)),
        ),
      );

      await tester.enterText(
          find.byKey(const ValueKey('pin_input_enter')), '12');
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('PIN 必须为 4-6 位数字'), findsOneWidget);
      // 仍然在第一步——确认表单没有跳到 confirm。
      expect(find.byKey(const ValueKey('pin_input_enter')), findsOneWidget);
      expect(find.byKey(const ValueKey('pin_input_confirm')), findsNothing);
    });
  });

  group('PinUnlockPage', () {
    Future<void> seedPin(
        InMemoryPinCredentialStore store, String pin) async {
      final salt = generatePinSalt();
      final cred = await hashPin(pin, salt, iterations: 1);
      await store.save(cred);
      await store.writeEnabled(true);
    }

    testWidgets('正确 PIN → pop(true)', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedPin(store, '1234');
      final clock = _Clock(DateTime(2026, 5, 7));

      bool? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(ctx).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const PinUnlockPage(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('3 次错误后按钮文案变为冷却中（X 秒）', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedPin(store, '1234');
      final clock = _Clock(DateTime(2026, 5, 7, 12, 0, 0));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock),
          child: _l10nApp(home: const PinUnlockPage()),
        ),
      );

      // 三次错误。
      for (var i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextField), '0000');
        await tester.tap(find.text('确认'));
        await tester.pumpAndSettle();
      }

      // FilledButton 文案应为"冷却中（30 秒）"。
      expect(find.textContaining('冷却中'), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
    });
  });

  group('AppLockSettingsPage', () {
    testWidgets('默认显示关闭开关；不展示"修改 PIN"入口', (tester) async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('启用应用锁'), findsOneWidget);
      expect(find.text('修改 PIN'), findsNothing);
      // 忘记 PIN 入口始终在。
      expect(find.text('忘记 PIN'), findsOneWidget);

      final sw = tester.widget<Switch>(_switchOf('启用应用锁'));
      expect(sw.value, isFalse);
    });

    testWidgets('开启开关 → push PinSetupPage → 完成两步后开关变为 ON 且"修改 PIN"出现',
        (tester) async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // 拨开应用锁开关。
      await tester.tap(_switchOf('启用应用锁'));
      await tester.pumpAndSettle();

      // 进入 PinSetupPage。
      expect(find.text('设置应用锁 PIN'), findsOneWidget);

      // 完成两步。
      await tester.enterText(
          find.byKey(const ValueKey('pin_input_enter')), '1234');
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('pin_input_confirm')), '1234');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 回到设置页——开关 ON + "修改 PIN" 入口出现。
      final sw = tester.widget<Switch>(_switchOf('启用应用锁'));
      expect(sw.value, isTrue);
      expect(find.text('修改 PIN'), findsOneWidget);
    });

    testWidgets('忘记 PIN 二次确认 → 关闭应用锁', (tester) async {
      final store = InMemoryPinCredentialStore();
      // 预先开启应用锁。
      final salt = generatePinSalt();
      await store.save(await hashPin('1234', salt, iterations: 1));
      await store.writeEnabled(true);

      final clock = _Clock(DateTime(2026, 5, 7));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(store: store, clock: clock),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('忘记 PIN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('清空'), findsWidgets);
      expect(find.text('我已知晓，关闭应用锁'), findsOneWidget);

      await tester.tap(find.text('我已知晓，关闭应用锁'));
      await tester.pumpAndSettle();

      // 锁被关闭：开关变 false + 凭据已清。
      final sw = tester.widget<Switch>(_switchOf('启用应用锁'));
      expect(sw.value, isFalse);
      expect(await store.load(), isNull);
      expect(await store.readEnabled(), isFalse);
    });
  });

  group('AppLockSettingsPage · 生物识别开关（Step 14.2）', () {
    Future<void> seedEnabledLock(InMemoryPinCredentialStore store) async {
      final salt = generatePinSalt();
      await store.save(await hashPin('1234', salt, iterations: 1));
      await store.writeEnabled(true);
    }

    testWidgets('设备不支持 → 开关置灰且 subtitle 显示原因', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedEnabledLock(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('生物识别'), findsOneWidget);
      expect(find.text('本设备不支持生物识别'), findsOneWidget);

      // 生物识别 tile 应 disabled —— Switch 的 onChanged 为 null。
      final biometricSwitch = tester.widget<Switch>(_switchOf('生物识别'));
      expect(biometricSwitch.onChanged, isNull);
    });

    testWidgets('设备支持但未录入 → 开关置灰且 subtitle 显示原因', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedEnabledLock(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: true,
        enrolled: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('请先在系统设置录入指纹 / 面容'), findsOneWidget);
    });

    testWidgets('可用 + 拨开开关 → authenticate success → 持久化 enabled=true',
        (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedEnabledLock(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: true,
        enrolled: true,
        nextResult: BiometricResult.success,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // 拨开生物识别开关。
      await tester.tap(_switchOf('生物识别'));
      await tester.pumpAndSettle();

      expect(auth.authenticateCalls, 1);
      expect(await store.readBiometricEnabled(), isTrue);
    });

    testWidgets('可用 + 拨开开关 → 用户取消 → 不持久化 + 显示 SnackBar',
        (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedEnabledLock(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: true,
        enrolled: true,
        nextResult: BiometricResult.cancelled,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_switchOf('生物识别'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(auth.authenticateCalls, 1);
      expect(await store.readBiometricEnabled(), isFalse,
          reason: '取消不应持久化为 true');
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('已开启状态拨关开关 → 直接持久化为 false（不再次弹生物识别）',
        (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedEnabledLock(store);
      await store.writeBiometricEnabled(true);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: true,
        enrolled: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // 拨关生物识别开关。
      await tester.tap(_switchOf('生物识别'));
      await tester.pumpAndSettle();

      expect(auth.authenticateCalls, 0,
          reason: '关闭路径不需要再次弹系统面板');
      expect(await store.readBiometricEnabled(), isFalse);
    });
  });

  group('PinUnlockPage · 生物识别（Step 14.2）', () {
    Future<void> seedPinAndBiometric(
        InMemoryPinCredentialStore store) async {
      final salt = generatePinSalt();
      await store.save(await hashPin('1234', salt, iterations: 1));
      await store.writeEnabled(true);
      await store.writeBiometricEnabled(true);
    }

    testWidgets('启用 + 设备可用 → 自动弹 authenticate（success → pop true）',
        (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedPinAndBiometric(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        nextResult: BiometricResult.success,
      );

      bool? popResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    popResult = await Navigator.of(ctx).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const PinUnlockPage(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(auth.authenticateCalls, 1,
          reason: 'init 阶段应自动触发一次生物识别');
      expect(popResult, isTrue);
    });

    testWidgets('启用 + 设备可用 + cancelled → 留在 PIN 输入 + 不报错', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedPinAndBiometric(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        nextResult: BiometricResult.cancelled,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const PinUnlockPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(auth.authenticateCalls, 1);
      // 仍在 PinUnlockPage——验证按钮可见。
      expect(find.text('确认'), findsOneWidget);
      // cancelled 不应展示"未通过"红字。
      expect(find.textContaining('未通过'), findsNothing);
    });

    testWidgets('启用 + 设备可用 + lockedOut → 展示锁定文案', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedPinAndBiometric(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        nextResult: BiometricResult.lockedOut,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const PinUnlockPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('生物识别已被系统临时锁定'), findsOneWidget);
    });

    testWidgets('biometricEnabled=false → 不自动弹 + 不显示按钮', (tester) async {
      final store = InMemoryPinCredentialStore();
      // 仅 PIN 启用，不开生物识别。
      final salt = generatePinSalt();
      await store.save(await hashPin('1234', salt, iterations: 1));
      await store.writeEnabled(true);
      // biometricEnabled 默认 false。

      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator();

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const PinUnlockPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(auth.authenticateCalls, 0);
      expect(find.textContaining('使用指纹'), findsNothing);
    });

    testWidgets('allowBiometric=false → 即便开启也不弹 + 不显示按钮', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedPinAndBiometric(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator();

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const PinUnlockPage(allowBiometric: false)),
        ),
      );
      await tester.pumpAndSettle();

      expect(auth.authenticateCalls, 0,
          reason: '"持有人确认"路径必须显式禁用生物识别');
      expect(find.textContaining('使用指纹'), findsNothing);
    });

    testWidgets('启用 + 设备不支持 → 不自动弹 + 不显示按钮', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedPinAndBiometric(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const PinUnlockPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(auth.authenticateCalls, 0,
          reason: '设备不支持时不应弹系统面板');
      expect(find.textContaining('使用指纹'), findsNothing);
    });
  });

  group('AppLockSettingsPage · 后台超时锁定（Step 14.3）', () {
    Future<void> seedEnabledLock(InMemoryPinCredentialStore store) async {
      final salt = generatePinSalt();
      await store.save(await hashPin('1234', salt, iterations: 1));
      await store.writeEnabled(true);
    }

    testWidgets('已开启状态下显示后台超时 ListTile，默认副标题为"1 分钟"',
        (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedEnabledLock(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('后台超时锁定'), findsOneWidget);
      expect(find.textContaining('1 分钟'), findsWidgets,
          reason: '默认 60 秒应展示为"1 分钟"');
    });

    testWidgets('未开启应用锁时不显示后台超时 ListTile', (tester) async {
      final store = InMemoryPinCredentialStore();
      // 不 seed → enabled=false。
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('后台超时锁定'), findsNothing,
          reason: '"后台超时"配置只在 PIN 已启用时挂载');
    });

    testWidgets('点击 ListTile 弹 BottomSheet → 选"立即锁定" → 持久化为 0',
        (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedEnabledLock(store);
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('后台超时锁定'));
      await tester.pumpAndSettle();

      // BottomSheet 出现 4 个选项。
      expect(find.text('立即锁定'), findsOneWidget);
      expect(find.text('1 分钟'), findsOneWidget);
      expect(find.text('5 分钟'), findsOneWidget);
      expect(find.text('15 分钟'), findsOneWidget);

      await tester.tap(find.text('立即锁定'));
      await tester.pumpAndSettle();

      expect(await store.readBackgroundLockTimeoutSeconds(), 0);
      // ListTile 副标题应反映新值。
      expect(find.textContaining('立即锁定'), findsWidgets);
    });

    testWidgets('选择当前已选项不触发 store 写入（identity skip）', (tester) async {
      final store = InMemoryPinCredentialStore();
      await seedEnabledLock(store);
      // 初始就是 60。
      final clock = _Clock(DateTime(2026, 5, 7));
      final auth = FakeBiometricAuthenticator(
        deviceSupported: false,
        enrolled: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides:
              _baseOverrides(store: store, clock: clock, auth: auth),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('后台超时锁定'));
      await tester.pumpAndSettle();

      // 选回当前值（1 分钟）。
      await tester.tap(find.text('1 分钟'));
      await tester.pumpAndSettle();

      // store 仍是默认 60——不变。
      expect(await store.readBackgroundLockTimeoutSeconds(),
          kDefaultBackgroundLockTimeoutSeconds);
    });
  });

  group('AppLockSettingsPage 隐私模式开关 (14.4)', () {
    testWidgets('未启用应用锁时 隐私模式开关仍可见且默认关闭', (tester) async {
      // 隐私模式独立于 PIN 锁——enabled=false 时也应展示。
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      final fakeService = FakePrivacyModeService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            store: store,
            clock: clock,
            privacyService: fakeService,
          ),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('隐私模式'), findsOneWidget,
          reason: '隐私模式与应用锁解耦——关锁状态下也要可见');
      expect(find.textContaining('关闭中'), findsWidgets);
    });

    testWidgets('打开开关 → setPrivacyMode(true) 写 store + 调用 native service',
        (tester) async {
      final store = InMemoryPinCredentialStore();
      final clock = _Clock(DateTime(2026, 5, 7));
      final fakeService = FakePrivacyModeService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            store: store,
            clock: clock,
            privacyService: fakeService,
          ),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // 找隐私模式开关。
      final switchFinder = _switchOf('隐私模式');
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(await store.readPrivacyMode(), isTrue);
      expect(fakeService.callCount, 1);
      expect(fakeService.lastEnabled, isTrue);
      // UI 反映新状态。
      expect(find.textContaining('已开启'), findsWidgets);
    });

    testWidgets('已开启状态下关闭开关 → setPrivacyMode(false)', (tester) async {
      final store = InMemoryPinCredentialStore();
      await store.writePrivacyMode(true);
      final clock = _Clock(DateTime(2026, 5, 7));
      final fakeService = FakePrivacyModeService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            store: store,
            clock: clock,
            privacyService: fakeService,
          ),
          child: _l10nApp(home: const AppLockSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = _switchOf('隐私模式');
      // 开关初值应是 true——验证一下。
      final swWidget = tester.widget<Switch>(switchFinder);
      expect(swWidget.value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(await store.readPrivacyMode(), isFalse);
      expect(fakeService.lastEnabled, isFalse);
    });
  });
}
