import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  static const List<_HomeTab> _tabs = [
    _HomeTab(label: '记账', icon: Icons.edit_note),
    _HomeTab(label: '统计', icon: Icons.pie_chart_outline),
    _HomeTab(label: '账本', icon: Icons.menu_book_outlined),
    _HomeTab(label: '我的', icon: Icons.person_outline),
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
          for (final tab in _tabs)
            BottomNavigationBarItem(
              icon: Icon(tab.icon),
              label: tab.label,
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
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('外观'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('提醒'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/reminder'),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('预算'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/budget'),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('资产'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/accounts'),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('多币种'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/multi-currency'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('快速输入 · AI 增强'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ai-input'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('云服务'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/sync'),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('附件缓存'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/attachment-cache'),
          ),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('导入 / 导出'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/import-export'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('应用锁'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/app-lock'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('垃圾桶'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/trash'),
          ),
        ],
      ),
    );
  }
}

class _HomeTab {
  const _HomeTab({required this.label, required this.icon});
  final String label;
  final IconData icon;
}