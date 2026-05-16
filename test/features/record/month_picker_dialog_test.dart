import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/features/record/month_picker_dialog.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';

/// Step 3.7 验证：自定义年-月选择器。
///
/// 仅做基本路径覆盖：
/// - 弹出后默认高亮当前选中的月份；
/// - 上 / 下一年箭头可切换显示年；
/// - 选择新月份后点击"确定"返回 `DateTime(year, month)`；
/// - "取消"返回 null（不修改首页 month state）。
void main() {
  group('showMonthPicker', () {
    testWidgets('默认高亮初始月份且确认返回该月份', (tester) async {
      DateTime? returned;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      // 触发弹窗（不 await，单独 pump 让 dialog 出来）。
      final future = showMonthPicker(
        context: capturedContext,
        initialMonth: DateTime(2025, 7),
      );
      await tester.pumpAndSettle();

      // 标题展示当前年。
      expect(find.text('2025 年'), findsOneWidget);

      // 不修改月份直接确认，应返回 (2025, 7)。
      await tester.tap(find.byKey(const Key('month_picker_confirm')));
      await tester.pumpAndSettle();
      returned = await future;

      expect(returned, DateTime(2025, 7));
    });

    testWidgets('左右箭头切换年份后选月，返回选择的年-月', (tester) async {
      DateTime? returned;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final future = showMonthPicker(
        context: capturedContext,
        initialMonth: DateTime(2026, 5),
      );
      await tester.pumpAndSettle();

      // 上一年 → 2025
      await tester.tap(find.byKey(const Key('month_picker_prev_year')));
      await tester.pumpAndSettle();
      expect(find.text('2025 年'), findsOneWidget);

      // 选 2025/1 月
      await tester.tap(find.byKey(const Key('month_picker_cell_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('month_picker_confirm')));
      await tester.pumpAndSettle();
      returned = await future;

      expect(returned, DateTime(2025, 1));
    });

    testWidgets('取消按钮返回 null', (tester) async {
      DateTime? returned;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final future = showMonthPicker(
        context: capturedContext,
        initialMonth: DateTime(2026, 5),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      returned = await future;

      expect(returned, isNull);
    });
  });
}
