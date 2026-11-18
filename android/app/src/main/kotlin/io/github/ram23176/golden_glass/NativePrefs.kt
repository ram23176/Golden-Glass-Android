package io.github.ram23176.golden_glass

import android.content.Context
import android.content.SharedPreferences

/**
 * Native অংশের নিজস্ব ছোট সেটিংস — অ্যাপ বন্ধ থাকলেও (WorkManager / Widget) এগুলো পড়া যায়।
 * Dart-এর মূল সেটিংস আলাদা জায়গায় থাকে; দরকারি অংশটুকু Dart এখানে পাঠিয়ে দেয়।
 */
object NativePrefs {
    private const val NAME = "gg_native"

    const val POOL = "pool"            // JSON array: ওয়ালপেপার ফাইলের পাথ
    const val SHUFFLE = "shuffle"
    const val TARGET = "target"        // home | lock | both
    const val FIT = "fit"              // auto | fill | fit
    const val LAST_PATH = "last_path"  // সর্বশেষ সেট করা ওয়ালপেপার
    const val ACCENT = "accent"        // উইজেটের রং (ARGB int)
    const val LABEL_FREE = "label_free"
    const val LABEL_NEXT = "label_next"

    fun get(context: Context): SharedPreferences =
        context.getSharedPreferences(NAME, Context.MODE_PRIVATE)
}
