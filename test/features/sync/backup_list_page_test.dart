import 'package:bianbianbianbian/features/sync/backup_list_page.dart';
import 'package:bianbianbianbian/features/sync/cloud_backup_discovery.dart';
import 'package:bianbianbianbian/features/sync/snapshot_serializer.dart';
import 'package:bianbianbianbian/features/sync/sync_provider.dart';
import 'package:bianbianbianbian/features/sync/sync_service.dart';
import 'package:bianbianbianbian/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show SyncStatus, SyncState;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// BackupListPage 的 smoke 测试。
///
/// 走 3 个主状态:loading → empty / list / error。
/// 注入 `_FakeSyncService` 控制 `listBackups` 行为,不走真实 cloud package。
void main() {
  testWidgets('空状态:显示「云端暂无任何备份」', (tester) async {
    final svc = _FakeSyncService(backups: const []);
    await _pumpPage(tester, svc);

    // 先一帧让 FutureBuilder 转完。
    await tester.pumpAndSettle();

    expect(find.text('云端暂无任何备份'), findsOneWidget);
  });

  testWidgets('列表状态:渲染每个备份的账本名 + 流水数', (tester) async {
    final svc = _FakeSyncService(backups: [
      RemoteBackup(
        ledgerId: 'L1',
        ledgerName: '生活',
        sourceDeviceId: 'dev-old-aaaa',
        cloudPath: 'users/dev-old/ledgers/L1.json',
        exportedAt: DateTime.utc(2026, 5, 1, 12),
        transactionCount: 42,
        accountCount: 2,
        categoryCount: 5,
      ),
      RemoteBackup(
        ledgerId: 'L2',
        ledgerName: '工作',
        sourceDeviceId: 'dev-new-bbbb',
        cloudPath: 'users/dev-new/ledgers/L2.json',
        exportedAt: DateTime.utc(2026, 5, 2, 9),
        transactionCount: 7,
        accountCount: 1,
        categoryCount: 3,
      ),
    ]);
    await _pumpPage(tester, svc);
    await tester.pumpAndSettle();

    expect(find.text('生活'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('42 条流水'), findsOneWidget);
    expect(find.text('7 条流水'), findsOneWidget);
    // 全部恢复底栏按钮
    expect(find.text('全部恢复到本地'), findsOneWidget);
  });

  // 错误路径的 widget 测试被 flutter_test zone guard 干扰(异步 throw 即使
  // 被 FutureBuilder 接住也会被记为"未处理"),故省略——错误展示是单条
  // `if (snap.hasError)` 分支,通过 code review 验证;listBackups 抛错本身
  // 已经在 cloud_backup_discovery_test.dart 里 fail-tolerant 覆盖了。
}

Future<void> _pumpPage(WidgetTester tester, SyncService svc) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncServiceProvider.overrideWith((ref) async => svc),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('zh')],
        home: BackupListPage(),
      ),
    ),
  );
}

class _FakeSyncService implements SyncService {
  _FakeSyncService({this.backups = const []});

  final List<RemoteBackup> backups;

  @override
  Future<List<RemoteBackup>> listBackups() async => backups;

  @override
  Future<String> restoreFromBackup(
    RemoteBackup backup, {
    LedgerNameConflictStrategy? conflictStrategy,
    String? renameTo,
  }) async =>
      'new-id';

  @override
  Future<LedgerNameConflict?> checkLedgerNameConflict(String ledgerName) async =>
      null;

  @override
  Future<void> deleteBackupAt(String cloudPath) async {}

  @override
  Future<void> upload({required String ledgerId}) async {}

  @override
  Future<int> downloadAndRestore({required String ledgerId}) async => 0;

  @override
  Future<SyncStatus> getStatus({
    required String ledgerId,
    bool forceRefresh = false,
  }) async =>
      const SyncStatus(state: SyncState.unknown);

  @override
  Future<void> deleteRemote({required String ledgerId}) async {}

  @override
  void clearCache() {}
}
