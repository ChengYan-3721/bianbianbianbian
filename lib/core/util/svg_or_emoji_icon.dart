import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 优先渲染 SVG 图标，无 SVG 时回退到 Emoji 文本。
///
/// [svgString] 为 SVG 代码字符串（如 `<svg>...</svg>`），非空时使用
/// [SvgPicture.string] 渲染；为空时使用 [emoji] 作为 [Text] 显示。
///
/// [size] 控制图标整体尺寸（默认 20），SVG 和 Emoji 均受此约束。
class SvgOrEmojiIcon extends StatelessWidget {
  const SvgOrEmojiIcon({
    super.key,
    this.svgString,
    this.emoji,
    this.size = 20,
    this.color,
  });

  /// SVG 代码字符串，非空时优先渲染。
  final String? svgString;

  /// Emoji 回退文本。
  final String? emoji;

  /// 图标尺寸。
  final double size;

  /// SVG 着色（仅对单色 SVG 有效），Emoji 不受影响。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (svgString != null && svgString!.trim().isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.string(
          svgString!,
          width: size,
          height: size,
          colorFilter: color != null
              ? ColorFilter.mode(color!, BlendMode.srcIn)
              : null,
          placeholderBuilder: (_) => _emojiFallback(),
        ),
      );
    }
    return _emojiFallback();
  }

  Widget _emojiFallback() {
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          emoji ?? '📁',
          style: TextStyle(fontSize: size),
        ),
      ),
    );
  }
}