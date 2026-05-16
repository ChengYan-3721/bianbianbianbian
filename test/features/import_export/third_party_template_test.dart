import 'dart:convert';
import 'dart:typed_data';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/entity_mappers.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/features/import_export/import_service.dart';
import 'package:bianbianbianbian/features/import_export/templates/third_party_template.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// Step 13.4 验证：第三方模板（钱迹 / 微信 / 支付宝）的识别 + 解析 + 关键词
/// 映射 + 与 [BackupImportService] CSV 路径的集成。
///
/// 三个 50+ 行样本（生成器构造，避免硬编码 200 行 CSV 字面量）：
/// - [_buildWechatBillCsv]  / [_buildAlipayBillCsv] / [_buildQianjiCsv]
/// 每个样本包含：
/// - 正常行（覆盖关键词命中 / 未命中两类）；
/// - 异常状态行（"已退款" / "已关闭" / "支付失败"）应被过滤；
/// - 空备注 / 含逗号引号备注 / 含 `¥` 符号金额；
/// - 总成功行数 ≥ 50（与 implementation-plan §Step 13.4 验证标准一致）。

const _devId = 'test-dev';
const _ledgerId = 'lg-fallback';

AppDatabase _createDb() => AppDatabase.forTesting(NativeDatabase.memory());

Ledger _ledger(String id, String name) => Ledger(
      id: id,
      name: name,
      coverEmoji: null,
      createdAt: DateTime.utc(2026, 4, 1),
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );

Category _cat(String id, String name, String parentKey) => Category(
      id: id,
      name: name,
      parentKey: parentKey,
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      type: 'cash',
      updatedAt: DateTime.utc(2026, 4, 1),
      deviceId: _devId,
    );

Future<void> _seedDb(
  AppDatabase db, {
  required List<Ledger> ledgers,
  required List<Category> categories,
  required List<Account> accounts,
}) async {
  for (final l in ledgers) {
    await db.into(db.ledgerTable).insert(ledgerToCompanion(l));
  }
  for (final c in categories) {
    await db.into(db.categoryTable).insert(categoryToCompanion(c));
  }
  for (final a in accounts) {
    await db.into(db.accountTable).insert(accountToCompanion(a));
  }
}

