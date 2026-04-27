import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;

import 'dao/account_dao.dart';
import 'dao/budget_dao.dart';
import 'dao/category_dao.dart';
import 'dao/ledger_dao.dart';
import 'dao/sync_op_dao.dart';
import 'dao/transaction_entry_dao.dart';
import 'db_cipher_key_store.dart';
import 'tables/account_table.dart';
import 'tables/budget_table.dart';
import 'tables/category_table.dart';
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
@DriftDatabase(
  tables: [
    UserPrefTable,
    LedgerTable,
    CategoryTable,
    AccountTable,
    TransactionEntryTable,
    BudgetTable,
    SyncOpTable,
  ],
  daos: [
    LedgerDao,
    CategoryDao,
    AccountDao,
    TransactionEntryDao,
    BudgetDao,
    SyncOpDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openEncrypted());

  /// 仅单元测试使用：传入 `NativeDatabase.memory()` 即可完全内存化。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

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
        },
      );

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
