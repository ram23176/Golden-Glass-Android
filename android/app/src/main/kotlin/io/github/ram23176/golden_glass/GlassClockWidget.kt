package io.github.ram23176.golden_glass

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/** হোম স্ক্রিন উইজেট: ঘড়ি + তারিখ + ব্যাটারি + খালি জায়গা + "পরের ওয়ালপেপার" বাটন। */
class GlassClockWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        WidgetUpdater.refresh(context)
    }

    override fun onEnabled(context: Context) {
        val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(REFRESH_WORK, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    override fun onDisabled(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(REFRESH_WORK)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_NEXT) {
            val pending = goAsync()
            thread {
                try {
                    AutoChanger.next(context.applicationContext)
                } finally {
                    pending.finish()
                }
            }
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        const val ACTION_NEXT = "io.github.ram23176.golden_glass.NEXT_WALLPAPER"
        private const val REFRESH_WORK = "gg_widget_refresh"
    }
}

object WidgetUpdater {
    private fun component(context: Context) = ComponentName(context, GlassClockWidget::class.java)

    fun count(context: Context): Int =
        AppWidgetManager.getInstance(context).getAppWidgetIds(component(context)).size

    fun canPin(context: Context): Boolean =
        AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported

    fun requestPin(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        if (!manager.isRequestPinAppWidgetSupported) return false
        return manager.requestPinAppWidget(component(context), null, null)
    }

    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(component(context))
        if (ids.isEmpty()) return

        val prefs = NativePrefs.get(context)
        val accent = prefs.getInt(NativePrefs.ACCENT, 0xFFFFB800.toInt())
        val freeLabel = prefs.getString(NativePrefs.LABEL_FREE, "free") ?: "free"
        val nextLabel = prefs.getString(NativePrefs.LABEL_NEXT, "Next") ?: "Next"
        val battery = SystemInfo.battery(context)
        val level = battery["level"] as? Int ?: -1
        val charging = battery["charging"] as? Boolean ?: false
        val free = SystemInfo.internalFree(context)
        val hasPool = AutoChanger.pool(context).isNotEmpty()

        val views = RemoteViews(context.packageName, R.layout.widget_glass_clock).apply {
            setTextColor(R.id.w_time, accent)
            setInt(R.id.w_accent_bar, "setBackgroundColor", accent)
            setTextViewText(R.id.w_battery, if (level >= 0) "${if (charging) "⚡" else "🔋"} $level%" else "🔋 —")
            setTextViewText(R.id.w_storage, "💾 ${formatBytes(free)} $freeLabel")
            setViewVisibility(R.id.w_next, if (hasPool) View.VISIBLE else View.GONE)
            setContentDescription(R.id.w_next, nextLabel)
            setInt(R.id.w_next, "setColorFilter", accent)

            val open = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            setOnClickPendingIntent(R.id.w_root, PendingIntent.getActivity(
                context, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))

            val next = Intent(context, GlassClockWidget::class.java).setAction(GlassClockWidget.ACTION_NEXT)
            setOnClickPendingIntent(R.id.w_next, PendingIntent.getBroadcast(
                context, 1, next, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        }
        manager.updateAppWidget(ids, views)
    }

    fun formatBytes(bytes: Long): String {
        val gb = bytes / 1_000_000_000.0
        return if (gb >= 1) String.format(Locale.US, "%.1f GB", gb)
        else String.format(Locale.US, "%.0f MB", bytes / 1_000_000.0)
    }
}
