import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/util/quick_text_parser.dart';

part 'quick_input_providers.g.dart';

/// Step 9.2：首页快捷输入条使用的本地解析器 provider。
///
/// `keepAlive: true` 让首页输入实例复用同一个 parser；clock 默认
/// `DateTime.now`，测试可通过 override 注入固定时间，让 `昨天 / N天前 /
/// 上周X` 这些相对时间断言稳定。Step 9.3 LLM 增强按钮也会消费同 provider
/// 拿到的解析结果作为兜底（即使 AI 失败也仍能展示本地基线）。
@Riverpod(keepAlive: true)
QuickTextParser quickTextParser(Ref ref) {
  return QuickTextParser();
}

/// implementation-plan §9.2 建议的低置信度阈值（0.6）。
///
/// 解析结果置信度低于此值时确认卡片高亮"请核对"提示；Step 9.3 也以同阈值
/// 决定是否暴露"AI 增强"按钮。常量而非 provider —— 阈值是产品决策、不
/// 随会话或账本变化，纯依赖项里没必要走 Riverpod。
const double quickConfidenceThreshold = 0.6;
