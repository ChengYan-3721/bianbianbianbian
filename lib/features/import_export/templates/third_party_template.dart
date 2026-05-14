// i18n-exempt: third-party CSV format detection keyword
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:intl/intl.dart';

import '../import_service.dart' show BackupImportCsvRow, BackupImportException;

/// 第三方账单模板抽象——把不同 App 导出的 CSV 行规范化成本 App 通用的
/// [BackupImportCsvRow]，复用 [BackupImportService.apply] 的 CSV 写库通道。
///
/// 每个模板自己负责：
/// - [matches]：根据二维 CSV 行内容判断是不是自己（匹配 header 关键字 + 必备列数）；
/// - [parse]：把命中的二维 rows 解析为 [BackupImportCsvRow] 列表；
/// - 字段填充约定：
///   - `ledgerLabel` 设为 [displayName]（如「微信账单」）——DB 不会有同名账本，
///     触发 unresolved → 全部落到 fallback 当前账本。**这是预期行为**：用户主动
///     把第三方账单导入到现有账本里。
///   - `categoryName` 用关键词映射输出**本地二级分类名**（"早餐"/"购物"...）；
///     未命中归 [`其他`]（默认 seed 里 `other.其他` 必存在）。
///   - `accountName` 透传账单里的支付方式 / 资金账户原名；DB resolve 不到就置 null。
abstract class ThirdPartyTemplate {
  const ThirdPartyTemplate();

  /// 模板唯一标识（不展示给用户，仅日志 / 测试用）。
  String get id;

  /// 用户可见名称（导入页"识别为：xxx"显示）。
  String get displayName;

  /// 是否能识别这个 CSV。**仅看二维 rows 的内容签名**（首行或前若干行 header），
  /// 不读字节、不读文件名后缀——实施计划 Step 13.4 要求"识别其列结构"。
  bool matches(List<List<String>> rows);

  /// 解析；调用方保证 [matches] 已返回 true，否则可抛 [BackupImportException]。
  ///
  /// 跳过状态异常的行（已退款 / 已关闭 / 失败）——只导入"成功的真实交易"。
  List<BackupImportCsvRow> parse(List<List<String>> rows);
}

/// 模板匹配结果——`detectThirdPartyTemplate` 返回。
@immutable
class ThirdPartyMatch {
  const ThirdPartyMatch({required this.template, required this.rows});
  final ThirdPartyTemplate template;
  final List<BackupImportCsvRow> rows;
}

/// 注册所有模板的入口——按列表顺序逐一 [ThirdPartyTemplate.matches]，命中第一个即返回。
///
/// 顺序对外不暴露——但**钱迹放最后**：钱迹模板的 header 关键字最弱（只看
/// "类型"+"金额"+"分类"），可能被微信 / 支付宝的更具体 header 误命中前者。
const List<ThirdPartyTemplate> kAllThirdPartyTemplates = [
  WechatBillTemplate(),
  AlipayBillTemplate(),
  QianjiTemplate(),
];

/// 主入口：识别并解析三方账单。
ThirdPartyMatch? detectThirdPartyTemplate(List<List<String>> rows) {
  if (rows.isEmpty) return null;
  for (final t in kAllThirdPartyTemplates) {
    if (t.matches(rows)) {
      return ThirdPartyMatch(template: t, rows: t.parse(rows));
    }
  }
  return null;
}

// ── 关键词→本地二级分类映射 ─────────────────────────────────────────────
//
// 设计原则：
// - **键是子串**（不是精确匹配）——账单里的"商品名称"/"交易对方"通常是商户全名
//   （如"星巴克咖啡(国贸三期店)"），用 contains 才能命中"星巴克"。
// - **值是本地二级分类名**——必须与 `seeder.dart#categoriesByParent` 里出现的
//   名字字面对齐（不带 emoji）；apply 阶段按 name 匹配。
// - 顺序敏感：靠前的优先。把"长关键词"放前面（"招商银行" 在 "银行" 前），避免短
//   词把长词覆盖。
// - 未命中 → [kFallbackCategoryName]。

