package io.github.ram23176.golden_glass

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * স্বয়ংক্রিয় ওয়ালপেপার বদল।
 * WorkManager ব্যবহার করে — অ্যাপ বন্ধ থাকলেও, ফোন রিস্টার্টের পরেও চলে।
 * Android-এর নিয়মে সবচেয়ে কম ব্যবধান ১৫ মিনিট।
 */
object AutoChanger {
    private const val WORK_NAME = "gg_auto_wallpaper"
    const val MIN_MINUTES = 15L
    private val lock = Any()

    fun configure(context: Context, paths: List<String>, shuffle: Boolean, target: String, fit: String) {
        NativePrefs.get(context).edit()
            .putString(NativePrefs.POOL, JSONArray(paths).toString())
            .putBoolean(NativePrefs.SHUFFLE, shuffle)
            .putString(NativePrefs.TARGET, target)
            .putString(NativePrefs.FIT, fit)
            .apply()
    }

    fun pool(context: Context): List<String> {
        val raw = NativePrefs.get(context).getString(NativePrefs.POOL, "[]") ?: "[]"
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }.filter { File(it).isFile }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** তালিকার পরের ওয়ালপেপার সেট করে; সফল হলে তার পাথ, না হলে null। */
    fun next(context: Context): String? = synchronized(lock) {
        val prefs = NativePrefs.get(context)
        val items = pool(context)
        if (items.isEmpty()) return null
        val last = prefs.getString(NativePrefs.LAST_PATH, null)
        val nextPath = if (prefs.getBoolean(NativePrefs.SHUFFLE, false) && items.size > 1) {
            items.filter { it != last }.random()
        } else {
            items[(items.indexOf(last) + 1) % items.size]
        }
        val target = prefs.getString(NativePrefs.TARGET, "both") ?: "both"
        val fit = prefs.getString(NativePrefs.FIT, "auto") ?: "auto"
        if (!WallpaperHelper.apply(context, nextPath, target, fit)) return null
        prefs.edit().putString(NativePrefs.LAST_PATH, nextPath).apply()
        WidgetUpdater.refresh(context)
        nextPath
    }

    fun schedule(context: Context, minutes: Int) {
        val m = minutes.toLong().coerceAtLeast(MIN_MINUTES)
        val request = PeriodicWorkRequestBuilder<WallpaperWorker>(m, TimeUnit.MINUTES)
            .setInitialDelay(m, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
}

class WallpaperWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        AutoChanger.next(applicationContext)
        return Result.success()   // ব্যর্থ হলেও পরের নির্ধারিত সময়ে আবার চেষ্টা হবে
    }
}

/** উইজেটের ব্যাটারি/স্টোরেজ তথ্য ১৫ মিনিট পরপর হালনাগাদ করে। */
class WidgetRefreshWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        WidgetUpdater.refresh(applicationContext)
        return Result.success()
    }
}
