import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;

import 'attachment_meta_codec.dart';
import 'dao/account_dao.dart';
import 'dao/budget_dao.dart';
import 'dao/category_dao.dart';
import 'dao/fx_rate_dao.dart';
import 'dao/ledger_dao.dart';
import 'dao/sync_op_dao.dart';
import 'dao/transaction_entry_dao.dart';
import 'db_cipher_key_store.dart';
import 'tables/account_table.dart';
import 'tables/budget_table.dart';
import 'tables/category_table.dart';
import 'tables/fx_rate_table.dart';
import 'tables/ledger_table.dart';
import 'tables/sync_op_table.dart';
import 'tables/transaction_entry_table.dart';
import 'tables/user_pref_table.dart';

export 'package:drift/drift.dart' show Value;

part 'app_database.g.dart';

/// 应用本地 drift 数据库。
///
/// 生产构造 `AppDatabase()` 走 SQLCipher 加密打开（Step 1.2）——密钥由
/// [DbCipherKeyStore] 从 `flutter_secure_storage` 读取/首建，以 hex 形式注入
/// `PRAGMA key = "x'<hex>'"`（跳过 SQLCipher 内部 KDF，因为我们的密钥已经
/// 是 `Random.secure()` 产出的 32 字节）。
///
/// 测试构造 `AppDatabase.forTesting(NativeDatabase.memory())` 保留不变——
/// 单元测试只验 schema / CRUD 行为，不复现加密层；SQLCipher 的真实加密效果
/// 需要设备级手工验证（见 memory-bank/progress.md Step 1.2 条目）。
///
/// ### Schema 版本历史
/// - v1（Step 1.1）：仅 `user_pref`。
/// - v2（Step 1.3）：新增 `ledger` / `category` / `account` / `transaction_entry`
///   / `budget` / `sync_op` 六张业务表 + `transaction_entry` 两个索引
///   （`idx_tx_ledger_time`、`idx_tx_updated`）。
/// - v3（Step 3.2 重构）：`category` 改为“全局二级分类”模型（新增 `parent_key`
///   / `is_favorite`，移除 `ledger_id` / `type`），按需求“不兼容旧结构”直接重建表。
/// - v4（Step 6.4）：`budget` 追加 `carry_balance REAL NOT NULL DEFAULT 0` 与
///   `last_settled_at INTEGER`（nullable），用于预算结转的累加值与结算 anchor。
/// - v5（Step 7.3）：`account` 追加 `billing_day INTEGER` 与
///   `repayment_day INTEGER`（均 nullable），用于信用卡账单日 / 还款日展示。
/// - v6（Step 8.1）：`user_pref` 追加 `multi_currency_enabled INTEGER DEFAULT 0`；
///   新增工具表 `fx_rate(code PK, rate_to_cny REAL, updated_at INTEGER)`。
/// - v7（Step 8.3）：`fx_rate` 追加 `is_manual INTEGER NOT NULL DEFAULT 0`
///   （手动覆盖标记，自动刷新跳过）；`user_pref` 追加 `last_fx_refresh_at
///   INTEGER`（上次自动刷新时间，每日节流锚点）。
/// - v8（Step 9.3）：`user_pref` 追加 `ai_api_model TEXT` /
///   `ai_api_prompt_template TEXT` / `ai_input_enabled INTEGER DEFAULT 0`。
///   `ai_api_endpoint` 与 `ai_api_key_encrypted` 是历史遗留列（自 v1 即声明
///   但未使用），Step 9.3 起被消费，无需迁移。
/// - v9（Step 11.2）：`transaction_entry.attachments_encrypted` BLOB 内 JSON
///   shape 升级——从 Step 3.5 的 `["<本地路径>", ...]` 字符串数组改为含
///   `remote_key / sha256 / size / original_name / mime / local_path` 的
///   `AttachmentMeta` 对象数组（详见 [AttachmentMetaCodec] / [AttachmentMeta]）。
///   不增列、不改列类型、不重命名（列名 `attachments_encrypted` 是历史遗留，
///   v1 设计为 AES-GCM 密文，现 V1 同步策略下内容明文）。迁移就地扫表 + 转换
///   BLOB；本地文件不存在的旧记录标记 `missing: true`，UI 显示占位。
///
/// > **plan 文档差异说明**：implementation-plan.md §11.2 写的是「v9 → v10」，
/// > 是因为 plan 起草时假设 Phase 9（AI 增强）会同时铺一个独立的 schema
/// > version；实际落地中 Phase 9 与现有 v8 复用了 user_pref 列，schema
/// > 没动。所以本步真实跨度是 v8 → v9，语义与 plan 完全一致，只是版本号
/// > 序列连续少一格。后续 Phase 文档勘误时统一以代码为准。
@DriftDatabase(
  tables: [
    UserPrefTable,
    LedgerTable,
    CategoryTable,
    AccountTable,
    TransactionEntryTable,
    BudgetTable,
    SyncOpTable,
    FxRateTable,
  ],
  daos: [
    LedgerDao,
    CategoryDao,
    AccountDao,
    TransactionEntryDao,
    BudgetDao,
    SyncOpDao,
    FxRateDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openEncrypted());

  /// 仅单元测试使用：传入 `NativeDatabase.memory()` 即可完全内存化。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // v2 空库首次创建：`createAll` 会依据 `@DriftDatabase` 声明一次性
          // 建好所有表；索引走手写 SQL（保留 §7.1 的 DESC 方向，drift 的
          // `@TableIndex` 注解不支持排序方向）。
          await m.createAll();
          await _createTransactionIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2：追加 6 张业务表 + 2 个索引，`user_pref` 原样保留。
            await m.createTable(ledgerTable);
            await m.createTable(categoryTable);
            await m.createTable(accountTable);
            await m.createTable(transactionEntryTable);
            await m.createTable(budgetTable);
            await m.createTable(syncOpTable);
            await _createTransactionIndexes();
          }

          if (from < 3) {
            // v2 → v3：按产品要求“无需兼容旧 category 结构”，直接重建 category。
            await m.deleteTable('category');
            await m.createTable(categoryTable);
          }

          if (from < 4) {
            // v3 → v4：budget 表追加 carry_balance / last_settled_at 两列，
            // 历史记录默认结转余额 0、未结算（lastSettledAt = NULL）。
            await m.addColumn(budgetTable, budgetTable.carryBalance);
            await m.addColumn(budgetTable, budgetTable.lastSettledAt);
          }

          if (from < 5) {
            // v4 → v5：account 表追加 billing_day / repayment_day 两列，
            // 历史记录默认 NULL；非信用卡账户也允许保持 NULL。
            await m.addColumn(accountTable, accountTable.billingDay);
            await m.addColumn(accountTable, accountTable.repaymentDay);
          }

          if (from < 6) {
            // v5 → v6：user_pref 追加 multi_currency_enabled 列（默认 0
            // = 关闭，与新装行为一致）；新增工具表 fx_rate。fx_rate 的
            // 初始快照不在 onUpgrade 写入——下次冷启动 seeder 会按
            // "fx_rate 表为空"独立判空补齐，与 ledger 种子化逻辑解耦。
            await m.addColumn(
              userPrefTable,
              userPrefTable.multiCurrencyEnabled,
            );
            await m.createTable(fxRateTable);
          }

          if (from < 7) {
            // v6 → v7：fx_rate 追加 is_manual 列（默认 0 = 自动管理，可被
            // 自动刷新覆盖）；user_pref 追加 last_fx_refresh_at（每日刷新
            // 节流锚点；NULL = 从未刷新）。
            await m.addColumn(fxRateTable, fxRateTable.isManual);
            await m.addColumn(
              userPrefTable,
              userPrefTable.lastFxRefreshAt,
            );
          }

          if (from < 8) {
            // v7 → v8：user_pref 追加 AI 增强配置 3 列。`ai_api_endpoint`
            // / `ai_api_key_encrypted` 自 v1 即声明，无需迁移。`ai_input_enabled`
            // 默认 0（关闭，与新装行为一致）；`ai_api_model` /
            // `ai_api_prompt_template` 默认 NULL，UI 配置页保存时按用户填
            // 写值写入，未填走 [kDefaultAiInputPromptTemplate] 兜底。
            await m.addColumn(userPrefTable, userPrefTable.aiApiModel);
            await m.addColumn(
              userPrefTable,
              userPrefTable.aiApiPromptTemplate,
            );
            await m.addColumn(userPrefTable, userPrefTable.aiInputEnabled);
          }

          if (from < 9) {
            // v8 → v9（Step 11.2）：transaction_entry.attachments_encrypted
            // BLOB 内 JSON shape 从字符串数组升级为 AttachmentMeta 对象数组。
            // 不动 schema，纯数据迁移：扫所有非空 BLOB → 解码旧 shape →
            // 包装成新对象数组（remote_key / sha256 留 null 等下次同步回填，
            // size / mime 现场推断，本地文件不存在的标记 missing: true）→
            // 写回原行。
            await _upgradeAttachmentsBlobToV9();
          }
        },
      );

  /// v8 → v9 迁移的具体实现，抽出方法便于阅读 + 单测注入。
  ///
  /// 直接走 [customSelect] / [customStatement]——不走 DAO/companion 因为：
  /// ① drift 数据类已经是 v9 形态，旧 shape 用不上；② 迁移路径要尽量稳定，
  /// 不依赖业务层；③ 减少代码生成耦合（drift schema 改动时不连带影响迁移）。
  Future<void> _upgradeAttachmentsBlobToV9() async {
    final rows = await customSelect(
      "SELECT id, attachments_encrypted FROM transaction_entry "
      'WHERE attachments_encrypted IS NOT NULL',
    ).get();

    final inputs = <({String id, Uint8List blob})>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      final blob = row.read<Uint8List>('attachments_encrypted');
      if (blob.isEmpty) continue;
      inputs.add((id: id, blob: blob));
    }

    final outputs = migrateAttachmentsBlobV8ToV9(
      inputs,
      readFileLength: (path) {
        try {
          final f = File(path);
          if (!f.existsSync()) return null;
          return f.lengthSync();
        } catch (_) {
          return null;
        }
      },
    );

    for (final out in outputs) {
      await customStatement(
        'UPDATE transaction_entry SET attachments_encrypted = ? WHERE id = ?',
        [out.newBlob, out.id],
      );
    }
  }

  Future<void> _createTransactionIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_ledger_time '
      'ON transaction_entry(ledger_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_updated '
      'ON transaction_entry(updated_at)',
    );
  }
}