/// 关键词 → 本地二级分类名。覆盖钱迹 / 微信 / 支付宝常见交易对手 + 商品名。
@visibleForTesting
const List<MapEntry<String, String>> kKeywordToCategory = [
  // 餐饮（食）
  MapEntry('星巴克', '饮料'),
  MapEntry('瑞幸', '饮料'),
  MapEntry('喜茶', '饮料'),
  MapEntry('奶茶', '饮料'),
  MapEntry('咖啡', '饮料'),
  MapEntry('饮料', '饮料'),
  MapEntry('麦当劳', '午餐'),
  MapEntry('肯德基', '午餐'),
  MapEntry('汉堡', '午餐'),
  MapEntry('美团外卖', '午餐'),
  MapEntry('饿了么', '午餐'),
  MapEntry('外卖', '午餐'),
  MapEntry('餐饮', '午餐'),
  MapEntry('火锅', '晚餐'),
  MapEntry('烧烤', '晚餐'),
  MapEntry('零食', '零食'),
  MapEntry('便利店', '零食'),
  MapEntry('全家', '零食'),
  MapEntry('711', '零食'),
  // 交通（行）
  MapEntry('滴滴', '打车'),
  MapEntry('高德打车', '打车'),
  MapEntry('出租车', '打车'),
  MapEntry('网约车', '打车'),
  MapEntry('地铁', '地铁公交'),
  MapEntry('公交', '地铁公交'),
  MapEntry('一卡通', '地铁公交'),
  MapEntry('Metro', '地铁公交'),
  MapEntry('加油', '加油'),
  MapEntry('中石化', '加油'),
  MapEntry('中石油', '加油'),
  MapEntry('停车', '停车'),
  MapEntry('etc', '加油'),
  MapEntry('火车票', '火车机票'),
  MapEntry('12306', '火车机票'),
  MapEntry('航空', '火车机票'),
  MapEntry('机票', '火车机票'),
  MapEntry('携程', '火车机票'),
  // 购物
  MapEntry('淘宝', '其他购物'),
  MapEntry('天猫', '其他购物'),
  MapEntry('京东', '其他购物'),
  MapEntry('拼多多', '其他购物'),
  MapEntry('唯品会', '其他购物'),
  MapEntry('优衣库', '服饰'),
  MapEntry('ZARA', '服饰'),
  MapEntry('H&M', '服饰'),
  MapEntry('耐克', '服饰'),
  MapEntry('阿迪', '服饰'),
  MapEntry('衣服', '服饰'),
  MapEntry('鞋', '服饰'),
  MapEntry('Apple', '数码'),
  MapEntry('苹果', '数码'),
  MapEntry('华为', '数码'),
  MapEntry('小米', '数码'),
  MapEntry('数码', '数码'),
  MapEntry('家居', '家居'),
  MapEntry('宜家', '家居'),
  MapEntry('IKEA', '家居'),
  MapEntry('超市', '日用品'),
  MapEntry('沃尔玛', '日用品'),
  MapEntry('家乐福', '日用品'),
  MapEntry('永辉', '日用品'),
  MapEntry('盒马', '日用品'),
  // 娱乐
  MapEntry('电影', '电影'),
  MapEntry('万达', '电影'),
  MapEntry('影院', '电影'),
  MapEntry('游戏', '游戏'),
  MapEntry('Steam', '游戏'),
  MapEntry('腾讯游戏', '游戏'),
  MapEntry('网易游戏', '游戏'),
  MapEntry('KTV', '聚会'),
  MapEntry('酒吧', '聚会'),
  MapEntry('密室', '聚会'),
  MapEntry('景区', '旅行娱乐'),
  MapEntry('门票', '旅行娱乐'),
  // 住房
  MapEntry('房租', '房租'),
  MapEntry('物业', '物业'),
  MapEntry('水费', '水费'),
  MapEntry('电费', '电费'),
  MapEntry('燃气', '燃气'),
  MapEntry('天然气', '燃气'),
  // 医疗
  MapEntry('医院', '门诊'),
  MapEntry('药房', '购药'),
  MapEntry('药店', '购药'),
  MapEntry('体检', '体检'),
  // 教育
  MapEntry('得到', '课程'),
  MapEntry('网易云课堂', '课程'),
  MapEntry('知乎', '课程'),
  MapEntry('图书', '书籍'),
  MapEntry('当当', '书籍'),
  MapEntry('Kindle', '书籍'),
  // 收入
  MapEntry('工资', '工资'),
  MapEntry('退款', '退款'),
  MapEntry('红包', '红包'),
  MapEntry('转账', '其他收入'),
  // 通信 / 订阅
  MapEntry('话费', '订阅'),
  MapEntry('流量', '订阅'),
  MapEntry('Netflix', '订阅'),
  MapEntry('iCloud', '订阅'),
  MapEntry('订阅', '订阅'),
  MapEntry('会员', '订阅'),
];

