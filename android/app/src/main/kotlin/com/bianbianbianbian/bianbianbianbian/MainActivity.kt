package com.bianbianbianbian.bianbianbianbian

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Step 14.4 隐私模式：通过 MethodChannel `bianbian/privacy` 接收 Dart 侧的
 * setEnabled(bool) 调用，开启时给 Window 打 FLAG_SECURE。
 *
 * FLAG_SECURE 是系统级 flag —— 同时实现：
 *   1. 多任务（Recent apps）预览中本 App 显示纯黑（Android 自动处理）；
 *   2. 系统截屏 / 录屏被阻止；
 *   3. 部分设备的"无障碍服务截屏"也被拦截。
 *
 * setFlags / clearFlags 必须在 UI 线程调用 —— MethodChannel 默认在 UI 线程派发，
 * 直接调即可。
 */
class MainActivity : FlutterFragmentActivity() {
    private val privacyChannelName = "bianbian/privacy"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, privacyChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        val enabled = call.arguments as? Boolean
                        if (enabled == null) {
                            result.error(
                                "INVALID_ARGUMENT",
                                "setEnabled expects Bool argument",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        if (enabled) {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
