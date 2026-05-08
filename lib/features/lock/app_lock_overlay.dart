import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_providers.dart';
import 'pin_unlock_page.dart';

/// Step 14.3：前台锁屏 overlay。
///
/// **不在路由栈内**——由 [BianBianApp] 在 `MaterialApp.router(builder: ...)` 里
/// 套一层 [Stack]，根据 [appLockGuardProvider] 的 `isLocked` 决定是否显示本
/// widget。这样做的优点：
/// 1. 深链跳转（`bianbian://record/new` 等）即便命中路由也仍被 overlay 挡在最
///    上层——锁屏期间不可能"跳过"或"穿透"到 protected 页面；
/// 2. 解锁后路由栈状态被保留——用户被锁前在哪页，解锁后还在那页，无需重新加载；
/// 3. 与 GoRouter 的 redirect 机制解耦——后续加新路由不需要在每个 builder 里重
///    复"是否锁屏"判断。
///
/// 内部包 [Material] + [PopScope]：
/// - [Material] 提供 InkWell / TextField 等需要的 ancestor；
/// - [PopScope] `canPop: false` 拦截 Android 物理返回键、桌面端 Esc 键，避免
///   用户绕过锁屏。系统级"切回桌面"不归 PopScope 管，但那不是"跳过"——下次回到
///   前台 isLocked 仍 true。
class AppLockOverlay extends ConsumerWidget {
  const AppLockOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Material(
        // 撑满父级 Stack；锁屏要完全遮盖底下的路由器内容。
        type: MaterialType.canvas,
        child: PinUnlockPage(
          subtitle: '请输入 PIN 解锁边边记账',
          allowBiometric: true,
          showAppBar: false,
          onUnlocked: () =>
              ref.read(appLockGuardProvider.notifier).unlock(),
        ),
      ),
    );
  }
}