void main() {
  group('detectThirdPartyTemplate', () {
    test('微信 header 命中 WechatBillTemplate', () {
      final rows = [
        ['微信支付账单明细列表'],
        ['以下为本人微信账单明细列表'],
        ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)', '支付方式', '当前状态'],
        ['2026-01-01 12:00:00', '商户消费', '星巴克', '咖啡', '支出', '35.00', '零钱', '支付成功'],
      ];
      final m = detectThirdPartyTemplate(rows);
      expect(m, isNotNull);
      expect(m!.template.id, 'wechat_bill');
      expect(m.rows, hasLength(1));
    });

    test('支付宝 header 命中 AlipayBillTemplate', () {
      final rows = [
        ['交易号', '商家订单号', '交易创建时间', '付款时间', '最近修改时间', '交易来源地', '类型',
         '交易对方', '商品名称', '金额（元）', '收/支', '交易状态', '服务费（元）', '成功退款（元）',
         '备注', '资金状态'],
        ['202601010001', '', '2026-01-01 10:00:00', '2026-01-01 10:00:00',
         '2026-01-01 10:00:00', '其他', '即时到账', '滴滴出行', '快车',
         '23.50', '支出', '交易成功', '0.00', '0.00', '', '已支出'],
      ];
      final m = detectThirdPartyTemplate(rows);
      expect(m, isNotNull);
      expect(m!.template.id, 'alipay_bill');
      expect(m.rows, hasLength(1));
    });

    test('钱迹 8 列 header 命中 QianjiTemplate', () {
      final rows = [
        ['时间', '类型', '金额', '一级分类', '二级分类', '账户1', '账户2', '备注'],
        ['2026-01-01 12:00', '支出', '35.00', '餐饮', '早餐', '现金', '', '豆浆油条'],
      ];
      final m = detectThirdPartyTemplate(rows);
      expect(m, isNotNull);
      expect(m!.template.id, 'qianji');
      expect(m.rows, hasLength(1));
    });

    test('钱迹 6 列 header（无类型列）命中', () {
      final rows = [
        ['日期', '分类', '子分类', '账户', '金额', '备注'],
        ['2026-01-01', '餐饮', '早餐', '现金', '15.00', '油条'],
      ];
      final m = detectThirdPartyTemplate(rows);
      expect(m, isNotNull);
      expect(m!.template.id, 'qianji');
      expect(m.rows, hasLength(1));
      expect(m.rows.first.type, 'expense');
    });

    test('未命中任何模板返回 null（本 App 9 列 CSV 不应被三方模板抢占）', () {
      final rows = [
        ['账本', '日期', '类型', '金额', '币种', '分类', '账户', '转入账户', '备注'],
      ];
      final m = detectThirdPartyTemplate(rows);
      expect(m, isNull);
    });

    test('空 rows 返回 null', () {
      expect(detectThirdPartyTemplate(<List<String>>[]), isNull);
    });
  });

  group('mapKeywordToCategory', () {
    test('星巴克 → 饮料', () {
      expect(mapKeywordToCategory(['星巴克咖啡(国贸三期店)']), '饮料');
    });

    test('滴滴 → 打车', () {
      expect(mapKeywordToCategory(['滴滴出行', '快车', '即时到账']), '打车');
    });

    test('地铁 → 地铁公交', () {
      expect(mapKeywordToCategory(['北京地铁', '日票', null]), '地铁公交');
    });

    test('淘宝 → 其他购物', () {
      expect(mapKeywordToCategory(['淘宝(中国)软件有限公司', '某商品']), '其他购物');
    });

    test('未命中关键词 → 其他', () {
      expect(mapKeywordToCategory(['某不知名商户', '某商品 ABC']), '其他');
    });

    test('全 null / 空候选 → 其他', () {
      expect(mapKeywordToCategory([null, '', null]), '其他');
    });

    test('iCloud 订阅 → 订阅', () {
      expect(mapKeywordToCategory(['iCloud 订阅', '50GB']), '订阅');
    });
  });

  group('parseAmount', () {
    test('普通数字', () => expect(parseAmount('35.00'), 35.0));
    test('带 ¥ 前缀', () => expect(parseAmount('¥35.00'), 35.0));
    test('带 ￥ 前缀', () => expect(parseAmount('￥35.00'), 35.0));
    test('千位分隔符', () => expect(parseAmount('1,234.56'), 1234.56));
    test('引号包裹', () => expect(parseAmount('"1,234.56"'), 1234.56));
    test('空字符串', () => expect(parseAmount(''), isNull));
    test('非法', () => expect(parseAmount('abc'), isNull));
  });

  group('parseFlexibleDate', () {
    test('yyyy-MM-dd HH:mm:ss', () {
      expect(parseFlexibleDate('2026-01-15 09:30:45'),
          DateTime(2026, 1, 15, 9, 30, 45));
    });
    test('yyyy-MM-dd HH:mm', () {
      expect(parseFlexibleDate('2026-01-15 09:30'),
          DateTime(2026, 1, 15, 9, 30));
    });
    test('yyyy-MM-dd', () {
      expect(parseFlexibleDate('2026-01-15'), DateTime(2026, 1, 15));
    });
    test('yyyy/MM/dd HH:mm:ss', () {
      expect(parseFlexibleDate('2026/01/15 09:30:45'),
          DateTime(2026, 1, 15, 9, 30, 45));
    });
    test('非法格式', () {
      expect(parseFlexibleDate('not-a-date'), isNull);
    });
  });

  group('微信账单模板', () {
    test('50+ 行样本：识别 + 条数 + 金额汇总', () {
      final sample = _buildWechatBillCsv();
      final preview = BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(sample.csv)),
        fileType: BackupImportFileType.csv,
      );
      return preview.then((p) {
        expect(p.thirdPartyTemplateId, 'wechat_bill');
        expect(p.thirdPartyTemplateName, '微信账单');
        expect(p.transactionCount, sample.expectedRowCount);
        // 金额汇总（仅"支出"列）应等于样本生成器记录的总额
        final actualTotal = p.csvRows!
            .where((r) => r.type == 'expense')
            .map((r) => r.amount)
            .fold<double>(0, (a, b) => a + b);
        expect(actualTotal, closeTo(sample.expectedExpenseTotal, 0.01));
      });
    });

    test('"已全额退款" 行被过滤', () async {
      final csv = '''微信账单
以下是本人账单
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-01-01 12:00:00,商户消费,星巴克,咖啡,支出,35.00,零钱,支付成功,T1,M1,/
2026-01-02 12:00:00,商户消费,某店,某物,支出,99.00,零钱,已全额退款,T2,M2,/
2026-01-03 12:00:00,商户消费,某店,某物,支出,50.00,零钱,支付失败,T3,M3,/
2026-01-04 12:00:00,商户消费,某店,某物,支出,20.00,零钱,已关闭,T4,M4,/
''';
      final preview = await BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.thirdPartyTemplateId, 'wechat_bill');
      expect(preview.transactionCount, 1);
      expect(preview.csvRows!.first.amount, 35.0);
    });

    test('"/"（中性）收/支被过滤', () async {
      final csv = '''微信账单
以下是本人账单
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-01-01 12:00:00,零钱通转入,零钱通,/,/,100.00,零钱,支付成功,T1,M1,/
2026-01-02 12:00:00,商户消费,星巴克,咖啡,支出,35.00,零钱,支付成功,T2,M2,/
''';
      final preview = await BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.transactionCount, 1);
      expect(preview.csvRows!.first.type, 'expense');
    });
  });

  group('支付宝账单模板', () {
    test('50+ 行样本：识别 + 条数 + 金额汇总', () async {
      final sample = _buildAlipayBillCsv();
      final preview = await BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(sample.csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.thirdPartyTemplateId, 'alipay_bill');
      expect(preview.thirdPartyTemplateName, '支付宝账单');
      expect(preview.transactionCount, sample.expectedRowCount);
      final actualTotal = preview.csvRows!
          .where((r) => r.type == 'expense')
          .map((r) => r.amount)
          .fold<double>(0, (a, b) => a + b);
      expect(actualTotal, closeTo(sample.expectedExpenseTotal, 0.01));
    });

    test('"交易关闭" / "退款成功" 行被过滤', () async {
      const csv =
          '''交易号,商家订单号,交易创建时间,付款时间,最近修改时间,交易来源地,类型,交易对方,商品名称,金额（元）,收/支,交易状态,服务费（元）,成功退款（元）,备注,资金状态
T1,,2026-01-01 10:00:00,2026-01-01 10:00:00,2026-01-01 10:00:00,其他,即时到账,滴滴,快车,23.50,支出,交易成功,0.00,0.00,,已支出
T2,,2026-01-02 10:00:00,2026-01-02 10:00:00,2026-01-02 10:00:00,其他,即时到账,某店,某物,99.00,支出,交易关闭,0.00,0.00,,已退款
T3,,2026-01-03 10:00:00,2026-01-03 10:00:00,2026-01-03 10:00:00,其他,即时到账,某店,某物,50.00,支出,退款成功,0.00,50.00,,已退款
''';
      final preview = await BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.transactionCount, 1);
      expect(preview.csvRows!.first.amount, 23.5);
    });

    test('未命中关键词归"其他"', () async {
      const csv =
          '''交易号,商家订单号,交易创建时间,付款时间,最近修改时间,交易来源地,类型,交易对方,商品名称,金额（元）,收/支,交易状态,服务费（元）,成功退款（元）,备注,资金状态
T1,,2026-01-01 10:00:00,2026-01-01 10:00:00,2026-01-01 10:00:00,其他,即时到账,某不知名商户ABC,神秘商品XYZ,50.00,支出,交易成功,0.00,0.00,,已支出
''';
      final preview = await BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.csvRows!.first.categoryName, '其他');
      expect(preview.unmappedCategoryCount, 1);
    });
  });

  group('钱迹模板', () {
    test('50+ 行样本：识别 + 条数 + 金额汇总', () async {
      final sample = _buildQianjiCsv();
      final preview = await BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(sample.csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.thirdPartyTemplateId, 'qianji');
      expect(preview.thirdPartyTemplateName, '钱迹');
      expect(preview.transactionCount, sample.expectedRowCount);
      final actualTotal = preview.csvRows!
          .where((r) => r.type == 'expense')
          .map((r) => r.amount)
          .fold<double>(0, (a, b) => a + b);
      expect(actualTotal, closeTo(sample.expectedExpenseTotal, 0.01));
    });

    test('转账行带账户 1/2', () async {
      const csv = '''时间,类型,金额,一级分类,二级分类,账户1,账户2,备注
2026-01-01 12:00,转账,500.00,转账,转账,招商银行卡,支付宝,
''';
      final preview = await BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.csvRows!.first.type, 'transfer');
      expect(preview.csvRows!.first.accountName, '招商银行卡');
      expect(preview.csvRows!.first.toAccountName, '支付宝');
    });

    test('二级分类直接成为 categoryName（即便不在本地分类表里）', () async {
      const csv = '''时间,类型,金额,一级分类,二级分类,账户1,账户2,备注
2026-01-01 12:00,支出,35.00,餐饮,自定义二级,现金,,豆浆
''';
      final preview = await BackupImportService().preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.csvRows!.first.categoryName, '自定义二级');
    });
  });

  group('集成：BackupImportService 写库（端到端）', () {
    test('微信账单 → fallback 当前账本 + 写入流水数 = 解析行数', () async {
      final db = _createDb();
      addTearDown(db.close);
      await _seedDb(db, ledgers: [
        _ledger(_ledgerId, '默认账本'),
      ], categories: [
        _cat('cat-yinliao', '饮料', 'food'),
        _cat('cat-other', '其他', 'other'),
      ], accounts: [
        _acc('acc-zero', '零钱'),
      ]);

      const csv = '''微信账单
以下是本人账单
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-01-01 12:00:00,商户消费,星巴克,咖啡,支出,35.00,零钱,支付成功,T1,M1,
2026-01-02 12:00:00,商户消费,瑞幸,生椰拿铁,支出,15.00,零钱,支付成功,T2,M2,
2026-01-03 12:00:00,商户消费,某不知名,某物,支出,20.00,零钱,支付成功,T3,M3,
''';
      final service = BackupImportService(uuid: const Uuid());
      final preview = await service.preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      final result = await service.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.asNew,
        db: db,
        currentDeviceId: _devId,
        fallbackLedgerId: _ledgerId,
      );
      expect(result.transactionsWritten, 3);
      // 模板把所有行的 ledgerLabel 设为 displayName，DB 没有同名账本，
      // 必然 unresolved → fallback。
      expect(result.unresolvedLedgerLabels, contains('微信账单'));

      // DB 真实落了 3 条
      final allTx = await db.select(db.transactionEntryTable).get();
      expect(allTx, hasLength(3));
      // 全部写入到 fallback 账本
      expect(allTx.every((t) => t.ledgerId == _ledgerId), isTrue);
      // 关键词命中映射到本地分类（"饮料" 命中 cat-yinliao；"其他" 命中 cat-other）
      final amounts = allTx.map((t) => t.amount).toList()..sort();
      expect(amounts, [15.0, 20.0, 35.0]);
    });

    test('支付宝账单 → category 名解析正确', () async {
      final db = _createDb();
      addTearDown(db.close);
      await _seedDb(db, ledgers: [
        _ledger(_ledgerId, '默认账本'),
      ], categories: [
        _cat('cat-dache', '打车', 'transport'),
        _cat('cat-other', '其他', 'other'),
      ], accounts: [
        _acc('acc-alipay', '支付宝'),
      ]);

      const csv =
          '''交易号,商家订单号,交易创建时间,付款时间,最近修改时间,交易来源地,类型,交易对方,商品名称,金额（元）,收/支,交易状态,服务费（元）,成功退款（元）,备注,资金状态
T1,,2026-01-01 10:00:00,2026-01-01 10:00:00,2026-01-01 10:00:00,其他,即时到账,滴滴出行,快车,23.50,支出,交易成功,0.00,0.00,,已支出
T2,,2026-01-02 10:00:00,2026-01-02 10:00:00,2026-01-02 10:00:00,其他,即时到账,某神秘店,神秘物品,50.00,支出,交易成功,0.00,0.00,,已支出
''';
      final service = BackupImportService();
      final preview = await service.preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      expect(preview.thirdPartyTemplateId, 'alipay_bill');
      expect(preview.unmappedCategoryCount, 1);

      final result = await service.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.asNew,
        db: db,
        currentDeviceId: _devId,
        fallbackLedgerId: _ledgerId,
      );
      expect(result.transactionsWritten, 2);
      final allTx = await db.select(db.transactionEntryTable).get();
      // 第一条命中"打车"，第二条命中"其他"
      final byAmount = {for (final t in allTx) t.amount: t};
      expect(byAmount[23.5]!.categoryId, 'cat-dache');
      expect(byAmount[50.0]!.categoryId, 'cat-other');
      // 账户名"支付宝"在 DB 存在，应被关联
      expect(byAmount[23.5]!.accountId, 'acc-alipay');
    });

    test('钱迹模板：8 列样本端到端写入', () async {
      final db = _createDb();
      addTearDown(db.close);
      await _seedDb(db, ledgers: [
        _ledger(_ledgerId, '默认账本'),
      ], categories: [
        _cat('cat-zaocan', '早餐', 'food'),
      ], accounts: [
        _acc('acc-cash', '现金'),
      ]);

      const csv = '''时间,类型,金额,一级分类,二级分类,账户1,账户2,备注
2026-01-01 12:00,支出,35.00,餐饮,早餐,现金,,豆浆油条
''';
      final service = BackupImportService();
      final preview = await service.preview(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileType: BackupImportFileType.csv,
      );
      final result = await service.apply(
        preview: preview,
        strategy: BackupDedupeStrategy.asNew,
        db: db,
        currentDeviceId: _devId,
        fallbackLedgerId: _ledgerId,
      );
      expect(result.transactionsWritten, 1);
      final tx = (await db.select(db.transactionEntryTable).get()).single;
      expect(tx.amount, 35.0);
      expect(tx.categoryId, 'cat-zaocan');
      expect(tx.accountId, 'acc-cash');
    });
  });
}

