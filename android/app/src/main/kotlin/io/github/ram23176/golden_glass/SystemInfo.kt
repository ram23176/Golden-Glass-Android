package io.github.ram23176.golden_glass

import android.app.ActivityManager
import android.app.usage.StorageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.SystemClock
import android.os.storage.StorageManager

/** ব্যাটারি, RAM, স্টোরেজ ও ডিভাইসের তথ্য — কোনো বিশেষ permission লাগে না। */
object SystemInfo {

    fun device(context: Context): Map<String, Any?> {
        val dm = context.resources.displayMetrics
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "android" to Build.VERSION.RELEASE,
            "sdk" to Build.VERSION.SDK_INT,
            "cores" to Runtime.getRuntime().availableProcessors(),
            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
            "uptimeMs" to SystemClock.elapsedRealtime(),
            "screen" to "${dm.widthPixels} × ${dm.heightPixels}",
        )
    }

    fun battery(context: Context): Map<String, Any?> {
        val intent: Intent? = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val bm = context.getSystemService(BatteryManager::class.java)
        var level = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
        if (level !in 0..100 && intent != null) {
            val raw = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
            if (raw >= 0 && scale > 0) level = raw * 100 / scale
        }
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val health = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, 0) ?: 0
        return mapOf(
            "level" to level,
            "charging" to (status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL),
            "full" to (status == BatteryManager.BATTERY_STATUS_FULL),
            "plugged" to when (plugged) {
                BatteryManager.BATTERY_PLUGGED_AC -> "ac"
                BatteryManager.BATTERY_PLUGGED_USB -> "usb"
                BatteryManager.BATTERY_PLUGGED_WIRELESS -> "wireless"
                0 -> "none"
                else -> "other"
            },
            "health" to when (health) {
                BatteryManager.BATTERY_HEALTH_GOOD -> "good"
                BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
                BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
                BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "over_voltage"
                BatteryManager.BATTERY_HEALTH_COLD -> "cold"
                else -> "unknown"
            },
            "temperature" to ((intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                ?: Int.MIN_VALUE).let { if (it == Int.MIN_VALUE) null else it / 10.0 }),
            "voltage" to (intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)?.takeIf { it > 0 }),
            "technology" to intent?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY),
        )
    }

    fun memory(context: Context): Map<String, Any?> {
        val am = context.getSystemService(ActivityManager::class.java)
        val info = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(info)
        return mapOf("total" to info.totalMem, "available" to info.availMem, "low" to info.lowMemory)
    }

    /** ফোনের নিজস্ব স্টোরেজ + SD কার্ড / USB OTG (যদি লাগানো থাকে)। */
    fun storage(context: Context): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()

        // Settings অ্যাপ যে সংখ্যা দেখায় (যেমন 128 GB) সেটাই StorageStatsManager দেয়
        var total: Long
        var free: Long
        try {
            val ssm = context.getSystemService(StorageStatsManager::class.java)
            total = ssm.getTotalBytes(StorageManager.UUID_DEFAULT)
            free = ssm.getFreeBytes(StorageManager.UUID_DEFAULT)
        } catch (e: Exception) {
            val fs = StatFs(Environment.getDataDirectory().path)
            total = fs.totalBytes
            free = fs.availableBytes
        }
        result.add(mapOf("id" to "internal", "kind" to "internal", "label" to null,
            "total" to total, "free" to free))

        val sm = context.getSystemService(StorageManager::class.java)
        for (dir in context.getExternalFilesDirs(null)) {
            if (dir == null) continue
            val volume = try { sm?.getStorageVolume(dir) } catch (e: Exception) { null } ?: continue
            if (volume.isPrimary && !volume.isRemovable) continue          // এটি internal-এরই অংশ
            if (Environment.getExternalStorageState(dir) != Environment.MEDIA_MOUNTED) continue
            try {
                val fs = StatFs(dir.path)
                result.add(mapOf(
                    "id" to (volume.uuid ?: dir.path),
                    "kind" to if (volume.isRemovable) "removable" else "other",
                    "label" to volume.getDescription(context),
                    "total" to fs.totalBytes,
                    "free" to fs.availableBytes,
                ))
            } catch (e: Exception) {
                // ভলিউম পড়া না গেলে বাদ
            }
        }
        return result
    }

    fun internalFree(context: Context): Long =
        (storage(context).firstOrNull()?.get("free") as? Long) ?: 0L
}
