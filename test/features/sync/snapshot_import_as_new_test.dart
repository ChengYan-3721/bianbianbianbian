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
/// - ledger 拿到 uuidFactory() 的第 1 个 UUID;
/// - 每条 transaction 拿到独立的 UUID(后续 UUID);
/// - 每条 budget 拿到独立的 UUID;
/// - 所有 transaction.ledgerId / budget.ledgerId 重映射到新 ledger UUID;
/// - categories / accounts 仍按原 id upsert(全局共享,不动);
/// - 同一个备份导入两次产生两个相互独立的 ledger。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('ledger / tx / budget 全部分配新 UUID,且 ledgerId 重映射一致', () async {
    final snap = _snapshotWith(
      ledgerId: 'cloud-L',
      ledgerName: '云端账本',
      txIds: const ['cloud-tx-1', 'cloud-tx-2'],
      budgetIds: const ['cloud-b-1'],
    );
    final factory = _UuidCounter(['new-L', 'new-tx-A', 'new-tx-B', 'new-b-A']);

    final newId = await importLedgerSnapshotAsNew(
      snapshot: snap,
      db: db,
      uuidFactory: factory.next,
    );

    expect(newId, 'new-L');

    final ledgers = await db.select(db.ledgerTable).get();
    expect(ledgers.map((l) => l.id), ['new-L']);
    expect(ledgers.single.name, '云端账本');

    final txs = await db.select(db.transactionEntryTable).get();
    expect(txs.map((t) => t.id).toSet(), {'new-tx-A', 'new-tx-B'});
    expect(txs.every((t) => t.ledgerId == 'new-L'), isTrue);

    final budgets = await db.select(db.budgetTable).get();
    expect(budgets.map((b) => b.id), ['new-b-A']);
    expect(budgets.single.ledgerId, 'new-L');
  });

  test('categories / accounts 仍按原 id upsert,可与已有共享', () async {
    final snap = _snapshotWith(
      ledgerId: 'cloud-L',
      categoryIds: const ['food', 'transport'],
      accountIds: const ['cash', 'card'],
    );
    final factory = _UuidCounter(['new-L']);

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

  test('同一个 snapshot 导入两次产生两个独立 ledger 与各自 txs', () async {
    final snap = _snapshotWith(
      ledgerId: 'cloud-L',
      txIds: const ['cloud-tx-1'],
    );

    final f1 = _UuidCounter(['L-a', 'tx-a']);
    final id1 = await importLedgerSnapshotAsNew(
      snapshot: snap,
      db: db,
      uuidFactory: f1.next,
    );
    final f2 = _UuidCounter(['L-b', 'tx-b']);
    final id2 = await importLedgerSnapshotAsNew(
      snapshot: snap,
      db: db,
      uuidFactory: f2.next,
    );

    expect(id1, 'L-a');
    expect(id2, 'L-b');

    final ledgers = await db.select(db.ledgerTable).get();
    expect(ledgers.map((l) => l.id).toSet(), {'L-a', 'L-b'});

    final txs = await db.select(db.transactionEntryTable).get();
    expect(txs.map((t) => t.id).toSet(), {'tx-a', 'tx-b'});
    expect(txs.where((t) => t.ledgerId == 'L-a').length, 1);
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