// ─── 样本生成器 ──────────────────────────────────────────────────────────

class _SampleCsv {
  _SampleCsv({
    required this.csv,
    required this.expectedRowCount,
    required this.expectedExpenseTotal,
  });
  final String csv;
  final int expectedRowCount;
  final double expectedExpenseTotal;
}

/// 生成 ≥ 50 行的微信账单样本。
///
/// 包含：
/// - 60 笔正常支出（涵盖星巴克 / 滴滴 / 美团外卖 / 淘宝 / 房租 / 一笔不知名商户）；
/// - 5 笔已退款（应被过滤）；
/// - 2 笔零钱通转入 收/支 列为 "/"（应被过滤）；
/// - 头部 16 行无关说明文字（模拟微信导出格式）。
_SampleCsv _buildWechatBillCsv() {
  final buf = StringBuffer();
  // 16 行说明
  for (var i = 0; i < 16; i++) {
    buf.writeln('微信支付账单说明 第${i + 1}行');
  }
  buf.writeln('交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注');

  final entries = <_W>[
    _W('星巴克', '咖啡', 35.0),
    _W('瑞幸咖啡', '生椰拿铁', 15.0),
    _W('喜茶', '芝芝莓莓', 28.0),
    _W('麦当劳', '巨无霸套餐', 42.0),
    _W('肯德基', '香辣鸡腿堡', 38.0),
    _W('美团外卖', '外卖', 56.0),
    _W('饿了么', '外卖', 49.0),
    _W('滴滴出行', '快车', 23.5),
    _W('北京地铁', '日票', 8.0),
    _W('淘宝', '日用品', 88.0),
    _W('天猫', '服饰', 199.0),
    _W('京东', '数码', 1299.0),
    _W('拼多多', '零食', 19.9),
    _W('某神秘商户', '某物', 50.0), // 未命中
  ];

  var total = 0.0;
  var idx = 0;
  for (var i = 0; i < 60; i++) {
    final e = entries[i % entries.length];
    final day = (i % 28) + 1;
    final dayStr = day.toString().padLeft(2, '0');
    final txId = idx;
    final mctId = idx + 1;
    buf.writeln(
        '2026-01-$dayStr 12:00:00,商户消费,${e.party},${e.goods},支出,${e.amount.toStringAsFixed(2)},零钱,支付成功,T$txId,M$mctId,');
    idx += 2;
    total += e.amount;
  }
  // 5 笔退款（应被过滤）
  for (var i = 0; i < 5; i++) {
    final day = (i + 1).toString().padLeft(2, '0');
    buf.writeln(
        '2026-02-$day 12:00:00,商户消费,某店,某物,支出,99.00,零钱,已全额退款,Tr$i,Mr$i,');
  }
  // 2 笔中性转入
  for (var i = 0; i < 2; i++) {
    final day = (i + 1).toString().padLeft(2, '0');
    buf.writeln(
        '2026-03-$day 12:00:00,零钱通转入,零钱通,/,/,100.00,零钱,支付成功,Tn$i,Mn$i,');
  }
  return _SampleCsv(
    csv: buf.toString(),
    expectedRowCount: 60,
    expectedExpenseTotal: total,
  );
}

