import 'package:flutter/material.dart';

/// Step 3.7：自定义"年-月"快速选择器。
///
/// 接入 `record_home_page.dart` 顶部月份显示区域：点击显示文字弹出本对话框，
/// 支持快速跳转到任意年份（左右箭头切换）+ 点选月份；返回值是 `DateTime(year, month)`，
/// `day` 固定为 1，与 `RecordMonthProvider` 的语义对齐。
///
/// 取消 / 关闭返回 `null`，调用方据此判断是否更新当前月份。
///
/// 设计取舍：
/// - 没用 `showDatePicker` 自带的 `DatePickerMode.year`——它强迫用户先选年再选日，
///   且无法直接选到"年/月"粒度，跨年快速跳转体验差。
/// - 没引入第三方包：仅 6 行 × 2 列网格 + 上下箭头，原生 Material widget 拼装即可。
Future<DateTime?> showMonthPicker({
  required BuildContext context,
  required DateTime initialMonth,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _MonthPickerDialog(
      initialMonth: initialMonth,
      firstDate: firstDate ?? DateTime(2000, 1),
      lastDate: lastDate ?? DateTime(DateTime.now().year + 5, 12),
    ),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({
    required this.initialMonth,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialMonth;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _displayYear; // 当前网格展示的年份
  late int _selectedYear; // 当前已选中（高亮）的年
  late int _selectedMonth; // 当前已选中（高亮）的月

  @override
  void initState() {
    super.initState();
    _displayYear = widget.initialMonth.year;
    _selectedYear = widget.initialMonth.year;
    _selectedMonth = widget.initialMonth.month;
  }

  bool _canPrevYear() => _displayYear > widget.firstDate.year;
  bool _canNextYear() => _displayYear < widget.lastDate.year;

  bool _isMonthEnabled(int year, int month) {
    final candidate = DateTime(year, month);
    final firstAllowed =
        DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastAllowed =
        DateTime(widget.lastDate.year, widget.lastDate.month);
    if (candidate.isBefore(firstAllowed)) return false;
    if (candidate.isAfter(lastAllowed)) return false;
    return true;
  }

  void _onMonthTap(int month) {
    if (!_isMonthEnabled(_displayYear, month)) return;
    setState(() {
      _selectedYear = _displayYear;
      _selectedMonth = month;
    });
  }

  void _confirm() {
    Navigator.of(context).pop(DateTime(_selectedYear, _selectedMonth));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      title: Row(
        children: [
          IconButton(
            key: const Key('month_picker_prev_year'),
            tooltip: '上一年',
            onPressed: _canPrevYear()
                ? () => setState(() => _displayYear--)
                : null,
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$_displayYear 年',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          IconButton(
            key: const Key('month_picker_next_year'),
            tooltip: '下一年',
            onPressed: _canNextYear()
                ? () => setState(() => _displayYear++)
                : null,
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (int month = 1; month <= 12; month++)
              _MonthCell(
                month: month,
                enabled: _isMonthEnabled(_displayYear, month),
                selected: _displayYear == _selectedYear &&
                    month == _selectedMonth,
                onTap: () => _onMonthTap(month),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: colors.onSurface,
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('month_picker_confirm'),
          onPressed: _confirm,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.month,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final int month;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = selected
        ? colors.primary
        : enabled
            ? colors.primary.withAlpha(28)
            : colors.surfaceContainerHighest;
    final fg = selected
        ? colors.onPrimary
        : enabled
            ? colors.onSurface
            : colors.onSurface.withAlpha(80);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('month_picker_cell_$month'),
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Center(
          child: Text(
            '$month 月',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
        ),
      ),
    );
  }
}
