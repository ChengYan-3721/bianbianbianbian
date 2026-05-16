import 'package:bianbianbianbian/core/util/parent_key_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kParentKeyToLabel', () {
    test('11 个 parent_key 全部覆盖', () {
      const keys = [
        'income', 'food', 'shopping', 'transport', 'education',
        'entertainment', 'social', 'housing', 'medical', 'investment', 'other',
      ];
      for (final k in keys) {
        expect(kParentKeyToLabel[k], isNotNull, reason: 'missing $k');
      }
      expect(kParentKeyToLabel.length, 11);
    });

    test('双向映射对称', () {
      kParentKeyToLabel.forEach((key, label) {
        expect(kLabelToParentKey[label], key, reason: 'mismatch $key↔$label');
      });
      expect(kLabelToParentKey.length, kParentKeyToLabel.length);
    });
  });

  group('parentKeyToChineseLabel', () {
    test('已知 key 返回中文', () {
      expect(parentKeyToChineseLabel('food'), '饮食');
      expect(parentKeyToChineseLabel('other'), '其他');
    });

    test('未知 key 返回 null', () {
      expect(parentKeyToChineseLabel('unknown'), isNull);
    });
  });

  group('chineseLabelToParentKey', () {
    test('已知中文返回 key', () {
      expect(chineseLabelToParentKey('饮食'), 'food');
      expect(chineseLabelToParentKey('  其他  '), 'other'); // trim
    });

    test('未知中文返回 null', () {
      expect(chineseLabelToParentKey('火星人'), isNull);
      expect(chineseLabelToParentKey(''), isNull);
    });
  });
}
