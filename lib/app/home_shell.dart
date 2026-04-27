import 'package:flutter/material.dart';

import '../features/ledger/ledger_list_page.dart';
import '../features/record/record_home_page.dart';

// HomeShell 是整个应用的底部 Tab 外壳：记账 / 统计 / 账本 / 我的。
// 各 Tab 的 body 当前状态：
// - 记账：Step 3.1 RecordHomePage（含数据卡片 + 流水列表 + FAB）。
// - 统计：Step 0.4 占位大标题，Phase 5 填充。
// - 账本：Step 4.1 LedgerListPage（正式卡片列表 + 切换 + 流水计数）。
// - 我的：Step 0.4 占位大标题，Phase 17 填充。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages = <Widget>[
    const RecordHomePage(),
    const _PlaceholderTab(label: '统计'),
    const LedgerListPage(),
    const _PlaceholderTab(label: '我的'),
  ];

  static const List<_HomeTab> _tabs = [
    _HomeTab(label: '记账', icon: Icons.edit_note),
    _HomeTab(label: '统计', icon: Icons.pie_chart_outline),
    _HomeTab(label: '账本', icon: Icons.menu_book_outlined),
    _HomeTab(label: '我的', icon: Icons.person_outline),
  ];

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
        onTap: (i) => setState(() => _currentIndex = i),
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

}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}

class _HomeTab {
  const _HomeTab({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
