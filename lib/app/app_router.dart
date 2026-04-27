import 'package:go_router/go_router.dart';

import '../features/ledger/ledger_edit_page.dart';
import '../features/record/category_manage_page.dart';
import '../features/record/record_new_page.dart';
import 'home_shell.dart';

final GoRouter goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeShell(),
    ),
    GoRoute(
      path: '/record/new',
      builder: (context, state) => const RecordNewPage(),
    ),
    GoRoute(
      path: '/record/categories',
      builder: (context, state) => const CategoryManagePage(),
    ),
    GoRoute(
      path: '/record/categories/parent',
      builder: (context, state) {
        final parentKey = state.uri.queryParameters['parentKey'] ?? 'food';
        return CategoryManagePage(parentKey: parentKey);
      },
    ),
    GoRoute(
      path: '/ledger/edit',
      builder: (context, state) {
        final ledgerId = state.uri.queryParameters['id'];
        return LedgerEditPage(ledgerId: ledgerId);
      },
    ),
  ],
);