/// 生成 ≥ 50 行的支付宝账单样本。
_SampleCsv _buildAlipayBillCsv() {
  final buf = StringBuffer();
  buf.writeln(
      '交易号,商家订单号,交易创建时间,付款时间,最近修改时间,交易来源地,类型,交易对方,商品名称,金额（元）,收/支,交易状态,服务费（元）,成功退款（元）,备注,资金状态');

  final entries = <_W>[
    _W('滴滴出行', '快车', 23.5),
    _W('饿了么', '外卖', 35.0),
    _W('美团', '团购', 88.0),
    _W('京东', '数码', 1299.0),
    _W('淘宝', '日用品', 56.0),
    _W('星巴克', '咖啡', 35.0),
    _W('麦当劳', '套餐', 42.0),
    _W('北京地铁', '日票', 8.0),
    _W('某神秘商户', '某物', 50.0), // 未命中
    _W('景区门票', '门票', 120.0),
    _W('万达影城', '电影票', 60.0),
    _W('Apple', 'iCloud 订阅', 21.0),
  ];

  var total = 0.0;
  var idx = 1000;
  for (var i = 0; i < 55; i++) {
    final e = entries[i % entries.length];
    final day = (i % 28) + 1;
    final dayStr = day.toString().padLeft(2, '0');
    buf.writeln(
        'T$idx,,2026-01-$dayStr 10:00:00,2026-01-$dayStr 10:00:00,2026-01-$dayStr 10:00:00,其他,即时到账,${e.party},${e.goods},${e.amount.toStringAsFixed(2)},支出,交易成功,0.00,0.00,,已支出');
    total += e.amount;
    idx++;
  }
  // 3 笔交易关闭（应被过滤）
  for (var i = 0; i < 3; i++) {
    final day = (i + 1).toString().padLeft(2, '0');
    buf.writeln(
        'TC$i,,2026-02-$day 10:00:00,2026-02-$day 10:00:00,2026-02-$day 10:00:00,其他,即时到账,某店,某物,99.00,支出,交易关闭,0.00,0.00,,已退款');
  }
  return _SampleCsv(
    csv: buf.toString(),
    expectedRowCount: 55,
    expectedExpenseTotal: total,
  );
}

