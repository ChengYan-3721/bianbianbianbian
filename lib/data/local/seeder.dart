import 'package:uuid/uuid.dart';

import '../../core/util/currencies.dart';
import 'app_database.dart';

/// [DefaultSeeder] 的 UUID / 时间注入点（测试里可替换成确定性实现）。
typedef SeedUuidFactory = String Function();
typedef SeedClock = DateTime Function();

/// 首次启动种子化器——在 `ledger` 表为空时**原子地**写入一组最小可用默认数据：
/// 1 个账本（📒 生活）、按固定一级分类映射的一组全局二级分类、5 个默认账户。
///
/// ## 幂等
/// 靠"ledger 表空"作为触发条件（实施计划 Step 1.7 硬性约束——不引入新列）。
/// 第二次调用看到非空 ledger 即整体跳过，不做增量补齐。这意味着用户手动删光
/// 账本（走垃圾桶然后硬删）**不会**被本 seeder "治愈"——Phase 4 的账本管理会
/// 保留至少一个默认账本，这里不越权兜底。
///
/// ## 非同步
/// 种子行**不**写入 `sync_op` 队列：开启云同步时若两台设备各自种了默认数据，
/// id 必然不同，会产生"两套 📒 生活"重复。真正的"首次同步 vs. 首次种子"
/// 顺序决定逻辑在 Phase 10 做——那时再加规则（例如：开启同步前就有种子数据
/// 则先 push 上云、后拉取；拉取后若本地已有同名账本则合并）。当下保持"种子是
/// 纯本地事务"。
///
/// ## 颜色分配
/// 分类色循环取自 design-document §10.2 奶油兔色板的 6 色（奶油黄 / 樱花粉 /
/// 可可棕 / 抹茶绿 / 蜜橘 / 苹果红）。索引 `i % 6` 保证相邻分类视觉上不重复；
/// 同 type 内部的顺序即用户在记账页分类网格看到的顺序。
class DefaultSeeder {
  DefaultSeeder({
    required AppDatabase db,
    required String deviceId,
    SeedClock? clock,
    SeedUuidFactory? uuidFactory,
  })  : _db = db,
        _deviceId = deviceId,
        _clock = clock ?? DateTime.now,
        _uuidFactory = uuidFactory ?? _defaultUuid;

  final AppDatabase _db;
  final String _deviceId;
  final SeedClock _clock;
  final SeedUuidFactory _uuidFactory;

  static String _defaultUuid() => const Uuid().v4();

  /// design-document §10.2 奶油兔 6 色板。分类索引 `i % 6` 循环取色。
  // i18n-exempt: seed data (color names are comments only, not UI text).
  static const List<String> palette = [
    '#FFE9B0', // 奶油黄
    '#FFB7C5', // 樱花粉
    '#8A5A3B', // 可可棕
    '#A8D8B9', // 抹茶绿
    '#F4A261', // 蜜橘
    '#E76F51', // 苹果红
  ];

  /// 固定一级分类键（不落库）下的默认二级分类（name + emoji）。
    ///
    /// 键集必须与 [CategoryTable.parentKey] 的 CHECK 约束保持一致。
    // i18n-exempt: seed data — names are DB values, not UI literals.
    static const Map<String, List<(String name, String emoji)>> categoriesByParent = {
      'income': [
        ('工资', '💰'),
        ('奖金', '🎉'),
        ('兼职', '👔'),
        ('投资收益', '📈'),
        ('理财收益', '💹'),
        ('报销', '🧾'),
        ('红包', '🧧'),
        ('退款', '↩️'),
        ('礼金', '💝'),
        ('其他收入', '💵'),
      ],
      'food': [
        ('早餐', '🥣'),
        ('午餐', '🍱'),
        ('晚餐', '🍲'),
        ('零食', '🍿'),
        ('饮料', '🧋'),
      ],
      'shopping': [
        ('日用品', '🧻'),
        ('服饰', '👕'),
        ('数码', '📱'),
        ('家居', '🛋️'),
        ('其他购物', '🛒'),
      ],
      'transport': [
        ('地铁公交', '🚇'),
        ('打车', '🚕'),
        ('加油', '⛽'),
        ('停车', '🅿️'),
        ('火车机票', '✈️'),
      ],
      'education': [
        ('书籍', '📚'),
        ('课程', '🧑‍🏫'),
        ('考试报名', '📝'),
        ('文具', '✏️'),
        ('其他教育', '🎒'),
      ],
      'entertainment': [
        ('电影', '🎬'),
        ('游戏', '🎮'),
        ('聚会', '🍻'),
        ('旅行娱乐', '🏖️'),
        ('其他娱乐', '🎉'),
      ],
      'social': [
        ('礼物', '🎁'),
        ('请客', '🍽️'),
        ('红包支出', '🧧'),
        ('随礼', '💌'),
        ('其他人情', '🤝'),
      ],
      'housing': [
        ('房租', '🏠'),
        ('水费', '🚿'),
        ('电费', '💡'),
        ('燃气', '🔥'),
        ('物业', '🧾'),
      ],
      'medical': [
        ('门诊', '🏥'),
        ('购药', '💊'),
        ('体检', '🩺'),
        ('治疗', '🛌'),
        ('其他医药', '🧪'),
      ],
      'investment': [
        ('基金', '📊'),
        ('股票', '📉'),
        ('债券', '🧾'),
        ('黄金', '🪙'),
        ('其他投资', '💼'),
      ],
      'other': [
        ('杂项', '🧩'),
        ('手续费', '💳'),
        ('捐赠', '🙏'),
        ('订阅', '🗂️'),
        ('其他', '💸'),
      ],
    };