/// 未命中关键词时归到本地分类名（必须与 seeder 的 `other` 一级下某个二级名一致）。
const String kFallbackCategoryName = '其他';

/// 把"商户名 / 商品名 / 备注"等候选文本拼起来，按 [kKeywordToCategory] 顺序
/// 找第一个**子串命中**的关键词，返回对应本地二级分类名；都不命中返回
/// [kFallbackCategoryName]。
@visibleForTesting
String mapKeywordToCategory(List<String?> candidates) {
  final buf = StringBuffer();
  for (final c in candidates) {
    if (c != null && c.isNotEmpty) {
      buf.write(c);
      buf.write(' ');
    }
  }
  final text = buf.toString();
  if (text.isEmpty) return kFallbackCategoryName;
  for (final entry in kKeywordToCategory) {
    if (text.contains(entry.key)) {
      return entry.value;
    }
  }
  return kFallbackCategoryName;
}

// ── 通用解析工具 ──────────────────────────────────────────────────────

/// 去掉 `¥`、`￥`、千位分隔逗号 + 前后空格，再 [double.tryParse]。
@visibleForTesting
double? parseAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  // 去除货币符号
  s = s.replaceAll('¥', '').replaceAll('￥', '').replaceAll(r'$', '').trim();
  // 去除千位分隔符 + 引号包裹（部分账单导出时金额在引号里）
  s = s.replaceAll(',', '').replaceAll('"', '').trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// 多格式日期解析（账单 vs 钱迹格式有差异）：
/// - `yyyy-MM-dd HH:mm:ss`（微信 / 支付宝）
/// - `yyyy-MM-dd HH:mm`（钱迹默认 / 本 App）
/// - `yyyy-MM-dd`（兜底）
/// - `yyyy/MM/dd HH:mm:ss`（部分账单）
/// 解析失败返回 null（调用方决定是抛错还是跳过该行）。
@visibleForTesting
DateTime? parseFlexibleDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  const formats = [
    'yyyy-MM-dd HH:mm:ss',
    'yyyy-MM-dd HH:mm',
    'yyyy-MM-dd',
    'yyyy/MM/dd HH:mm:ss',
    'yyyy/MM/dd HH:mm',
    'yyyy/MM/dd',
  ];
  for (final f in formats) {
    try {
      return DateFormat(f).parseStrict(s);
    } on FormatException {
      // 尝试下一个
    }
  }
  return null;
}

// ── 微信账单 ──────────────────────────────────────────────────────────

/// 微信支付账单模板。
///
/// **来源**：微信支付 → 账单 → 申请账单 → 邮箱接收 → 解压 ZIP → CSV。
///
/// **结构**：文件头有 16 行说明文字（"以下为本人微信账单明细列表..."），第 17
/// 行为 header：
/// `交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注`
///
/// 由于说明行数可能因版本浮动，[matches] 与 [parse] 都靠**找 header 行**而不是
/// 固定行号。
class WechatBillTemplate extends ThirdPartyTemplate {
  const WechatBillTemplate();

  @override
  String get id => 'wechat_bill';

  @override
  String get displayName => '微信账单';

  /// header 必含的列名（不分大小写、不分中英标点；用作 [matches] 签名）。
  static const List<String> _kHeaderSignals = [
    '交易时间',
    '交易类型',
    '交易对方',
    '收/支',
  ];

