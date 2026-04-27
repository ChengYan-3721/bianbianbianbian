import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/local/providers.dart';

part 'ledger_providers.g.dart';

/// 各账本的活跃流水条数——供账本列表展示"流水总数"。
@Riverpod(keepAlive: true)
class LedgerTxCounts extends _$LedgerTxCounts {
  @override
  Future<Map<String, int>> build() async {
    final db = ref.watch(appDatabaseProvider);
    await ref.watch(defaultSeedProvider.future);
    final ledgers = await db.ledgerDao.listActive();
    final result = <String, int>{};
    for (final l in ledgers) {
      result[l.id] = await db.transactionEntryDao.countActiveByLedger(l.id);
    }
    return result;
  }

  /// 某账本写入 / 删除流水后，只刷新该账本的计数（全量重建）。
  void invalidate() => ref.invalidateSelf();
}