  /// 5 个默认账户（名称 + 类型 + emoji）。
  // i18n-exempt: seed data — names are DB values, not UI literals.
  static const List<(String name, String type, String emoji)>
      defaultAccounts = [
    ('现金', 'cash', '💵'),
    ('工商银行卡', 'debit', '🏦'),
    ('招商信用卡', 'credit', '💳'),
    ('支付宝', 'third_party', '💰'),
    ('微信', 'third_party', '💬'),
  ];

  /// 如果 `ledger` 表当前非空（含软删的行）→ 整体跳过；否则在单事务内插入
  /// 账本 + 全部分类 + 全部账户。任一行失败整体回滚，不会留下半成品。
  ///
  /// fx_rate 工具表（Step 8.1）走**独立判空**——与 ledger 解耦：
  /// - 即使用户清空了 ledger 又重新种子化，fx_rate 不应被覆盖（用户可能
  ///   手动改过某币种汇率）。
  /// - schema v6 升级流程只 `createTable(fxRateTable)`，本机首次冷启动
  ///   到 v6 时由 seeder 把 [kFxRateSnapshot] 灌进去。
  Future<void> seedIfEmpty() async {
    await _db.transaction(() async {
      final anyLedger = await (_db.select(_db.ledgerTable)..limit(1)).get();
      if (anyLedger.isEmpty) {
        final nowMs = _clock().millisecondsSinceEpoch;
        final ledgerId = _uuidFactory();

        await _insertLedger(ledgerId, nowMs);
        await _insertCategories(nowMs);
        await _insertAccounts(nowMs);
      }

      final anyFxRate = await (_db.select(_db.fxRateTable)..limit(1)).get();
      if (anyFxRate.isEmpty) {
        final nowMs = _clock().millisecondsSinceEpoch;
        for (final entry in kFxRateSnapshot.entries) {
          await _db.into(_db.fxRateTable).insert(
                FxRateTableCompanion.insert(
                  code: entry.key,
                  rateToCny: entry.value,
                  updatedAt: nowMs,
                ),
              );
        }
      }
    });
  }

  Future<void> _insertLedger(String id, int nowMs) async {
    await _db.into(_db.ledgerTable).insert(
          LedgerTableCompanion.insert(
            id: id,
            // i18n-exempt: seed data — name is DB value, not UI literal.
            name: '生活',
            coverEmoji: const Value('📒'),
            createdAt: nowMs,
            updatedAt: nowMs,
            deviceId: _deviceId,
          ),
        );
  }

  Future<void> _insertCategories(int nowMs) async {
    for (final entry in categoriesByParent.entries) {
      final parentKey = entry.key;
      final items = entry.value;
      for (var i = 0; i < items.length; i++) {
        final (name, emoji) = items[i];
        await _db.into(_db.categoryTable).insert(
              CategoryTableCompanion.insert(
                id: _uuidFactory(),
                parentKey: parentKey,
                name: name,
                icon: Value(emoji),
                color: Value(palette[i % palette.length]),
                sortOrder: Value(i),
                isFavorite: const Value(0),
                updatedAt: nowMs,
                deviceId: _deviceId,
              ),
            );
      }
    }
  }

  Future<void> _insertAccounts(int nowMs) async {
    var index = 0;
    for (final (name, type, emoji) in defaultAccounts) {
      await _db.into(_db.accountTable).insert(
            AccountTableCompanion.insert(
              id: _uuidFactory(),
              name: name,
              type: type,
              icon: Value(emoji),
              color: Value(palette[index % palette.length]),
              updatedAt: nowMs,
              deviceId: _deviceId,
            ),
          );
      index++;
    }
  }
}
