import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n_ext.dart';
import '../features/budget/budget_providers.dart';
import '../features/ledger/ledger_list_page.dart';
import '../features/ledger/ledger_providers.dart';
import '../features/record/record_home_page.dart';
import '../features/stats/stats_page.dart';
import '../features/stats/stats_range_providers.dart';

// HomeShell 是整个应用的底部 Tab 外壳：记账 / 统计 / 账本 / 我的。
// 各 Tab 的 body 当前状态：
// - 记账：Step 3.1 RecordHomePage（含数据卡片 + 流水列表 + FAB）。
// - 统计：Step 5.2 StatsPage（时间区间 + 收支折线图）。
// - 账本：Step 4.1 LedgerListPage（正式卡片列表 + 切换 + 流水计数）。
// - 我的：Step 0.4 占位大标题，Phase 17 填充。
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  static void switchToRecordTab() {
    _HomeShellState.switchToRecordTab();
  }

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static _HomeShellState? _instance;

  int _currentIndex = 0;

  late final List<Widget> _pages = <Widget>[
    const RecordHomePage(),
    const StatsPage(),
    const LedgerListPage(),
    const _MeTab(),
  ];

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    if (identical(_instance, this)) {
      _instance = null;
    }
    super.dispose();
  }

  static void switchToRecordTab() {
    _instance?._switchToRecordTab();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.edit_note),
            label: context.l10n.tabRecord,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.pie_chart_outline),
            label: context.l10n.tabStats,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_outlined),
            label: context.l10n.tabLedger,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: context.l10n.tabMe,
          ),
        ],
      ),
    );
  }

  void _onTabTap(int i) {
    setState(() => _currentIndex = i);

    // 进入统计页时，主动刷新统计数据
    if (i == 1) {
      ref.invalidate(statsLinePointsProvider);
      ref.invalidate(statsPieSlicesProvider);
      ref.invalidate(statsRankItemsProvider);
      ref.invalidate(statsHeatmapCellsProvider);
      ref.invalidate(budgetProgressForProvider);
    }

    // 进入账本页时，主动刷新各账本流水条数
    if (i == 2) {
      ref.invalidate(ledgerTxCountsProvider);
    }
  }

  void _switchToRecordTab() {
    if (!mounted) return;
    setState(() => _currentIndex = 0);
  }
}

/// "我的" Tab——目前仅承载预算入口；Phase 17 会扩展为完整设置页。
class _MeTab extends StatelessWidget {
  const _MeTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tabMe)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.meAppearance),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(context.l10n.meReminder),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/reminder'),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: Text(context.l10n.meBudget),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/budget'),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(context.l10n.meAssets),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/accounts'),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(context.l10n.meMultiCurrency),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/multi-currency'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: Text(context.l10n.meAiInput),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ai-input'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: Text(context.l10n.meCloudService),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/sync'),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(context.l10n.meAttachmentCache),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/attachment-cache'),
          ),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: Text(context.l10n.meImportExport),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/import-export'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(context.l10n.meAppLock),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/app-lock'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(context.l10n.meTrash),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/trash'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.meAbout),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }
}
