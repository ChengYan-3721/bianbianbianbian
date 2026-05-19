import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/budget.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 覆盖 [importLedgerSnapshotAsNew]:把云端快照作为"新账本"导入,
/// 不与本地现有账本同 id 冲突。
///
/// 关键不变量:
/// - ledger:**优先保留原始 id**——仅当本地已存在同名活跃账本时才生成新 UUID;
/// - 每条 transaction 拿到独立的 UUID(后续 UUID);
/// - 每条 budget 拿到独立的 UUID;
/// - 所有 transaction.ledgerId / budget.ledgerId 重映射到最终 ledger UUID;
/// - categories / accounts 仍按原 id upsert(全局共享,不动);
/// - 同一个备份导入两次:第一次保留原始 id,第二次检测到冲突后生成新 UUID。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('无冲突时保留原始 ledgerId,tx/budget 分配新 UUID 且 ledgerId 重映射一致', () async {
    final snap = _snapshotWith(
      ledgerId: 'cloud-L',
      ledgerName: '云端账本',
      txIds: const ['cloud-tx-1', 'cloud-tx-2'],
      budgetIds: const ['cloud-b-1'],
    );
    // uuidFactory 的第 1 个 UUID 留给 ledger(仅冲突时使用),此处无冲突故保留原始 id。
    // tx 和 budget 各需独立 UUID。
    final factory = _UuidCounter(['new-tx-A', 'new-tx-B', 'new-b-A']);

    final newId = await importLedgerSnapshotAsNew(
      snapshot: snap,
      db: db,
      uuidFactory: factory.next,
    );

    // 无冲突 → 保留原始 ledgerId
    expect(newId, 'cloud-L');

    final ledgers = await db.select(db.ledgerTable).get();
    expect(ledgers.map((l) => l.id), ['cloud-L']);
    expect(ledgers.single.name, '云端账本');

    final txs = await db.select(db.transactionEntryTable).get();
    expect(txs.map((t) => t.id).toSet(), {'new-tx-A', 'new-tx-B'});
    expect(txs.every((t) => t.ledgerId == 'cloud-L'), isTrue);

    final budgets = await db.select(db.budgetTable).get();
    expect(budgets.map((b) => b.id), ['new-b-A']);
    expect(budgets.single.ledgerId, 'cloud-L');
  });

  test('categories / accounts 仍按原 id upsert,可与已有共享', () async {
    final snap = _snapshotWith(
      ledgerId: 'cloud-L',
      categoryIds: const ['food', 'transport'],
      accountIds: const ['cash', 'card'],
    );
    // 无冲突 → ledgerId 保留原始值,不需要 uuidFactory 提供 ledger UUID
    final factory = _UuidCounter(<String>[]);

    await importLedgerSnapshotAsNew(
      snapshot: snap,
      db: db,
      uuidFactory: factory.next,
    );

    final cats = await db.select(db.categoryTable).get();
    expect(cats.map((c) => c.id).toSet(), {'food', 'transport'});

    final accts = await db.select(db.accountTable).get();
    expect(accts.map((a) => a.id).toSet(), {'cash', 'card'});
  });

  test('同一个 snapshot 导入两次:第一次保留原始 id,第二次冲突后生成新 UUID', () async {
    final snap = _snapshotWith(
      ledgerId: 'cloud-L',
      txIds: const ['cloud-tx-1'],
    );

    // 第一次导入:无冲突 → 保留原始 ledgerId 'cloud-L'
    final f1 = _UuidCounter(['tx-a']);
    final id1 = await importLedgerSnapshotAsNew(
      snapshot: snap,
      db: db,
      uuidFactory: f1.next,
    );
    // 第二次导入:同名活跃账本 'cloud-L' 已存在 → 冲突 → 生成新 UUID。
    // uuidFactory 调用顺序:先为 tx 分配 UUID(事务外),再为 ledger 分配(事务内冲突时)。
    final f2 = _UuidCounter(['tx-b', 'L-b']);
    final id2 = await importLedgerSnapshotAsNew(
      snapshot: snap,
      db: db,
      uuidFactory: f2.next,
    );

    expect(id1, 'cloud-L');
    expect(id2, 'L-b');

    final ledgers = await db.select(db.ledgerTable).get();
    expect(ledgers.map((l) => l.id).toSet(), {'cloud-L', 'L-b'});

    final txs = await db.select(db.transactionEntryTable).get();
    expect(txs.map((t) => t.id).toSet(), {'tx-a', 'tx-b'});
    expect(txs.where((t) => t.ledgerId == 'cloud-L').length, 1);
    expect(txs.where((t) => t.ledgerId == 'L-b').length, 1);
  });
}

// ---- 测试夹具 ----------------------------------------------------------------

const _devId = 'test-dev';
final _t0 = DateTime.utc(2026, 5, 1, 12);

class _UuidCounter {
  _UuidCounter(this._values);
  final List<String> _values;
  int _i = 0;
  String next() {
    if (_i >= _values.length) {
      throw StateError('UuidCounter exhausted; provide more values');
    }
    return _values[_i++];
  }
}

Ledger _ledger(String id, String name) => Ledger(
      id: id,
      name: name,
      createdAt: _t0,
      updatedAt: _t0,
      deviceId: _devId,
    );

Category _category(String id) => Category(
      id: id,
      name: id,
      parentKey: 'food',
      updatedAt: _t0,
      deviceId: _devId,
    );

Account _account(String id) => Account(
      id: id,
      name: id,
      type: 'cash',
      updatedAt: _t0,
      deviceId: _devId,
    );

TransactionEntry _tx(String id, String ledgerId) => TransactionEntry(
      id: id,
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10,
      currency: 'CNY',
      occurredAt: _t0,
      updatedAt: _t0,
      deviceId: _devId,
    );

Budget _budget(String id, String ledgerId) => Budget(
      id: id,
      ledgerId: ledgerId,
      period: 'monthly',
      amount: 1000,
      startDate: _t0,
      updatedAt: _t0,
      deviceId: _devId,
    );

LedgerSnapshot _snapshotWith({
  String ledgerId = 'L',
  String ledgerName = '账本',
  List<String> txIds = const [],
  List<String> budgetIds = const [],
  List<String> categoryIds = const ['food'],
  List<String> accountIds = const ['cash'],
}) =>
    LedgerSnapshot(
      version: LedgerSnapshot.kVersion,
      exportedAt: _t0,
      deviceId: _devId,
      ledger: _ledger(ledgerId, ledgerName),
      categories: categoryIds.map(_category).toList(),
      accounts: accountIds.map(_account).toList(),
      transactions: txIds.map((id) => _tx(id, ledgerId)).toList(),
      budgets: budgetIds.map((id) => _budget(id, ledgerId)).toList(),
    );
