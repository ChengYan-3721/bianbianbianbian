package com.bianbianbianbian.bianbianbianbian

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Step 14.4 隐私模式：通过 MethodChannel `bianbian/privacy` 接收 Dart 侧的
 * setEnabled(bool) 调用，开启时给 Window 打 FLAG_SECURE。
 *
 * FLAG_SECURE 是系统级 flag —— 前台常态用于阻止系统截屏 / 录屏，部分设备的
 * "无障碍服务截屏"也会被拦截。Dart 层在进入多任务快照前会先盖模糊遮罩，并短暂
 * 调 setEnabled(false) 清掉 flag，让 Android 尽量捕获遮罩而不是安全窗口空白占位；
 * 回前台后再调 setEnabled(true) 恢复前台截屏保护。
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