  @override
  bool matches(List<List<String>> rows) {
    return _findHeaderRow(rows) != null;
  }

  @override
  List<BackupImportCsvRow> parse(List<List<String>> rows) {
    final headerIdx = _findHeaderRow(rows);
    if (headerIdx == null) {
      throw const BackupImportException('微信账单：未找到表头');
    }
    final header = rows[headerIdx];
    final col = _columnIndexer(header);
    final out = <BackupImportCsvRow>[];
    for (var i = headerIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < header.length) continue;
      // 状态列含"已全额退款" / "支付失败" / "已关闭" 之类的跳过
      final status = col(row, '当前状态') ?? '';
      if (status.contains('退款') ||
          status.contains('失败') ||
          status.contains('关闭') ||
          status.contains('未支付')) {
        continue;
      }
      final dateStr = col(row, '交易时间') ?? '';
      final occurredAt = parseFlexibleDate(dateStr);
      if (occurredAt == null) continue;
      final amountRaw = col(row, '金额(元)') ?? col(row, '金额（元）') ?? '';
      final amount = parseAmount(amountRaw);
      if (amount == null || amount <= 0) continue;
      final ioFlag = col(row, '收/支') ?? '';
      final type = _typeFromIoFlag(ioFlag);
      // "/" 或空 → 跳过（中性流水，例如零钱通转入零钱）
      if (type == null) continue;

      final counterparty = col(row, '交易对方') ?? '';
      final goods = col(row, '商品') ?? '';
      final txType = col(row, '交易类型') ?? '';
      final payway = col(row, '支付方式') ?? '';
      final remark = col(row, '备注');

      final categoryName = mapKeywordToCategory([
        counterparty,
        goods,
        txType,
      ]);
      final note = _composeNote([counterparty, goods, remark]);

      out.add(BackupImportCsvRow(
        ledgerLabel: displayName,
        occurredAt: occurredAt,
        type: type,
        amount: amount,
        currency: 'CNY',
        categoryName: categoryName,
        accountName: payway.isEmpty ? null : payway,
        note: note,
      ));
    }
    return out;
  }

  static int? _findHeaderRow(List<List<String>> rows) {
    final scanLimit = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 6) continue;
      // header 行必须同时包含所有信号词
      final joined = row.join('|');
      if (_kHeaderSignals.every(joined.contains)) {
        return i;
      }
    }
    return null;
  }
}

// ── 支付宝账单 ────────────────────────────────────────────────────────

/// 支付宝账单模板。
///
/// **来源**：支付宝 App → 我的 → 账单 → 开具交易流水证明 → 选 CSV → 邮箱。
/// 也可以是网页版导出。
///
/// **结构**：文件头若干行说明 + 表头：
/// `交易号,商家订单号,交易创建时间,付款时间,最近修改时间,交易来源地,类型,
///  交易对方,商品名称,金额（元）,收/支,交易状态,服务费（元）,成功退款（元）,备注,资金状态`
///
/// 行尾通常有页脚说明（"导出时间:...", "总笔数:..."），同时空行也常见——
/// [parse] 跳过空行 + 列数不足的行。
class AlipayBillTemplate extends ThirdPartyTemplate {
  const AlipayBillTemplate();

  @override
  String get id => 'alipay_bill';

  @override
  String get displayName => '支付宝账单';

  static const List<String> _kHeaderSignals = [
    '交易号',
    '交易创建时间',
    '商品名称',
    '金额',
    '收/支',
  ];

  @override
  bool matches(List<List<String>> rows) {
    return _findHeaderRow(rows) != null;
  }

