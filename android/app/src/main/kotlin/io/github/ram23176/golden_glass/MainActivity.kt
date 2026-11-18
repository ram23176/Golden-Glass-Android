package io.github.ram23176.golden_glass

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Flutter (Dart) ↔ Android-এর সেতু।
 * Dart থেকে "golden_glass/native" চ্যানেলে কল আসে; ভারী কাজ (ওয়ালপেপার সেট, স্টোরেজ পড়া)
 * আলাদা থ্রেডে চলে যাতে UI আটকে না যায়।
 */
class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val ctx = applicationContext
        when (call.method) {
            "getDeviceInfo" -> result.success(SystemInfo.device(ctx))
            "getBattery" -> result.success(SystemInfo.battery(ctx))
            "getMemory" -> result.success(SystemInfo.memory(ctx))
            "getStorage" -> background(result) { SystemInfo.storage(ctx) }
            "setWallpaper" -> {
                val path = call.argument<String>("path") ?: return result.error("ARG", "path", null)
                val target = call.argument<String>("target") ?: "both"
                val fit = call.argument<String>("fit") ?: "auto"
                background(result) {
                    val ok = WallpaperHelper.apply(ctx, path, target, fit)
                    if (ok) {
                        NativePrefs.get(ctx).edit().putString(NativePrefs.LAST_PATH, path).apply()
                        WidgetUpdater.refresh(ctx)
                    }
                    ok
                }
            }
            "configurePool" -> {
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                AutoChanger.configure(
                    ctx, paths,
                    call.argument<Boolean>("shuffle") ?: false,
                    call.argument<String>("target") ?: "both",
                    call.argument<String>("fit") ?: "auto",
                )
                WidgetUpdater.refresh(ctx)
                result.success(true)
            }
            "nextWallpaper" -> background(result) { AutoChanger.next(ctx) }
            "scheduleAuto" -> {
                AutoChanger.schedule(ctx, call.argument<Int>("minutes") ?: 30)
                result.success(true)
            }
            "cancelAuto" -> {
                AutoChanger.cancel(ctx)
                result.success(true)
            }
            "getLastWallpaper" -> result.success(
                NativePrefs.get(ctx).getString(NativePrefs.LAST_PATH, null)
            )
            "configureWidget" -> {
                NativePrefs.get(ctx).edit()
                    .putInt(NativePrefs.ACCENT, (call.argument<Number>("accent") ?: 0xFFFFB800).toInt())
                    .putString(NativePrefs.LABEL_FREE, call.argument<String>("free") ?: "free")
                    .putString(NativePrefs.LABEL_NEXT, call.argument<String>("next") ?: "Next")
                    .apply()
                WidgetUpdater.refresh(ctx)
                result.success(WidgetUpdater.count(ctx))
            }
            "widgetCount" -> result.success(WidgetUpdater.count(ctx))
            "canPinWidget" -> result.success(WidgetUpdater.canPin(ctx))
            "pinWidget" -> result.success(WidgetUpdater.requestPin(ctx))
            else -> result.notImplemented()
        }
    }

    /** কাজটি ব্যাকগ্রাউন্ড থ্রেডে চালিয়ে ফলাফল মেইন থ্রেডে ফেরত দেয়। */
    private fun background(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("NATIVE", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "golden_glass/native"
    }
}
