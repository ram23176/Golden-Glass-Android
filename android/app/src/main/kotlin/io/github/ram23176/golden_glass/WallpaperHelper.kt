package io.github.ram23176.golden_glass

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.hardware.display.DisplayManager
import android.media.ExifInterface
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * ছবি ফাইল → Home / Lock screen ওয়ালপেপার।
 * fit:
 *   "fill" — স্ক্রিন ভরে দেয় (মাঝখান থেকে কেটে)
 *   "fit"  — পুরো ছবি দেখায়, ফাঁকা জায়গায় একই ছবির ঝাপসা রূপ
 *   "auto" — আড়াআড়ি (landscape) ছবি হলে fit, লম্বালম্বি হলে fill
 * বড় ছবি আগেই ছোট করে পড়া হয় যাতে মেমরি শেষ না হয়।
 */
object WallpaperHelper {
    private const val TAG = "GoldenGlass"

    fun apply(context: Context, path: String, target: String, fit: String = "auto"): Boolean {
        val file = File(path)
        if (!file.isFile) return false
        val (screenW, screenH) = screenSize(context)

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return false

        val rotation = exifRotation(path)
        val srcW = if (rotation % 180 == 0) bounds.outWidth else bounds.outHeight
        val srcH = if (rotation % 180 == 0) bounds.outHeight else bounds.outWidth
        val useFit = when (fit) {
            "fit" -> true
            "fill" -> false
            else -> srcW > srcH
        }

        // যতটুকু বড় দেখাতে হবে তার চেয়ে ছোট না করে যতটা সম্ভব ছোট করে পড়া
        val needScale = if (useFit) min(screenW.toFloat() / srcW, screenH.toFloat() / srcH)
                        else max(screenW.toFloat() / srcW, screenH.toFloat() / srcH)
        var sample = 1
        while (1f / (sample * 2) >= needScale) sample *= 2

        val decoded = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: return false
        val upright = rotate(decoded, rotation)
        val finalBitmap = if (useFit) fitWithBlur(upright, screenW, screenH) else centerCrop(upright, screenW, screenH)

        val flags = when (target) {
            "home" -> WallpaperManager.FLAG_SYSTEM
            "lock" -> WallpaperManager.FLAG_LOCK
            else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
        }
        return try {
            WallpaperManager.getInstance(context).setBitmap(finalBitmap, null, true, flags) != 0
        } catch (e: Exception) {
            Log.e(TAG, "setBitmap failed", e)
            false
        } finally {
            finalBitmap.recycle()
        }
    }

    /** ফোনের আসল স্ক্রিন সাইজ (পোর্ট্রেট ধরে)। */
    @Suppress("DEPRECATION")
    private fun screenSize(context: Context): Pair<Int, Int> {
        val dm = context.getSystemService(DisplayManager::class.java)
        val metrics = DisplayMetrics()
        dm?.getDisplay(Display.DEFAULT_DISPLAY)?.getRealMetrics(metrics)
        var w = metrics.widthPixels
        var h = metrics.heightPixels
        if (w <= 0 || h <= 0) {
            w = context.resources.displayMetrics.widthPixels
            h = context.resources.displayMetrics.heightPixels
        }
        return Pair(min(w, h).coerceAtLeast(480), max(w, h).coerceAtLeast(800))
    }

    private fun exifRotation(path: String): Int = try {
        when (ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90
            ExifInterface.ORIENTATION_ROTATE_180 -> 180
            ExifInterface.ORIENTATION_ROTATE_270 -> 270
            else -> 0
        }
    } catch (e: Exception) {
        0
    }

    private fun rotate(src: Bitmap, degrees: Int): Bitmap {
        if (degrees == 0) return src
        val m = Matrix().apply { postRotate(degrees.toFloat()) }
        val out = Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
        if (out !== src) src.recycle()
        return out
    }

    /** স্ক্রিনের অনুপাতে মাঝখান থেকে কেটে স্ক্রিন সাইজে আনে (ছবি টানা/চ্যাপ্টা হয় না)। */
    private fun centerCrop(src: Bitmap, targetW: Int, targetH: Int): Bitmap {
        val scale = max(targetW.toFloat() / src.width, targetH.toFloat() / src.height)
        val cropW = (targetW / scale).roundToInt().coerceIn(1, src.width)
        val cropH = (targetH / scale).roundToInt().coerceIn(1, src.height)
        val x = (src.width - cropW) / 2
        val y = (src.height - cropH) / 2
        val cropped = Bitmap.createBitmap(src, x, y, cropW, cropH)
        val scaled = Bitmap.createScaledBitmap(cropped, targetW, targetH, true)
        if (cropped !== scaled && cropped !== src) cropped.recycle()
        if (src !== scaled) src.recycle()
        return scaled
    }

    /** পুরো ছবি মাঝখানে; পেছনে একই ছবি বড় করে, ঝাপসা ও একটু অন্ধকার করে। */
    private fun fitWithBlur(src: Bitmap, targetW: Int, targetH: Int): Bitmap {
        val out = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)

        // খুব ছোট করে আবার বড় করলে মসৃণ ঝাপসা ভাব আসে (দুই ধাপে — দাগ কম হয়)
        val tiny = Bitmap.createScaledBitmap(src, max(1, src.width / 32), max(1, src.height / 32), true)
        val soft = Bitmap.createScaledBitmap(tiny, max(1, tiny.width * 4), max(1, tiny.height * 4), true)
        val coverScale = max(targetW.toFloat() / soft.width, targetH.toFloat() / soft.height)
        val bw = soft.width * coverScale
        val bh = soft.height * coverScale
        canvas.drawBitmap(soft, null, RectF((targetW - bw) / 2, (targetH - bh) / 2, (targetW + bw) / 2, (targetH + bh) / 2), paint)
        canvas.drawColor(0x59000000)

        val fitScale = min(targetW.toFloat() / src.width, targetH.toFloat() / src.height)
        val fw = src.width * fitScale
        val fh = src.height * fitScale
        canvas.drawBitmap(src, null, RectF((targetW - fw) / 2, (targetH - fh) / 2, (targetW + fw) / 2, (targetH + fh) / 2), paint)

        if (soft !== tiny) soft.recycle()
        tiny.recycle()
        src.recycle()
        return out
    }
}
