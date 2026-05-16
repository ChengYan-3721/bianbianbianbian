import 'dart:async';
import 'dart:io';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show SyncStatus, SyncState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bianbianbianbian/data/repository/providers.dart'
    show CurrentLedgerId, currentLedgerIdProvider;
import 'package:bianbianbianbian/features/sync/sync_provider.dart';
import 'package:bianbianbianbian/features/sync/sync_service.dart';
import 'package:bianbianbianbian/features/sync/sync_trigger.dart';

/// Step 10.7：SyncTrigger 单测覆盖三大不变量 + 防抖语义。
///
/// 这里**不**走真实的 cloud package 链——直接 override `syncServiceProvider`
/// 注入 fake，避免触达 SharedPreferences / 网络。
void main() {
  group('SyncTrigger.trigger', () {
    test('未配置云服务时返回 notConfigured，不抛异常', () async {
      final container = _container(service: const LocalOnlySyncService());
      addTearDown(container.dispose);

      final result = await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.notConfigured);
      final state = container.read(syncTriggerProvider);
      expect(state.isRunning, false);
      expect(state.isConfigured, false);
      expect(state.lastSyncedAt, isNull);
    });

    test('成功路径：upload + clearCache 被调用，state 写入 lastSyncedAt', () async {
      final fixedNow = DateTime.utc(2026, 5, 3, 12, 0);
      final fake = _FakeSyncService();
      final container = _container(
        service: fake,
        clock: () => fixedNow,
      );
      addTearDown(container.dispose);

      final result = await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.success);
      expect(fake.uploadedLedgerIds, ['ledger-test']);
      expect(fake.clearCacheCalls, 1);

      final state = container.read(syncTriggerProvider);
      expect(state.isRunning, false);
      expect(state.isConfigured, true);
      expect(state.lastSyncedAt, fixedNow);
      expect(state.lastError, isNull);
    });

    test('SocketException 归类为 networkUnavailable，并写入 lastError', () async {
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
      // 失败不写 lastSyncedAt
      expect(state.lastSyncedAt, isNull);
    });

    test('文本含 "TimeoutException" 也归类为 networkUnavailable', () async {
      final fake = _FakeSyncService(
        uploadError: TimeoutException('TimeoutException after 5s'),
      );
      final container = _container(service: fake);
      addTearDown(container.dispose);

      final result = await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.networkUnavailable);
    });

    test('普通 Exception 归类为 failure，message 透传', () async {
      final fake = _FakeSyncService(uploadError: Exception('401 unauthorized'));
      final container = _container(service: fake);
      addTearDown(container.dispose);

      final result = await container.read(syncTriggerProvider.notifier).trigger();
      expect(result.outcome, SyncTriggerOutcome.failure);
      expect(result.message, contains('401 unauthorized'));
      final state = container.read(syncTriggerProvider);
      expect(state.lastError, contains('401 unauthorized'));
    });

    test('前一次未完成时第二次调用直接返回 skipped', () async {
      final upload = Completer<void>();
      final fake = _FakeSyncService.controlled(upload);
      final container = _container(service: fake);
      addTearDown(container.dispose);

      final notifier = container.read(syncTriggerProvider.notifier);
      // 故意不 await：让第一次仍 in-flight
      final first = notifier.trigger();
      // 同一微任务里第二次调度：应被 _running 标记拦截
      final second = await notifier.trigger();
      expect(second.outcome, SyncTriggerOutcome.skipped);
      expect(fake.uploadedLedgerIds.length, 0); // 第一次还没结束

      // 放第一次走完，避免悬挂
      upload.complete();
      final firstResult = await first;
      expect(firstResult.outcome, SyncTriggerOutcome.success);
    });
  });

  group('SyncTrigger.scheduleDebounced', () {
    test('防抖窗口内重复调度只触发一次 upload', () async {
      fakeAsync(() async {
        final fake = _FakeSyncService();
        final container = _container(service: fake);
        addTearDown(container.dispose);

        final notifier = container.read(syncTriggerProvider.notifier);
        notifier.scheduleDebounced(delay: const Duration(seconds: 1));
        // 200ms 后再次调度——应重置 timer
        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.scheduleDebounced(delay: const Duration(seconds: 1));
        // 再 800ms 后第一个 timer 本应触发——但被重置应不触发
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(fake.uploadedLedgerIds.length, 0);
        // 再过 300ms 总计 1300ms，从最后一次调度算 1100ms → 第二个 timer 触发
        await Future<void>.delayed(const Duration(milliseconds: 400));
        // 等微任务把 trigger() 推到完成
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(fake.uploadedLedgerIds.length, 1);
      });
    });

    test('cancelTimers 取消未触发的防抖任务', () async {
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
}

// 注：避免引入 fake_async 依赖，第一个防抖测试改用 await Future.delayed 的真
// 实异步。`fakeAsync` 在这里是占位 wrapper——下面以普通函数实现。
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
}
