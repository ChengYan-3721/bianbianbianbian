import 'package:home_widget/home_widget.dart';

import '../../data/repository/ledger_repository.dart'
    show LedgerRepository;
import '../../data/repository/transaction_repository.dart'
    show TransactionRepository;
import '../../domain/entity/ledger.dart';
import '../../domain/entity/transaction_entry.dart';

/// 小组件展示数据——今日支出 + 本月结余 + 账本名称。
class WidgetData {
  const WidgetData({
    required this.todayExpense,
    required this.monthlyBalance,
    required this.ledgerName,
  });

  /// 格式化后的今日支出，如 `"¥25.00"`。
  final String todayExpense;

  /// 格式化后的本月结余，如 `"¥150.00"` 或 `"-¥30.00"`。
  final String monthlyBalance;

  /// 账本名称，如 `"📒 生活"`。
  final String ledgerName;

  static const empty = WidgetData(
    todayExpense: '¥0.00',
    monthlyBalance: '¥0.00',
    ledgerName: '边边记账',
  );
}

/// SharedPreferences / UserDefaults 中与原生小组件共享的 key。
const _keyTodayExpense = 'widget_today_expense';
const _keyMonthlyBalance = 'widget_monthly_balance';
const _keyLedgerName = 'widget_ledger_name';

/// iOS App Group ID（需与 Xcode 中 Widget Extension 的 App Group 一致）。
const kWidgetAppGroupId = 'group.com.bianbianbianbian.app';

/// Android 原生 AppWidgetProvider 全限定类名。
const kAndroidWidgetQualifiedName =
    'com.bianbianbianbian.bianbianbianbian.BianBianWidgetProvider';

/// 纯函数：从当前账本的活跃流水计算小组件数据。
///
/// 可独立测试，不依赖任何 Flutter / Riverpod / home_widget API。
WidgetData computeWidgetData({
  required List<TransactionEntry> transactions,
  required String ledgerName,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  double todayExpense = 0;
  double monthIncome = 0;
  double monthExpense = 0;

  for (final tx in transactions) {
    final converted = tx.amount * tx.fxRate;
    final txDate = DateTime(
      tx.occurredAt.year,
      tx.occurredAt.month,
      tx.occurredAt.day,
    );

    // 今日支出
    if (txDate == today && tx.type == 'expense') {
      todayExpense += converted;
    }

    // 本月收支
    if (tx.occurredAt.year == now.year && tx.occurredAt.month == now.month) {
      if (tx.type == 'income') {
        monthIncome += converted;
      } else if (tx.type == 'expense') {
        monthExpense += converted;
      }
    }
  }

  return WidgetData(
    todayExpense: _formatAmount(todayExpense),
    monthlyBalance: _formatAmount(monthIncome - monthExpense),
    ledgerName: ledgerName,
  );
}

String _formatAmount(double amount) {
  final abs = amount.abs().toStringAsFixed(2);
  return amount < 0 ? '-¥$abs' : '¥$abs';
}

/// 小组件数据读写与刷新服务。
///
/// 通过 [HomeWidget] 将数据写入 SharedPreferences / UserDefaults，
/// 供原生 WidgetKit / AppWidgetProvider 读取。刷新时触发
/// `APPWIDGET_UPDATE` 广播（Android）或 `reloadAllTimelines`（iOS）。
///
/// 调用方一律 fire-and-forget；平台不支持（桌面 / Web）时静默吞错。
class WidgetDataService {
  WidgetDataService._();

  /// iOS 初始化——设置 App Group ID，让主 App 与 Widget Extension 共享
  /// UserDefaults。Android 无需此步。应在首次 save 前调用。
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    } catch (_) {
      // 非 iOS / Android 平台
    }
  }

  /// 将 [WidgetData] 写入平台存储并触发原生小组件刷新。
  static Future<void> saveAndRefresh(WidgetData data) async {
    try {
      await HomeWidget.saveWidgetData(_keyTodayExpense, data.todayExpense);
      await HomeWidget.saveWidgetData(_keyMonthlyBalance, data.monthlyBalance);
      await HomeWidget.saveWidgetData(_keyLedgerName, data.ledgerName);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: kAndroidWidgetQualifiedName,
      );
    } catch (_) {
      // 平台不支持
    }
  }

  /// 从仓库层读取当前账本数据 → 计算 → 持久化。
  ///
  /// 接受原始仓库实例而非 Riverpod `Ref`，兼容 `WidgetRef` /
  /// `ProviderContainer.read` / `Ref` 等各类调用方。
  static Future<void> computeAndRefresh({
    required String ledgerId,
    required TransactionRepository txRepo,
    required LedgerRepository ledgerRepo,
  }) async {
    final txs = await txRepo.listActiveByLedger(ledgerId);
    final ledger = await ledgerRepo.getById(ledgerId);

    final data = computeWidgetData(
      transactions: txs,
      ledgerName: _formatLedgerName(ledger),
    );

    await saveAndRefresh(data);
  }

  static String _formatLedgerName(Ledger? ledger) {
    if (ledger == null) return '边边记账';
    final emoji = ledger.coverEmoji;
    return emoji != null && emoji.isNotEmpty
        ? '$emoji ${ledger.name}'
        : ledger.name;
  }
}