/// 移除 `sqlite3_flutter_libs` 之后，`package:sqlite3` 在 Android 上仍默认
/// 试图 `DynamicLibrary.open('libsqlite3.so')`——那个 .so 不在 APK 里，会
/// 静默失败。必须把加载器指到 `sqlcipher_flutter_libs` 的 `libsqlcipher.so`。
/// 必须在主 isolate **和** drift 的后台 isolate 里各调一次（后台 isolate
/// 是实际执行 `sqlite3.open` 的地方；主 isolate 调是 belt-and-suspenders，
/// 以防后续有其他 sqlite3 使用方）。
void _registerSqlCipherLoader() {
  if (Platform.isAndroid) {
    sqlite3_open.open
        .overrideFor(sqlite3_open.OperatingSystem.android, openCipherOnAndroid);
  }
  // iOS 走 static link，sqlcipher_flutter_libs 的 pod 已经把符号并入主二进制，
  // sqlite3 包用 `DynamicLibrary.process()` 就能找到，无需 override。
}

LazyDatabase _openEncrypted() {
  return LazyDatabase(() async {
    // 主 isolate 侧：老 Android 设备 (<6.0) 装载 SQLCipher 的已知 workaround。
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    _registerSqlCipherLoader();

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'bbb.db'));
    final cipherKeyHex = await DbCipherKeyStore().loadOrCreate();

    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () async {
        // 后台 isolate 侧：同样需要 workaround + 加载器注入，因为实际的
        // sqlite3.open 发生在这里。
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
        _registerSqlCipherLoader();
      },
      setup: (rawDb) {
        // `x'<hex>'` 语法让 SQLCipher 直接取 hex 串解码出的原始 32 字节作为密钥，
        // 不再跑自带的 PBKDF2；随机来源已是 Random.secure()。
        rawDb.execute("PRAGMA key = \"x'$cipherKeyHex'\";");
        // 断言 SQLCipher 真的加载了；否则 `PRAGMA cipher_version` 返回空结果集
        // —— 说明 runtime 链接到了普通 sqlite3，这会让数据"看似加密"实际明文落盘。
        final cipher = rawDb.select('PRAGMA cipher_version;');
        if (cipher.isEmpty) {
          throw StateError(
            'SQLCipher runtime not available: make sure sqlcipher_flutter_libs '
            'is bundled and sqlite3_flutter_libs is NOT also present.',
          );
        }
      },
    );
  });
}