  @override
  List<BackupImportCsvRow> parse(List<List<String>> rows) {
    final headerIdx = _findHeaderRow(rows);
    if (headerIdx == null) {
      throw const BackupImportException('支付宝账单：未找到表头');
    }
    final header = rows[headerIdx];
    final col = _columnIndexer(header);
    final out = <BackupImportCsvRow>[];
    for (var i = headerIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < header.length) continue;
      final status = col(row, '交易状态') ?? '';
      if (status.contains('退款') ||
          status.contains('关闭') ||
          status.contains('失败')) {
        continue;
      }
      final dateStr = col(row, '交易创建时间') ?? col(row, '付款时间') ?? '';
      final occurredAt = parseFlexibleDate(dateStr);
      if (occurredAt == null) continue;
      final amountRaw = col(row, '金额（元）') ?? col(row, '金额(元)') ?? '';
      final amount = parseAmount(amountRaw);
      if (amount == null || amount <= 0) continue;
      final ioFlag = col(row, '收/支') ?? '';
      final type = _typeFromIoFlag(ioFlag);
      if (type == null) continue;

      final counterparty = col(row, '交易对方') ?? '';
      final goods = col(row, '商品名称') ?? '';
      final txType = col(row, '类型') ?? '';
      final remark = col(row, '备注');

      final categoryName = mapKeywordToCategory([
        counterparty,
        goods,
        txType,
      ]);
      final note = _composeNote([counterparty, goods, remark]);

      out.add(BackupImportCsvRow(
        ledgerLabel: displayName,
        occurredAt: occurredAt,
        type: type,
        amount: amount,
        currency: 'CNY',
        categoryName: categoryName,
        accountName: '支付宝',
        note: note,
      ));
    }
    return out;
  }

  static int? _findHeaderRow(List<List<String>> rows) {
    final scanLimit = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 8) continue;
      final joined = row.join('|');
      if (_kHeaderSignals.every(joined.contains)) {
        return i;
      }
    }
    return null;
  }
}

// ── 钱迹 ──────────────────────────────────────────────────────────────

/// 钱迹（Qianji）账单模板。
///
/// **来源**：钱迹 App → 我的 → 备份 → 导出 CSV。
///
/// **结构**：钱迹历史版本 header 浮动较大；本模板兼容两种最常见列序：
/// 1. `时间, 类型, 金额, 一级分类, 二级分类, 账户1, 账户2, 备注`（8 列）
/// 2. `日期, 分类, 子分类, 账户, 金额, 备注`（6 列）
///
/// [matches] 依然走"列名签名"——找到一行同时含 `分类` + `金额`（出现在前 10 列内）
/// 即视为命中。**注意优先级**：必须放在微信 / 支付宝**之后**注册，避免误命中。
class QianjiTemplate extends ThirdPartyTemplate {
  const QianjiTemplate();

  @override
  String get id => 'qianji';

  @override
  String get displayName => '钱迹';

  @override
  bool matches(List<List<String>> rows) {
    return _findHeaderRow(rows) != null;
  }

