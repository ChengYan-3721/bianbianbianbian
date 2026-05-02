import 'package:flutter/foundation.dart';

/// 中文快速记账文本的本地解析结果。
///
/// 字段语义详见 [QuickTextParser.parse] 的注释；任一字段为 null 表示该维度未识别，
/// 由 UI 层（Step 9.2 的"确认卡片"）让用户补全或修正。
@immutable
class QuickParseResult {
  const QuickParseResult({
    required this.amount,
    required this.categoryParentKey,
    required this.categoryLabel,
    required this.confidence,
    required this.occurredAt,
    required this.note,
    required this.rawText,
  });

  /// 金额（人民币，正数）。null 表示未识别到金额。
  final double? amount;

  /// 命中的一级分类 key（与 `seeder.dart::categoriesByParent.keys` 同集）。
  /// null 表示分类词典未命中。
  final String? categoryParentKey;

  /// [categoryParentKey] 的中文标签（与 `budget_providers.dart::kParentKeyLabels` 同义）。
  final String? categoryLabel;

  /// 解析置信度，0.0 ~ 1.0。
  ///
  /// 评分规则（实施计划 Step 9.1）：
  /// - 阿拉伯数字金额命中：+0.5；中文数字金额命中：+0.4；
  /// - 分类词典命中：+0.4；
  /// - 时间关键词命中：+0.1；
  /// - 上限 1.0。
  ///
  /// Step 9.2 默认阈值 0.6 决定是否在确认卡片高亮"请核对"。
  final double confidence;

  /// 解析出的发生时间（已截断到当天 00:00 本地时区）。null 表示未识别。
  final DateTime? occurredAt;

  /// 剥离金额 / 时间 / 分类关键词后的残余文本，作为流水备注的初值。
  /// null 表示残余为空。
  final String? note;

  /// 原始输入文本（trim 之前），便于 UI 回溯展示。
  final String rawText;

  @override
  String toString() {
    return 'QuickParseResult(amount: $amount, parent: $categoryParentKey/$categoryLabel, '
        'confidence: ${confidence.toStringAsFixed(2)}, time: $occurredAt, note: $note)';
  }
}