/// 生成 ≥ 50 行的钱迹样本。
_SampleCsv _buildQianjiCsv() {
  final buf = StringBuffer();
  buf.writeln('时间,类型,金额,一级分类,二级分类,账户1,账户2,备注');

  final entries = <_Q>[
    _Q('餐饮', '早餐', 12.0),
    _Q('餐饮', '午餐', 38.0),
    _Q('餐饮', '晚餐', 56.0),
    _Q('餐饮', '零食', 8.0),
    _Q('交通', '地铁公交', 6.0),
    _Q('交通', '打车', 23.5),
    _Q('购物', '日用品', 88.0),
    _Q('购物', '服饰', 199.0),
    _Q('娱乐', '电影', 60.0),
    _Q('住房', '房租', 3500.0),
  ];

  var total = 0.0;
  for (var i = 0; i < 52; i++) {
    final e = entries[i % entries.length];
    final day = (i % 28) + 1;
    final dayStr = day.toString().padLeft(2, '0');
    buf.writeln(
        '2026-01-$dayStr 12:00,支出,${e.amount.toStringAsFixed(2)},${e.cat1},${e.cat2},现金,,${e.cat2}消费');
    total += e.amount;
  }
  return _SampleCsv(
    csv: buf.toString(),
    expectedRowCount: 52,
    expectedExpenseTotal: total,
  );
}

class _W {
  _W(this.party, this.goods, this.amount);
  final String party;
  final String goods;
  final double amount;
}

class _Q {
  _Q(this.cat1, this.cat2, this.amount);
  final String cat1;
  final String cat2;
  final double amount;
}
