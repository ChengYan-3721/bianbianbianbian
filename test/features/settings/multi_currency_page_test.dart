import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/features/settings/fx_rate_refresh_service.dart';
import 'package:bianbianbianbian/features/settings/multi_currency_page.dart';
import 'package:bianbianbianbian/features/settings/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 8.1 + Step 8.3：多币种设置页 widget 行为。
class _TestMultiCurrencyEnabled extends MultiCurrencyEnabled {
  _TestMultiCurrencyEnabled({bool initial = false}) : _initial = initial;
  final bool _initial;

  @override
  Future<bool> build() async => _initial;

  @override
  Future<void> set(bool enabled) async {
    state = AsyncValue.data(enabled);
  }
}

/// 在内存里维护 fx_rate 行 + 提供 setManualRate/resetToAuto/refreshIfDue 行为。
class _FakeRefreshService implements FxRateRefreshService {
  _FakeRefreshService(this.rows, this.refreshResult);

  final Map<String, FxRateEntry> rows;
  bool refreshResult;
  int refreshCalls = 0;
  int refreshForceCalls = 0;

  @override
  Future<bool> refreshIfDue({bool force = false}) async {
    refreshCalls++;
    if (force) refreshForceCalls++;
    return refreshResult;
  }

  @override
  Future<void> setManualRate(String code, double rateToCny) async {
    final old = rows[code];
    rows[code] = FxRateEntry(
      code: code,
      rateToCny: rateToCny,
      updatedAt: old?.updatedAt ?? 0,
      isManual: 1,
    );
  }

  @override
  Future<void> resetToAuto(String code) async {
    final old = rows[code];
    if (old == null) return;
    rows[code] = FxRateEntry(
      code: old.code,
      rateToCny: old.rateToCny,
      updatedAt: old.updatedAt,
      isManual: 0,
    );
  }
}

FxRateEntry _entry(String code, double rate, {int isManual = 0}) =>
    FxRateEntry(
      code: code,
      rateToCny: rate,
      updatedAt: 1714000000000,
      isManual: isManual,
    );

void main() {
  Map<String, FxRateEntry> initialRows() => {
        'CNY': _entry('CNY', 1.0),
        'USD': _entry('USD', 7.20),
        'EUR': _entry('EUR', 7.85, isManual: 1),
      };

  Widget wrapApp({
    required _TestMultiCurrencyEnabled fake,
    required _FakeRefreshService service,
  }) {
    return ProviderScope(
      overrides: [
        multiCurrencyEnabledProvider.overrideWith(() => fake),
        fxRateRefreshServiceProvider.overrideWithValue(service),
        fxRateRowsProvider.overrideWith((ref) async {
          final list = service.rows.values.toList()
            ..sort((a, b) => a.code.compareTo(b.code));
          return list;
        }),
      ],
      child: const MaterialApp(home: MultiCurrencyPage()),
    );
  }

  testWidgets('开关默认关闭时 SwitchListTile.value=false', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('multi_currency_switch')),
    );
    expect(tile.value, false);
  });

  testWidgets('点击开关后 SwitchListTile.value 翻转为 true', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('multi_currency_switch')));
    await tester.pumpAndSettle();

    final tileAfter = tester.widget<SwitchListTile>(
      find.byKey(const Key('multi_currency_switch')),
    );
    expect(tileAfter.value, true);
  });

  testWidgets('内置币种行展示 11 种 code', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    expect(find.text('内置币种'), findsOneWidget);
    expect(find.textContaining('CNY'), findsWidgets);
    expect(find.textContaining('USD'), findsWidgets);
    expect(find.textContaining('AUD'), findsWidgets);
  });

  testWidgets('Step 8.3：汇率列表展示行 + 手动/自动徽章 + CNY 标"基准"',
      (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fx_rate_row_CNY')), findsOneWidget);
    expect(find.byKey(const Key('fx_rate_row_USD')), findsOneWidget);
    expect(find.byKey(const Key('fx_rate_row_EUR')), findsOneWidget);

    // CNY 行禁用 + 显示"基准"
    final cny = tester.widget<ListTile>(
      find.byKey(const Key('fx_rate_row_CNY')),
    );
    expect(cny.enabled, false);
    expect(find.text('基准'), findsOneWidget);

    // USD 行 = 自动；EUR 行 = 手动
    expect(find.text('自动'), findsWidgets);
    expect(find.text('手动'), findsWidgets);
  });

  testWidgets('Step 8.3：点击 USD 行 → 输入新汇率 → setManualRate', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fx_rate_row_USD')));
    await tester.pumpAndSettle();

    expect(find.text('设置 USD 汇率'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('manual_rate_field')),
      '6.5',
    );
    await tester.tap(find.byKey(const Key('manual_rate_submit')));
    await tester.pumpAndSettle();

    final usd = service.rows['USD']!;
    expect(usd.rateToCny, 6.5);
    expect(usd.isManual, 1);
  });

  testWidgets('Step 8.3：点击 EUR（手动行）→ "重置为自动"', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fx_rate_row_EUR')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual_rate_reset')), findsOneWidget);
    await tester.tap(find.byKey(const Key('manual_rate_reset')));
    await tester.pumpAndSettle();

    expect(service.rows['EUR']!.isManual, 0);
    expect(service.rows['EUR']!.rateToCny, 7.85);
  });

  testWidgets('Step 8.3：点击 CNY 行无反应', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fx_rate_row_CNY')));
    await tester.pumpAndSettle();
    expect(find.text('设置 CNY 汇率'), findsNothing);
  });

  testWidgets('Step 8.3：AppBar 立即刷新按钮 → force=true', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), true);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    final initialCalls = service.refreshCalls;
    await tester.tap(find.byKey(const Key('fx_refresh_now')));
    await tester.pumpAndSettle();

    expect(service.refreshCalls, greaterThan(initialCalls));
    expect(service.refreshForceCalls, 1);
    expect(find.text('汇率已更新'), findsOneWidget);
  });

  testWidgets('Step 8.3：立即刷新失败时显示降级提示', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fx_refresh_now')));
    await tester.pumpAndSettle();

    expect(find.text('联网失败，使用现有快照'), findsOneWidget);
  });

  testWidgets('Step 8.3：进入页面自动 fire-and-forget 触发节流刷新', (tester) async {
    final fake = _TestMultiCurrencyEnabled();
    final service = _FakeRefreshService(initialRows(), false);
    await tester.pumpWidget(wrapApp(fake: fake, service: service));
    await tester.pumpAndSettle();

    expect(service.refreshCalls, greaterThanOrEqualTo(1));
    expect(service.refreshForceCalls, 0,
        reason: '入页只 refreshIfDue()，不 force');
  });
}
