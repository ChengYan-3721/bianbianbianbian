import 'package:bianbianbianbian/core/util/quick_text_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试基准时间：2026-05-04（周一），便于精确断言"昨天 / 上周五 / N 天前"等相对时间。
final _today = DateTime(2026, 5, 4);
DateTime _fixedClock() => _today;
DateTime _atDay(int year, int month, int day) => DateTime(year, month, day);

QuickTextParser _parser() => QuickTextParser(clock: _fixedClock);

void main() {
  group('parseChineseNumber - 中文数字解析', () {
    test('个位', () {
      expect(QuickTextParser.parseChineseNumber('一'), 1);
      expect(QuickTextParser.parseChineseNumber('两'), 2);
      expect(QuickTextParser.parseChineseNumber('九'), 9);
    });

    test('十位组合', () {
      expect(QuickTextParser.parseChineseNumber('十'), 10);
      expect(QuickTextParser.parseChineseNumber('十二'), 12);
      expect(QuickTextParser.parseChineseNumber('三十'), 30);
      expect(QuickTextParser.parseChineseNumber('三十五'), 35);
    });

    test('百千组合', () {
      expect(QuickTextParser.parseChineseNumber('一百'), 100);
      expect(QuickTextParser.parseChineseNumber('一百二十'), 120);
      expect(QuickTextParser.parseChineseNumber('一百二十三'), 123);
      expect(QuickTextParser.parseChineseNumber('两千'), 2000);
    });

    test('万级', () {
      expect(QuickTextParser.parseChineseNumber('一万'), 10000);
      expect(QuickTextParser.parseChineseNumber('两万五千'), 25000);
    });

    test('非法输入返回 null', () {
      expect(QuickTextParser.parseChineseNumber(''), isNull);
      expect(QuickTextParser.parseChineseNumber('abc'), isNull);
      expect(QuickTextParser.parseChineseNumber('零'), isNull);
    });
  });

  group('amount - 金额解析', () {
    test('裸数字: "30"', () {
      final r = _parser().parse('30');
      expect(r.amount, 30);
      expect(r.confidence, closeTo(0.5, 1e-9));
    });

    test('带 ¥ 前缀: "¥30"', () {
      final r = _parser().parse('¥30');
      expect(r.amount, 30);
    });

    test('带"元"后缀: "30元"', () {
      final r = _parser().parse('30元');
      expect(r.amount, 30);
      expect(r.note, isNull, reason: '"30元"整体被剥离，残留为空');
    });

    test('小数: "30.5"', () {
      final r = _parser().parse('30.5');
      expect(r.amount, 30.5);
    });

    test('中文数字 + "块": "三十块"', () {
      final r = _parser().parse('三十块');
      expect(r.amount, 30);
      expect(r.note, isNull);
      // chinese path: +0.4
      expect(r.confidence, closeTo(0.4, 1e-9));
    });

    test('"大写：两万五千元"', () {
      final r = _parser().parse('两万五千元');
      expect(r.amount, 25000);
    });

    test('单字中文数字若无尾缀不视为金额', () {
      // "买了一些菜" 中的 "一" 不应被解析为金额。
      final r = _parser().parse('买了一些菜');
      expect(r.amount, isNull);
    });
  });

  group('category - 分类识别', () {
    test('"淘宝买衣服 99" → 购物（长词优先）', () {
      final r = _parser().parse('淘宝买衣服 99');
      expect(r.amount, 99);
      expect(r.categoryParentKey, 'shopping');
    });

    test('"看电影 50" → 娱乐', () {
      final r = _parser().parse('看电影 50');
      expect(r.amount, 50);
      expect(r.categoryParentKey, 'entertainment');
    });

    test('"工资 5000" → 收入', () {
      final r = _parser().parse('工资 5000');
      expect(r.amount, 5000);
      expect(r.categoryParentKey, 'income');
    });

    test('"房租 3500" → housing', () {
      final r = _parser().parse('房租 3500');
      expect(r.amount, 3500);
      expect(r.categoryParentKey, 'housing');
    });

    test('未命中词典: "买了点东西"', () {
      final r = _parser().parse('买了点东西');
      expect(r.categoryParentKey, isNull);
      expect(r.categoryLabel, isNull);
    });
  });

  group('time - 相对时间', () {
    test('"今天" → 今日', () {
      final r = _parser().parse('今天 午饭 30');
      expect(r.occurredAt, _atDay(2026, 5, 4));
    });

    test('"昨天打车 25" → 昨日 + 25 + 交通', () {
      final r = _parser().parse('昨天打车 25');
      expect(r.amount, 25);
      expect(r.categoryParentKey, 'transport');
      expect(r.occurredAt, _atDay(2026, 5, 3));
      expect(r.confidence, closeTo(1.0, 1e-9));
    });

    test('"前天 50" → 前日', () {
      final r = _parser().parse('前天 50');
      expect(r.occurredAt, _atDay(2026, 5, 2));
    });

    test('"大前天 早饭 12" → 大前天（不会被"前天"截断）', () {
      final r = _parser().parse('大前天 早饭 12');
      expect(r.occurredAt, _atDay(2026, 5, 1));
      expect(r.categoryParentKey, 'food');
      expect(r.amount, 12);
    });

    test('"上周五 100" → 2026-05-01（基准为周一）', () {
      final r = _parser().parse('上周五 100');
      expect(r.occurredAt, _atDay(2026, 5, 1));
    });

    test('"3天前 烧烤 88" → 3 天前', () {
      final r = _parser().parse('3天前 烧烤 88');
      expect(r.amount, 88);
      expect(r.categoryParentKey, 'food');
      expect(r.occurredAt, _atDay(2026, 5, 1));
    });

    test('"5 天前" 数字与"天前"间允许空格', () {
      final r = _parser().parse('5 天前 50');
      expect(r.occurredAt, _atDay(2026, 4, 29));
    });
  });

  group('note 备注剥离 + confidence 置信度', () {
    test('"午饭 30" 残余应为空', () {
      final r = _parser().parse('午饭 30');
      expect(r.note, isNull);
    });

    test('"昨天 给猫买罐头 25" 应保留"给猫买罐头"', () {
      final r = _parser().parse('昨天 给猫买罐头 25');
      expect(r.amount, 25);
      expect(r.occurredAt, _atDay(2026, 5, 3));
      expect(r.note, contains('给猫'));
      expect(r.note, contains('罐头'));
    });

    test('置信度 < 0.6 时由 UI 决定是否提示 AI（此处仅做下限断言）', () {
      // 仅识别中文金额，不命中分类、不命中时间 → 0.4
      final r = _parser().parse('三十块');
      expect(r.confidence, lessThan(0.6));
    });

    test('全维度命中应取得满分 1.0', () {
      // 阿拉伯金额(0.5) + 分类(0.4) + 时间(0.1) = 1.0
      final r = _parser().parse('昨天 午餐 28');
      expect(r.confidence, closeTo(1.0, 1e-9));
    });

    test('空输入返回零置信度结果', () {
      final r = _parser().parse('');
      expect(r.amount, isNull);
      expect(r.categoryParentKey, isNull);
      expect(r.occurredAt, isNull);
      expect(r.note, isNull);
      expect(r.confidence, 0.0);
    });

    test('rawText 保留原输入', () {
      const input = '  昨天 午饭 30 ';
      final r = _parser().parse(input);
      expect(r.rawText, input);
    });
  });

  group('QuickParseResult', () {
    test('@immutable + toString 含关键字段', () {
      const r = QuickParseResult(
        amount: 30,
        categoryParentKey: 'food',
        categoryLabel: '餐饮',
        confidence: 0.9,
        occurredAt: null,
        note: 'demo',
        rawText: '午饭 30',
      );
      // 仅做存在性断言，避免格式化细节耦合
      final s = r.toString();
      expect(s, contains('30'));
      expect(s, contains('food'));
      expect(s, contains('demo'));
      // 防止 immutable 被错改：foundation.@immutable 是 const 标记，已经构造成 const 即说明合规
      expect(r, isA<QuickParseResult>());
    });

    test('immutable 注解断言（编译期）', () {
      // 仅充当编译期保护：若 QuickParseResult 失去 @immutable，本测试不会失败，
      // 但 lint(`must_be_immutable`) 会拦截。这里仅做 import 占位避免未使用警告。
      expect(immutable, isNotNull);
    });
  });
}
