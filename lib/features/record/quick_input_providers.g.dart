// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_input_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$quickTextParserHash() => r'1014623845fa8eff52b8a91888e253711e8f7a53';

/// Step 9.2：首页快捷输入条使用的本地解析器 provider。
///
/// `keepAlive: true` 让首页输入实例复用同一个 parser；clock 默认
/// `DateTime.now`，测试可通过 override 注入固定时间，让 `昨天 / N天前 /
/// 上周X` 这些相对时间断言稳定。Step 9.3 LLM 增强按钮也会消费同 provider
/// 拿到的解析结果作为兜底（即使 AI 失败也仍能展示本地基线）。
///
/// Copied from [quickTextParser].
@ProviderFor(quickTextParser)
final quickTextParserProvider = Provider<QuickTextParser>.internal(
  quickTextParser,
  name: r'quickTextParserProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$quickTextParserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef QuickTextParserRef = ProviderRef<QuickTextParser>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