  @override
  List<BackupImportCsvRow> parse(List<List<String>> rows) {
    final headerIdx = _findHeaderRow(rows);
    if (headerIdx == null) {
      throw const BackupImportException('钱迹：未找到表头');
    }
    final header = rows[headerIdx];
    final col = _columnIndexer(header);
    final out = <BackupImportCsvRow>[];
    for (var i = headerIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < header.length) continue;
      // 钱迹有的版本会在最后一行写汇总，关键字段必须有值才算正常行
      final dateStr = (col(row, '时间') ?? col(row, '日期') ?? '').trim();
      if (dateStr.isEmpty) continue;
      final occurredAt = parseFlexibleDate(dateStr);
      if (occurredAt == null) continue;
      final amountRaw = (col(row, '金额') ?? '').trim();
      final amount = parseAmount(amountRaw);
      if (amount == null) continue;

      // 类型：优先「类型」列；其次根据「金额」正负或"分类"列推断
      String? type;
      final typeLabel = col(row, '类型');
      if (typeLabel != null && typeLabel.isNotEmpty) {
        type = _typeFromQianjiLabel(typeLabel);
      } else {
        // 钱迹的 6 列版本无独立类型列——按金额正负判断（钱迹支出为正）
        // 默认 expense，无法推断 income/transfer
        type = amount.abs() > 0 ? 'expense' : null;
      }
      if (type == null) continue;

      final cat1 = col(row, '一级分类') ?? '';
      final cat2 = col(row, '二级分类') ?? col(row, '子分类') ?? '';
      final cat = col(row, '分类') ?? '';
      final categoryName = _resolveQianjiCategoryName(
        primary: cat1,
        secondary: cat2,
        single: cat,
      );

      final account1 = col(row, '账户1') ?? col(row, '账户') ?? '';
      final account2 = col(row, '账户2') ?? '';
      final remark = col(row, '备注');

      out.add(BackupImportCsvRow(
        ledgerLabel: displayName,
        occurredAt: occurredAt,
        type: type,
        amount: amount.abs(),
        currency: 'CNY',
        categoryName: categoryName,
        accountName: account1.isEmpty ? null : account1,
        toAccountName:
            (type == 'transfer' && account2.isNotEmpty) ? account2 : null,
        note: remark == null || remark.isEmpty ? null : remark,
      ));
    }
    return out;
  }

  /// 钱迹「分类」字段映射策略：
  /// - 优先用二级分类名（更具体，更可能命中本地 seeder 的 name）；
  /// - 二级缺失时退到一级分类，再用关键词映射；
  /// - 都缺失 → fallback。
  static String _resolveQianjiCategoryName({
    required String primary,
    required String secondary,
    required String single,
  }) {
    final s = secondary.trim();
    if (s.isNotEmpty) return s;
    final p = primary.trim();
    if (p.isNotEmpty) return mapKeywordToCategory([p]);
    final sg = single.trim();
    if (sg.isNotEmpty) return mapKeywordToCategory([sg]);
    return kFallbackCategoryName;
  }

  static int? _findHeaderRow(List<List<String>> rows) {
    final scanLimit = rows.length < 10 ? rows.length : 10;
    for (var i = 0; i < scanLimit; i++) {
      final row = rows[i];
      if (row.length < 4) continue;
      // 必须出现"金额"列名 + ("分类"或"一级分类"或"二级分类") + ("时间"或"日期")
      final cols = row.map((c) => c.trim()).toList();
      final joined = cols.join('|');
      final hasAmount = joined.contains('金额');
      final hasCat = joined.contains('分类') || joined.contains('类别');
      final hasDate = joined.contains('时间') || joined.contains('日期');
      if (!(hasAmount && hasCat && hasDate)) continue;
      // 排除本 App 9 列 CSV——它带"账本"/"币种"列；钱迹不会有这两列。
      if (cols.contains('账本') || cols.contains('币种')) continue;
      return i;
    }
    return null;
  }

  static String? _typeFromQianjiLabel(String label) {
    final t = label.trim();
    if (t == '支出') return 'expense';
    if (t == '收入') return 'income';
    if (t == '转账') return 'transfer';
    return null;
  }
}

// ── 共享工具 ──────────────────────────────────────────────────────────

/// "收/支" 列 → 内部 type。
/// - 微信 / 支付宝："支出" / "收入" / 其他（"/"、空、"不计收支"）一律返回 null。
String? _typeFromIoFlag(String flag) {
  final t = flag.trim();
  if (t == '支出') return 'expense';
  if (t == '收入') return 'income';
  return null;
}

/// 把候选文本数组拼成单行备注，去除 null / 空 / 仅斜杠（"/"）的项。
String? _composeNote(List<String?> parts) {
  final keep = <String>[];
  for (final p in parts) {
    if (p == null) continue;
    final t = p.trim();
    if (t.isEmpty || t == '/') continue;
    keep.add(t);
  }
  if (keep.isEmpty) return null;
  return keep.join(' · ');
}

/// 返回一个根据 header 列名取值的闭包——按"列名 → 列索引"的映射；列名不存在
/// 返回 null。**列名匹配是 trim 后精确相等**，调用方多列名时多次调用即可。
String? Function(List<String>, String) _columnIndexer(List<String> header) {
  final idx = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    final key = header[i].trim();
    // 同名列保留首个，与多数表格软件一致
    idx.putIfAbsent(key, () => i);
  }
  return (List<String> row, String name) {
    final i = idx[name];
    if (i == null) return null;
    if (i >= row.length) return null;
    return row[i].trim();
  };
}
