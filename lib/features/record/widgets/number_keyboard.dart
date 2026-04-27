import 'package:flutter/material.dart';

/// 自定义数字键盘：0-9、小数点、+、-、⌫、币种、动态「= / ✓」。
///
/// 布局（按设计图）：
/// ```
///  7    8    9    ⌫
///  4    5    6    +
///  1    2    3    -
/// CNY   0    .    ✓/=
/// ```
/// 每个按键通过 `onKeyTap(String key)` 回调通知父组件。
class NumberKeyboard extends StatelessWidget {
  const NumberKeyboard({
    super.key,
    required this.onKeyTap,
    required this.currencyLabel,
    required this.showEquals,
    this.onActionTap,
    this.canAction = false,
    this.onCurrencyTap,
  });

  final ValueChanged<String> onKeyTap;
  final String currencyLabel;
  final bool showEquals;
  final VoidCallback? onActionTap;
  final bool canAction;
  final VoidCallback? onCurrencyTap;

  static const _rows = [
    ['7', '8', '9', '⌫'],
    ['4', '5', '6', '+'],
    ['1', '2', '3', '-'],
    ['CURRENCY', '0', '.', 'ACTION'],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Column(
        children: [
          for (final row in _rows)
            Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: _KeyButton(
                      label: key == 'CURRENCY'
                          ? currencyLabel
                          : key == 'ACTION'
                              ? (showEquals ? '=' : '✓')
                              : key,
                      onTap: () {
                        if (key == 'CURRENCY') {
                          (onCurrencyTap ?? () {})();
                          return;
                        }
                        if (key == 'ACTION') {
                          (onActionTap ?? () {})();
                          return;
                        }
                        onKeyTap(key);
                      },
                      highlight: key == 'ACTION',
                      enabled: key == 'ACTION' ? canAction : true,
                      colors: colors,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.enabled = true,
    required this.colors,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final bool enabled;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        height: 65,
        child: Material(
          color: highlight ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: label == '✓' || label == '=' ? 20 : 22,
                  fontWeight: FontWeight.w600,
                  color: highlight
                      ? colors.onPrimary
                      : enabled
                          ? colors.onSurface
                          : colors.onSurface.withAlpha(80),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