/// 中文快速记账文本本地解析器。
///
/// 设计依据：design-document §5.1.3 步骤 1-4 + implementation-plan Step 9.1。
/// 解析流程为单线串行（时间在金额之前——避免 `3天前 烧烤 88` 中的 "3" 被金额
/// 正则先吃掉，导致 `(\d+)\s*天前` 无法再命中）：
/// 1. 时间（绝对/相对/N天前/上下周X 三类）；
/// 2. 金额（先阿拉伯数字正则、再中文数字回退）；
/// 3. 分类（关键词词典，长词优先）；
/// 4. 置信度评分；
/// 5. 备注 = 残余文本（去除已识别片段后的 trim）。
///
/// 词典 / 时间关键词都是 const，纯函数解析；不依赖 Flutter / Riverpod / drift。
/// Step 9.3 的 LLM 增强是该结果的"补救路径"——本类只负责提供本地基线 +
/// 置信度信号，由 UI 层根据阈值决定是否展示 AI 按钮。
class QuickTextParser {
  QuickTextParser({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// 一级分类标签，与 `budget_providers.dart::kParentKeyLabels` 保持同义。
  /// 此处特意复制一份而非 import 上层 feature——`core/util` 不允许反向依赖。
  static const Map<String, String> _parentKeyLabels = {
    'income': '收入',
    'food': '餐饮',
    'shopping': '购物',
    'transport': '交通',
    'education': '教育',
    'entertainment': '娱乐',
    'social': '人情',
    'housing': '居家',
    'medical': '医疗',
    'investment': '投资',
    'other': '其他',
  };

  /// 关键词 → parent_key 词典。匹配时按 [_sortedKeywords] 长词优先扫描，
  /// 避免 "午饭" 被泛 "饭" 截断。
  ///
  /// 词典覆盖目标（implementation-plan Step 9.1）：餐饮 / 交通 / 购物 / 娱乐
  /// 为重点；其它一级分类各放少量高频词，留待 Step 9.3 LLM 增强补齐长尾。
  static const Map<String, String> _keywordDict = {
    // food
    '早饭': 'food', '早餐': 'food', '午饭': 'food', '午餐': 'food',
    '晚饭': 'food', '晚餐': 'food', '夜宵': 'food', '吃饭': 'food',
    '外卖': 'food', '零食': 'food', '饮料': 'food', '咖啡': 'food',
    '奶茶': 'food', '火锅': 'food', '烧烤': 'food', '面条': 'food',
    '麦当劳': 'food', '肯德基': 'food', '星巴克': 'food', '聚餐': 'food',
    // transport
    '地铁': 'transport', '公交': 'transport', '打车': 'transport',
    '滴滴': 'transport', '出租车': 'transport', '高铁': 'transport',
    '火车': 'transport', '飞机': 'transport', '机票': 'transport',
    '加油': 'transport', '停车': 'transport', '共享单车': 'transport',
    '车票': 'transport',
    // shopping
    '衣服': 'shopping', '裤子': 'shopping', '鞋子': 'shopping',
    '数码': 'shopping', '手机': 'shopping', '电脑': 'shopping',
    '日用品': 'shopping', '家居': 'shopping', '家具': 'shopping',
    '京东': 'shopping', '淘宝': 'shopping', '拼多多': 'shopping',
    '购物': 'shopping',
    // entertainment
    '电影': 'entertainment', '游戏': 'entertainment',
    'KTV': 'entertainment', '唱K': 'entertainment',
    '旅游': 'entertainment', '旅行': 'entertainment',
    '景点': 'entertainment', '门票': 'entertainment',
    '酒吧': 'entertainment',
    // social
    '礼物': 'social', '红包': 'social', '请客': 'social',
    '随礼': 'social', '份子钱': 'social',
    // housing
    '房租': 'housing', '水费': 'housing', '电费': 'housing',
    '燃气': 'housing', '物业': 'housing', '房贷': 'housing',
    '水电': 'housing',
    // medical
    '看病': 'medical', '医院': 'medical', '门诊': 'medical',
    '买药': 'medical', '吃药': 'medical', '体检': 'medical',
    // education
    '书籍': 'education', '买书': 'education', '课程': 'education',
    '培训': 'education', '学费': 'education', '文具': 'education',
    // investment
    '基金': 'investment', '股票': 'investment', '理财': 'investment',
    '黄金': 'investment', '债券': 'investment',
    // income
    '工资': 'income', '奖金': 'income', '兼职': 'income',
    '报销': 'income', '退款': 'income', '收入': 'income',
  };

  /// 长词优先排序的关键词列表。Dart 3 静态 final + 闭包初始化，进程内仅算一次。
  static final List<String> _sortedKeywords = () {
    final keys = _keywordDict.keys.toList();
    keys.sort((a, b) => b.length.compareTo(a.length));
    return keys;
  }();

  /// 内置时间关键词 → 相对天数偏移（基于"今天 00:00"）。
  /// 大词在前以避免 "大前天" 被 "前天" 截断。
  static const List<(String, int)> _relativeDayKeywords = [
    ('大前天', -3),
    ('前天', -2),
    ('昨天', -1),
    ('昨儿', -1),
    ('今天', 0),
    ('今儿', 0),
    ('明天', 1),
    ('后天', 2),
    ('大后天', 3),
  ];

  /// 阿拉伯数字金额正则。允许前缀 ¥/￥，允许后缀 元/块/￥/¥。
  /// 整个匹配区间在解析后会被替换为空白，剥离后送入备注分支。
  static final RegExp _amountRegex = RegExp(
    r'[¥￥]?(\d+(?:\.\d+)?)\s*(?:元|块|RMB|CNY|￥|¥)?',
    caseSensitive: false,
  );

  /// 中文数字字符集。
  static final RegExp _cnNumeralRegex =
      RegExp(r'[零一二两三四五六七八九十百千万]+');

  /// `N 天前` / `N天前` 相对时间。
  static final RegExp _nDaysAgoRegex = RegExp(r'(\d+)\s*天前');

  /// 上周/这周/本周/下周 + 周一~周日。
  static final RegExp _weekRegex =
      RegExp(r'(上周|这周|本周|下周|上个星期|这个星期|下个星期)([一二三四五六日天])');

  // --------------------------------------------------------------------------
  // 入口
  // --------------------------------------------------------------------------

  QuickParseResult parse(String text) {
    final raw = text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return QuickParseResult(
        amount: null,
        categoryParentKey: null,
        categoryLabel: null,
        confidence: 0.0,
        occurredAt: null,
        note: null,
        rawText: raw,
      );
    }

    // 用一个可变工作字符串：每识别一段就替换为单个空格，最终残留 = 备注。
    var working = trimmed;

    // --- 时间（先于金额：N 天前的 "N" 必须先归入时间片段）-------------------
    DateTime? occurredAt;
    final tm = _matchTime(working);
    if (tm != null) {
      occurredAt = tm.date;
      working = _replaceRangeWithSpace(working, tm.start, tm.end);
    }

    // --- 金额 ---------------------------------------------------------------
    double? amount;
    var amountFromArabic = false;
    final arab = _matchArabicAmount(working);
    if (arab != null) {
      amount = arab.value;
      amountFromArabic = true;
      working = _replaceRangeWithSpace(working, arab.start, arab.end);
    } else {
      final cn = _matchChineseNumeralAmount(working);
      if (cn != null) {
        amount = cn.value;
        working = _replaceRangeWithSpace(working, cn.start, cn.end);
      }
    }

    // --- 分类 ---------------------------------------------------------------
    String? parentKey;
    final cat = _matchCategory(working);
    if (cat != null) {
      parentKey = cat.parentKey;
      working = _replaceRangeWithSpace(working, cat.start, cat.end);
    }

    // --- 置信度 -------------------------------------------------------------
    var confidence = 0.0;
    if (amount != null) confidence += amountFromArabic ? 0.5 : 0.4;
    if (parentKey != null) confidence += 0.4;
    if (occurredAt != null) confidence += 0.1;
    if (confidence > 1.0) confidence = 1.0;

    // --- 备注 ---------------------------------------------------------------
    final noteText = working.replaceAll(RegExp(r'\s+'), ' ').trim();

    return QuickParseResult(
      amount: amount,
      categoryParentKey: parentKey,
      categoryLabel: parentKey == null ? null : _parentKeyLabels[parentKey],
      confidence: confidence,
      occurredAt: occurredAt,
      note: noteText.isEmpty ? null : noteText,
      rawText: raw,
    );
  }

  // --------------------------------------------------------------------------
  // 金额：阿拉伯数字
  // --------------------------------------------------------------------------

  _Range<double>? _matchArabicAmount(String text) {
    final m = _amountRegex.firstMatch(text);
    if (m == null) return null;
    final digits = m.group(1);
    if (digits == null || digits.isEmpty) return null;
    final value = double.tryParse(digits);
    if (value == null || value <= 0) return null;
    return _Range<double>(value: value, start: m.start, end: m.end);
  }

  // --------------------------------------------------------------------------
  // 金额：中文数字
  // --------------------------------------------------------------------------

  _Range<double>? _matchChineseNumeralAmount(String text) {
    final m = _cnNumeralRegex.firstMatch(text);
    if (m == null) return null;
    final str = m.group(0)!;
    final parsed = _parseChineseNumber(str);
    if (parsed == null || parsed <= 0) return null;

    var end = m.end;
    // 中文数字 + 单字符尾缀（元/块/￥/¥）一并归入金额片段。
    if (end < text.length) {
      final next = text[end];
      if (next == '元' || next == '块' || next == '￥' || next == '¥') {
        end += 1;
      }
    }

    final isLengthOk = str.length >= 2;
    final hasUnitSuffix = end > m.end;
    // 单字符中文数字（如 "一"、"二"）若无尾缀，容易把"买了一些菜"中的"一"误判为金额，
    // 因此要求"长度 ≥ 2 个字" 或 "尾缀元/块/¥"才接受。
    if (!isLengthOk && !hasUnitSuffix) return null;

    return _Range<double>(value: parsed.toDouble(), start: m.start, end: end);
  }

  /// 仅支持 0..99,999 的常见中文数字解析（覆盖日常记账场景的金额范围）。
  /// 不支持负数、小数（中文小数极少在记账里出现）、亿。
  @visibleForTesting
  static int? parseChineseNumber(String s) => _parseChineseNumber(s);

  static int? _parseChineseNumber(String s) {
    const digits = {
      '零': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    const units = {'十': 10, '百': 100, '千': 1000};
    var section = 0;
    var current = 0;
    var total = 0;
    var consumed = false;

    for (final ch in s.split('')) {
      if (digits.containsKey(ch)) {
        current = digits[ch]!;
        consumed = true;
      } else if (units.containsKey(ch)) {
        final u = units[ch]!;
        if (current == 0) current = 1; // "十二" → 12
        section += current * u;
        current = 0;
        consumed = true;
      } else if (ch == '万') {
        section += current;
        total += section * 10000;
        section = 0;
        current = 0;
        consumed = true;
      } else {
        return null;
      }
    }
    total += section + current;
    if (!consumed) return null;
    return total > 0 ? total : null;
  }

  // --------------------------------------------------------------------------
  // 时间
  // --------------------------------------------------------------------------

  _TimeMatch? _matchTime(String text) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);

    // 1. 内置相对天数关键词（大词优先扫描）
    for (final entry in _relativeDayKeywords) {
      final kw = entry.$1;
      final offset = entry.$2;
      final idx = text.indexOf(kw);
      if (idx >= 0) {
        return _TimeMatch(
          date: today.add(Duration(days: offset)),
          start: idx,
          end: idx + kw.length,
        );
      }
    }

    // 2. "上周三" / "这周日" / "下周一" 等
    final wm = _weekRegex.firstMatch(text);
    if (wm != null) {
      final relative = wm.group(1)!;
      final dayCh = wm.group(2)!;
      const dayMap = {
        '一': 1,
        '二': 2,
        '三': 3,
        '四': 4,
        '五': 5,
        '六': 6,
        '日': 7,
        '天': 7,
      };
      final targetWeekday = dayMap[dayCh]!;
      final currentWeekday = today.weekday; // 1..7
      var offset = targetWeekday - currentWeekday;
      if (relative == '上周' || relative == '上个星期') offset -= 7;
      if (relative == '下周' || relative == '下个星期') offset += 7;
      return _TimeMatch(
        date: today.add(Duration(days: offset)),
        start: wm.start,
        end: wm.end,
      );
    }

    // 3. "N 天前" / "N天前"
    final nm = _nDaysAgoRegex.firstMatch(text);
    if (nm != null) {
      final n = int.tryParse(nm.group(1)!);
      if (n != null && n > 0) {
        return _TimeMatch(
          date: today.subtract(Duration(days: n)),
          start: nm.start,
          end: nm.end,
        );
      }
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // 分类
  // --------------------------------------------------------------------------

  _CategoryMatch? _matchCategory(String text) {
    for (final kw in _sortedKeywords) {
      final idx = text.indexOf(kw);
      if (idx >= 0) {
        return _CategoryMatch(
          parentKey: _keywordDict[kw]!,
          start: idx,
          end: idx + kw.length,
        );
      }
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // 工具
  // --------------------------------------------------------------------------

  static String _replaceRangeWithSpace(String text, int start, int end) {
    if (start < 0 || end > text.length || start >= end) return text;
    return '${text.substring(0, start)} ${text.substring(end)}';
  }
}

class _Range<T> {
  _Range({required this.value, required this.start, required this.end});

  final T value;
  final int start;
  final int end;
}

class _TimeMatch {
  _TimeMatch({required this.date, required this.start, required this.end});

  final DateTime date;
  final int start;
  final int end;
}

class _CategoryMatch {
  _CategoryMatch({
    required this.parentKey,
    required this.start,
    required this.end,
  });

  final String parentKey;
  final int start;
  final int end;
}
