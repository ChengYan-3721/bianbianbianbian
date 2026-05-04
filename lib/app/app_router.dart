import 'package:go_router/go_router.dart';

import '../domain/entity/category.dart';
import '../features/account/account_edit_page.dart';
import '../features/account/account_list_page.dart';
import '../features/budget/budget_edit_page.dart';
import '../features/budget/budget_list_page.dart';
import '../features/ledger/ledger_edit_page.dart';
import '../features/record/category_edit_page.dart';
import '../features/record/category_manage_page.dart';
import '../features/record/category_reorder_page.dart';
import '../features/record/favorite_reorder_page.dart';
import '../features/record/record_new_page.dart';
import '../features/record/record_search_page.dart';
import '../features/settings/ai_input_settings_page.dart';
import '../features/settings/attachment_cache_page.dart';
import '../features/settings/multi_currency_page.dart';
import '../features/sync/cloud_service_page.dart';
import '../features/trash/trash_page.dart';
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
      path: '/record/search',
      builder: (context, state) => const RecordSearchPage(),
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
      path: '/record/categories/edit',
      builder: (context, state) {
        final parentKey = state.uri.queryParameters['parentKey'];
        final extraCategory = state.extra as Category?;
        if (extraCategory != null) {
          return CategoryEditPage(initialCategory: extraCategory);
        }
        if (parentKey != null) {
          return CategoryEditPage(parentKey: parentKey);
        }
        // 默认使用 food 作为 parentKey（兼容旧调用）
        return CategoryEditPage(parentKey: 'food');
      },
    ),
    GoRoute(
      path: '/record/categories/reorder',
      builder: (context, state) {
        final parentKey = state.uri.queryParameters['parentKey'] ?? 'food';
        return CategoryReorderPage(parentKey: parentKey);
      },
    ),
    GoRoute(
      path: '/record/categories/favorites/reorder',
      builder: (context, state) => const FavoriteReorderPage(),
    ),
    GoRoute(
      path: '/ledger/edit',
      builder: (context, state) {
        final ledgerId = state.uri.queryParameters['id'];
        return LedgerEditPage(ledgerId: ledgerId);
      },
    ),
    GoRoute(
      path: '/budget',
      builder: (context, state) => const BudgetListPage(),
    ),
    GoRoute(
      path: '/budget/edit',
      builder: (context, state) {
        final budgetId = state.uri.queryParameters['id'];
        return BudgetEditPage(budgetId: budgetId);
      },
    ),
    GoRoute(
      path: '/accounts',
      builder: (context, state) => const AccountListPage(),
    ),
    GoRoute(
      path: '/accounts/edit',
      builder: (context, state) {
        final accountId = state.uri.queryParameters['id'];
        return AccountEditPage(accountId: accountId);
      },
    ),
    GoRoute(
      path: '/settings/multi-currency',
      builder: (context, state) => const MultiCurrencyPage(),
    ),
    GoRoute(
      path: '/settings/ai-input',
      builder: (context, state) => const AiInputSettingsPage(),
    ),
    GoRoute(
      path: '/settings/attachment-cache',
      builder: (context, state) => const AttachmentCachePage(),
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => const CloudServicePage(),
    ),
    GoRoute(
      path: '/trash',
      builder: (context, state) => const TrashPage(),
    ),
  ],
);
