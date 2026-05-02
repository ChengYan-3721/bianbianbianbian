import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/util/currencies.dart';
import '../../data/local/app_database.dart';
import 'settings_providers.dart';

/// Step 8.1：多币种设置页（Step 8.3 扩展为汇率管理）。
///
/// 三段：① 全局开关 SwitchListTile；② 内置币种概览；③ 汇率列表（每行一种币种，
/// 含手动/自动徽章 + 更新时间，点击进入手动覆盖对话框）。AppBar 右侧"立即刷新"
/// 按钮触发 force=true 刷新。
class MultiCurrencyPage extends ConsumerStatefulWidget {
  const MultiCurrencyPage({super.key});

  @override
  ConsumerState<MultiCurrencyPage> createState() => _MultiCurrencyPageState();
}

class _MultiCurrencyPageState extends ConsumerState<MultiCurrencyPage> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget：进入页面尝试触发节流后的自动刷新；失败静默。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(fxRateRefreshServiceProvider)
          .refreshIfDue()
          .then((ok) {
        if (!mounted || !ok) return;
        ref.invalidate(fxRateRowsProvider);
        ref.invalidate(fxRatesProvider);
      });
    });
  }

  Future<void> _refreshNow() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(fxRateRefreshServiceProvider);
      final ok = await service.refreshIfDue(force: true);
      ref.invalidate(fxRateRowsProvider);
      ref.invalidate(fxRatesProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(ok ? '汇率已更新' : '联网失败，使用现有快照')),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openManualDialog(FxRateRow row) async {
    if (row.code == 'CNY') return;
    final result = await showDialog<_ManualResult>(
      context: context,
      builder: (_) => _ManualRateDialog(row: row),
    );
    if (result == null || !mounted) return;
    final service = ref.read(fxRateRefreshServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (result.reset) {
      await service.resetToAuto(row.code);
      ref.invalidate(fxRateRowsProvider);
      ref.invalidate(fxRatesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('${row.code} 已恢复自动刷新')),
      );
      return;
    }
    final newRate = result.rate;
    if (newRate != null) {
      await service.setManualRate(row.code, newRate);
      ref.invalidate(fxRateRowsProvider);
      ref.invalidate(fxRatesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('${row.code} 汇率已手动设为 $newRate')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncEnabled = ref.watch(multiCurrencyEnabledProvider);
    final asyncRows = ref.watch(fxRateRowsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('多币种'),
        actions: [
          IconButton(
            key: const Key('fx_refresh_now'),
            tooltip: '立即刷新汇率',
            onPressed: _refreshing ? null : _refreshNow,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        children: [
          asyncEnabled.when(
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('多币种'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('多币种'),
              subtitle: Text('读取失败：$e'),
            ),
            data: (enabled) => SwitchListTile(
              key: const Key('multi_currency_switch'),
              value: enabled,
              onChanged: (v) =>
                  ref.read(multiCurrencyEnabledProvider.notifier).set(v),
              title: const Text('开启多币种'),
              subtitle: const Text('开启后，记账页可选择币种；统计按账本默认币种换算展示。'),
              secondary: const Icon(Icons.public),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('内置币种'),
            subtitle: Text(
              kBuiltInCurrencies.map((c) => c.code).join(' · '),
            ),
            leading: const Icon(Icons.list_alt_outlined),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '汇率管理',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '点击行可手动设置汇率；标记为"手动"的行不会被自动刷新覆盖。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          asyncRows.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('加载失败：$e'),
            ),
            data: (rows) => Column(
              children: [
                for (final row in rows.map(FxRateRow.fromEntry))
                  _FxRateTile(
                    row: row,
                    onTap: () => _openManualDialog(row),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 视图模型——把 drift 行解耦成 UI 用结构，便于测试。
class FxRateRow {
  const FxRateRow({
    required this.code,
    required this.rateToCny,
    required this.updatedAt,
    required this.isManual,
  });

  factory FxRateRow.fromEntry(FxRateEntry entry) {
    return FxRateRow(
      code: entry.code,
      rateToCny: entry.rateToCny,
      updatedAt: entry.updatedAt,
      isManual: entry.isManual == 1,
    );
  }

  final String code;
  final double rateToCny;
  final int updatedAt;
  final bool isManual;
}

class _FxRateTile extends StatelessWidget {
  const _FxRateTile({required this.row, required this.onTap});

  final FxRateRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currency = kBuiltInCurrencies.firstWhere(
      (c) => c.code == row.code,
      orElse: () => Currency(code: row.code, symbol: row.code, name: row.code),
    );
    final updated = DateTime.fromMillisecondsSinceEpoch(row.updatedAt);
    final updatedText =
        DateFormat('yyyy-MM-dd HH:mm').format(updated.toLocal());
    final isCny = row.code == 'CNY';
    final badge = isCny
        ? '基准'
        : (row.isManual ? '手动' : '自动');
    final badgeColor = isCny
        ? Colors.grey
        : (row.isManual ? Colors.orange : Colors.green);

    return ListTile(
      key: Key('fx_rate_row_${row.code}'),
      enabled: !isCny,
      onTap: isCny ? null : onTap,
      leading: SizedBox(
        width: 56,
        child: Text(
          row.code,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(currency.name)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '1 ${row.code} = ${row.rateToCny.toStringAsFixed(4)} CNY · 更新于 $updatedText',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _ManualResult {
  const _ManualResult({this.rate, this.reset = false});
  final double? rate;
  final bool reset;
}

class _ManualRateDialog extends StatefulWidget {
  const _ManualRateDialog({required this.row});
  final FxRateRow row;

  @override
  State<_ManualRateDialog> createState() => _ManualRateDialogState();
}

class _ManualRateDialogState extends State<_ManualRateDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.row.rateToCny.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0 || !value.isFinite) {
      setState(() => _error = '请输入正数（例如 7.20）');
      return;
    }
    Navigator.of(context).pop(_ManualResult(rate: value));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('设置 ${widget.row.code} 汇率'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1 ${widget.row.code} 等于多少 CNY？'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('manual_rate_field'),
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '例如 7.20',
              errorText: _error,
              suffixText: 'CNY',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.row.isManual)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '当前为手动覆盖，自动刷新不会修改它。',
                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
              ),
            ),
        ],
      ),
      actions: [
        if (widget.row.isManual)
          TextButton(
            key: const Key('manual_rate_reset'),
            onPressed: () =>
                Navigator.of(context).pop(const _ManualResult(reset: true)),
            child: const Text('重置为自动'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('manual_rate_submit'),
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
