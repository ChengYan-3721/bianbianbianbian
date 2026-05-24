import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../data/local/app_database.dart';
import '../../data/repository/entity_mappers.dart';
import '../../data/repository/repo_clock.dart';
import '../../domain/entity/account.dart';
import '../../domain/entity/transaction_entry.dart';

class AccountSaveService {
  AccountSaveService({
    required AppDatabase db,
    required String deviceId,
    RepoClock clock = DateTime.now,
    Uuid? uuid,
  }) : _db = db,
       _deviceId = deviceId,
       _clock = clock,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final String _deviceId;
  final RepoClock _clock;
  final Uuid _uuid;

  Future<Account> save({
    required Account account,
    required String ledgerId,
    required double oldBalance,
    required double newBalance,
    required String adjustmentNote,
  }) async {
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;
    final stamped = account.copyWith(updatedAt: now, deviceId: _deviceId);
    final delta = _normalizeAmount(newBalance - oldBalance);

    await _db.transaction(() async {
      await _db.accountDao.upsert(accountToCompanion(stamped));
      await _db.syncOpDao.enqueue(
        entity: 'account',
        entityId: stamped.id,
        op: 'upsert',
        payload: jsonEncode(stamped.toJson()),
        enqueuedAt: nowMs,
      );

      if (delta == 0) return;

      final adjustment = TransactionEntry(
        id: _uuid.v4(),
        ledgerId: ledgerId,
        type: delta > 0 ? 'income' : 'expense',
        amount: delta.abs(),
        currency: stamped.currency,
        categoryId: null,
        accountId: stamped.id,
        toAccountId: null,
        occurredAt: now,
        tags: adjustmentNote,
        updatedAt: now,
        deviceId: _deviceId,
      );
      await _db.transactionEntryDao.upsert(
        transactionEntryToCompanion(adjustment),
      );
      await _db.syncOpDao.enqueue(
        entity: 'transaction',
        entityId: adjustment.id,
        op: 'upsert',
        payload: jsonEncode(adjustment.toJson()),
        enqueuedAt: nowMs,
      );
    });

    return stamped;
  }

  double _normalizeAmount(double value) {
    final cents = (value * 100).round();
    if (cents == 0) return 0;
    return cents / 100;
  }
}
