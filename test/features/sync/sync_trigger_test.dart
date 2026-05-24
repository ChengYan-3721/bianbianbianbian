import 'dart:async';
import 'dart:io';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show SyncStatus, SyncState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/data/local/app_database.dart';
import 'package:bianbianbianbian/data/repository/providers.dart'
    show CurrentLedgerId, currentLedgerIdProvider;
import 'package:bianbianbianbian/features/sync/incremental_sync_service.dart';
import 'package:bianbianbianbian/features/sync/sync_provider.dart';
import 'package:bianbianbianbian/features/sync/sync_service.dart';
import 'package:bianbianbianbian/features/sync/sync_trigger.dart';
import 'package:bianbianbianbian/features/sync/cloud_backup_discovery.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';
import 'package:drift/native.dart';

void main() {
  group('SyncTrigger.trigger', () {
    test('unconfigured returns notConfigured', () async {
      final container = _container(service: const LocalOnlySyncService());
      addTearDown(container.dispose);

      final result = await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.notConfigured);
      final state = container.read(syncTriggerProvider);
      expect(state.isRunning, false);
      expect(state.isConfigured, false);
      expect(state.lastSyncedAt, isNull);
    });

    test('SocketException → networkUnavailable', () async {
      final fake = _FakeSyncService(
        uploadError: const SocketException('Failed host lookup'),
      );
      final container = _container(service: fake);
      addTearDown(container.dispose);

      final result = await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.networkUnavailable);
      expect(result.message, '网络不可用');

      final state = container.read(syncTriggerProvider);
      expect(state.isRunning, false);
      expect(state.lastError, '网络不可用');
      expect(state.lastSyncedAt, isNull);
    });

    test('TimeoutException → networkUnavailable', () async {
      final fake = _FakeSyncService(
        uploadError: TimeoutException('TimeoutException after 5s'),
      );
      final container = _container(service: fake);
      addTearDown(container.dispose);

      final result = await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.networkUnavailable);
    });

    test('generic Exception → failure', () async {
      final fake = _FakeSyncService(uploadError: Exception('401 unauthorized'));
      final container = _container(service: fake);
      addTearDown(container.dispose);

      final result = await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.failure);
      expect(result.message, contains('401 unauthorized'));
      final state = container.read(syncTriggerProvider);
      expect(state.lastError, contains('401 unauthorized'));
    });

    test('concurrent triggers → skipped', () async {
      final upload = Completer<void>();
      final fake = _FakeSyncService.controlled(upload);
      final container = _container(service: fake);
      addTearDown(container.dispose);

      final notifier = container.read(syncTriggerProvider.notifier);
      final first = notifier.trigger();
      final second = await notifier.trigger();
      expect(second.outcome, SyncTriggerOutcome.skipped);
      expect(fake.uploadedLedgerIds.length, 0);

      upload.complete();
      final firstResult = await first;
      expect(firstResult.outcome, SyncTriggerOutcome.success);
    });
  });

  group('SyncTrigger.scheduleDebounced', () {
    test('debounce window fires once', () async {
      fakeAsync(() async {
        final fake = _FakeSyncService();
        final container = _container(service: fake);
        addTearDown(container.dispose);

        final notifier = container.read(syncTriggerProvider.notifier);
        notifier.scheduleDebounced(delay: const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.scheduleDebounced(delay: const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(fake.uploadedLedgerIds.length, 0);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(fake.uploadedLedgerIds.length, 1);
      });
    });

    test('cancelTimers prevents debounce', () async {
      final fake = _FakeSyncService();
      final container = _container(service: fake);
      addTearDown(container.dispose);

      final notifier = container.read(syncTriggerProvider.notifier);
      notifier.scheduleDebounced(delay: const Duration(milliseconds: 50));
      notifier.cancelTimers();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fake.uploadedLedgerIds.length, 0);
    });
  });

  group('SyncTrigger → IncrementalSyncService', () {
    late AppDatabase db;
    late _CountingGateway gateway;
    late IncrementalSyncService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      gateway = _CountingGateway();
      await db.into(db.userPrefTable).insert(
            UserPrefTableCompanion.insert(deviceId: 'device-self'),
          );
      service = IncrementalSyncService(
        gateway: gateway,
        db: db,
        deviceId: 'device-self',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('trigger() → pullThenPush', () async {
      final container = _container(service: service);
      addTearDown(container.dispose);

      final result =
          await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.success);
      expect(gateway.queryCalls, hasLength(5));
      expect(gateway.upsertCalls, isEmpty);
    });

    test('trigger(pushOnly: true) → no query', () async {
      final container = _container(service: service);
      addTearDown(container.dispose);

      final result = await container
          .read(syncTriggerProvider.notifier)
          .trigger(pushOnly: true);
      expect(result.outcome, SyncTriggerOutcome.success);
      expect(gateway.queryCalls, isEmpty);
      expect(gateway.upsertCalls, isEmpty);
    });

    test('scheduleDebounced → pushOnly', () async {
      final container = _container(service: service);
      addTearDown(container.dispose);

      container
          .read(syncTriggerProvider.notifier)
          .scheduleDebounced(delay: const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(gateway.queryCalls, isEmpty);
      expect(gateway.upsertCalls, isEmpty);
    });
  });
}

Future<void> fakeAsync(Future<void> Function() body) => body();

ProviderContainer _container({
  required SyncService service,
  SyncTriggerClock? clock,
}) {
  return ProviderContainer(
    overrides: [
      currentLedgerIdProvider
          .overrideWith(() => _FixedLedgerId('ledger-test')),
      syncServiceProvider.overrideWith((ref) async => service),
      if (clock != null)
        syncTriggerProvider.overrideWith(() => SyncTrigger(clock: clock)),
    ],
  );
}

class _FixedLedgerId extends CurrentLedgerId {
  _FixedLedgerId(this._id);
  final String _id;
  @override
  Future<String> build() async => _id;
}

class _FakeSyncService implements SyncService {
  _FakeSyncService({this.uploadError});

  factory _FakeSyncService.controlled(Completer<void> gate) {
    return _FakeSyncService._gated(gate);
  }

  _FakeSyncService._gated(this._gate);

  final List<String> uploadedLedgerIds = [];
  int clearCacheCalls = 0;
  Object? uploadError;
  Completer<void>? _gate;

  @override
  Future<void> upload({required String ledgerId}) async {
    if (_gate != null) await _gate!.future;
    if (uploadError != null) throw uploadError!;
    uploadedLedgerIds.add(ledgerId);
  }

  @override
  Future<int> downloadAndRestore({required String ledgerId}) async => 0;

  @override
  Future<void> deleteRemote({required String ledgerId}) async {}

  @override
  Future<List<RemoteBackup>> listBackups() async => const [];

  @override
  Future<String> restoreFromBackup(
    RemoteBackup backup, {
    LedgerNameConflictStrategy? conflictStrategy,
    String? renameTo,
  }) async =>
      throw UnimplementedError();

  @override
  Future<LedgerNameConflict?> checkLedgerNameConflict(String ledgerName) async =>
      null;

  @override
  Future<void> deleteBackupAt(String cloudPath) async {}

  @override
  void clearCache() {
    clearCacheCalls++;
  }

  @override
  Future<SyncStatus> getStatus({
    required String ledgerId,
    bool forceRefresh = false,
  }) async {
    return const SyncStatus(state: SyncState.unknown);
  }

  @override
  Future<void> forcePushAll() async {}

  @override
  Future<void> forcePullAll() async {}
}

class _CountingGateway implements IncrementalCloudGateway {
  final List<String> queryCalls = [];
  final List<String> upsertCalls = [];

  @override
  Future<void> upsertBatch({
    required String table,
    required List<Map<String, dynamic>> data,
  }) async {
    upsertCalls.add(table);
  }

  @override
  Future<void> deleteAll(String table) async {}

  @override
  Future<void> deleteBatch({
    required String table,
    required List<String> ids,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> queryUpdatedSince({
    required String table,
    required int updatedAtGt,
    required int limit,
    int offset = 0,
  }) async {
    queryCalls.add(table);
    return const [];
  }
}
