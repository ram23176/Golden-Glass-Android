# Golden Glass — Android

Golden Glass Desktop-এর Android সংস্করণ (Flutter + Kotlin)। সোনালি কাচের থিম, ওয়ালপেপার,
হোম স্ক্রিন উইজেট আর সিস্টেম মনিটর। বাংলা ও English দুই ভাষাতেই চলে।

- **প্রয়োজন:** Android 8.0 (API 26) বা নতুন
- **তৈরি APK:** `release/GoldenGlass-Android-1.0.0.apk` (SHA-256 পাশের `.sha256.txt` ফাইলে)

## ফিচার

| অংশ | কী করে |
|---|---|
| হোম | শুভেচ্ছা, লাইভ ঘড়ি ও বাংলা তারিখ, ব্যাটারি/RAM/খালি জায়গা, বর্তমান ওয়ালপেপার, দ্রুত কাজ |
| ওয়ালপেপার | অ্যাপের ২টি ছবি + গ্যালারি থেকে নিজের ছবি যোগ, প্রিয়, Home / Lock / দুটোতেই সেট, বসানোর ধরন (স্বয়ংক্রিয় / স্ক্রিন ভরে / পুরো ছবি) |
| স্বয়ংক্রিয় বদল | ১৫ মিনিট থেকে ১ দিন পরপর, এলোমেলো ক্রম, শুধু প্রিয় থেকে। অ্যাপ বন্ধ থাকলেও আর রিস্টার্টের পরেও চলে (WorkManager) |
| থিম | ৭টি তৈরি থিম, ডার্ক/লাইট, নিজের থিম (৮টি রং, রং বাছাই), থিম ফাইল import/export। **Windows ভার্সনের থিম ফাইলও চলে** |
| সিস্টেম | ব্যাটারি (চার্জ, তাপমাত্রা, ভোল্টেজ, স্বাস্থ্য), RAM, স্টোরেজ (ফোন + SD কার্ড/USB, রঙের সীমা বদলানো যায়), ডিভাইসের তথ্য |
| উইজেট | হোম স্ক্রিনে ঘড়ি + তারিখ + ব্যাটারি + খালি জায়গা + ⏭ পরের ওয়ালপেপার বাটন, থিমের রঙে |
| চেহারা | কার্ডের স্বচ্ছতা, কোণ, আভা, অ্যানিমেশনের গতি, ঝাপসা ওয়ালপেপার ব্যাকগ্রাউন্ড |
| ব্যাকআপ | সব সেটিংস ও নিজের থিম একটি .json ফাইলে সংরক্ষণ ও ফেরত (ছবি নিজে ব্যাকআপে থাকে না) |

Windows ভার্সনের যেসব ফিচার Android-এ **সম্ভব নয়**, তাই নেই: ফোল্ডারের রং, ড্রাইভ আইকন,
Explorer right-click মেনু, System Tray, Windows startup।

## ফোনে ইনস্টল

1. `release/GoldenGlass-Android-1.0.0.apk` ফাইলটি ফোনে পাঠান (USB, Google Drive, Telegram ইত্যাদি)।
2. ফোনে ফাইলটিতে চাপ দিন। প্রথমবার Android জিজ্ঞেস করবে "Install unknown apps" অনুমতি দেবেন কিনা।
   যে অ্যাপ দিয়ে খুলছেন (Files / Chrome) সেটির জন্য অনুমতি দিন।
3. Play Protect সতর্কবার্তা দেখালে "More details → Install anyway" বেছে নিন।
   (অ্যাপটি Play Store-এ নেই বলে এটা দেখায়।)

## নিজে বিল্ড করা

```powershell
cd "d:\pc app\Golden Glass Android"
flutter pub get
flutter analyze          # কোডে ভুল আছে কিনা
flutter test             # ২০টি টেস্ট
flutter build apk --release
# ফল: build\app\outputs\flutter-apk\app-release.apk
```

ফোন USB-তে লাগিয়ে (Developer options → USB debugging চালু) সরাসরি চালাতে: `flutter run`

নতুন ভার্সন বানালে `pubspec.yaml`-এর `version: 1.0.0+1` বাড়ান (যেমন `1.0.1+2`; `+` এর পরের
সংখ্যা অবশ্যই বাড়াতে হবে), আর `lib/core/app_info.dart`-এর `appVersion` মিলিয়ে দিন। একটা টেস্ট দুটো মিলিয়ে দেখে।

## ⚠ সাইন করার চাবি (খুব জরুরি)

APK সাইন হয় `android/keystore/golden-glass-release.jks` দিয়ে। পাসওয়ার্ড আছে `android/key.properties`-এ।
দুটোই git-এ যায় না (`.gitignore`)।

- **এই দুটো ফাইল নিরাপদ জায়গায় ব্যাকআপ রাখুন** (পেনড্রাইভ / নিজের Google Drive)।
- চাবি হারালে ফোনে ইনস্টল করা অ্যাপের উপর নতুন ভার্সন আপডেট হবে না। তখন পুরনো অ্যাপ মুছে
  নতুন করে ইনস্টল করতে হবে (সেটিংস হারাবে, আগে ব্যাকআপ নিন)।
- এই ফাইল কাউকে দেবেন না, কোথাও আপলোড করবেন না।
- `key.properties` না থাকলে বিল্ড debug চাবিতে সাইন হয় (শুধু পরীক্ষার জন্য)।

## ফোল্ডার গঠন

```
lib/
  main.dart                 অ্যাপের শুরু
  core/                     থিম/রঙের হিসাব, সেটিংস (AppState), বাংলা/English লেখা
  services/                 native.dart (Kotlin-এর সাথে যোগাযোগ), wallpaper_store.dart
  ui/                       কাচের কার্ড, বাটন, রং বাছাই
  pages/                    প্রতিটি পেজ
android/app/src/main/kotlin/…/golden_glass/
  MainActivity.kt           Dart ↔ Android সেতু
  WallpaperHelper.kt        ছবি → ওয়ালপেপার (মাপমতো কাটা / ঝাপসা পেছনসহ পুরো ছবি)
  AutoChanger.kt            স্বয়ংক্রিয় বদল (WorkManager)
  SystemInfo.kt             ব্যাটারি, RAM, স্টোরেজ, ডিভাইস
  GlassClockWidget.kt       হোম স্ক্রিন উইজেট
android/app/proguard-rules.pro   release বিল্ডে দরকারি ক্লাস যেন মুছে না যায়
test/                       ইউনিট টেস্ট + সব পেজ খোলার UI টেস্ট
```

## জানা সীমাবদ্ধতা

- স্বয়ংক্রিয় বদল সবচেয়ে কম ১৫ মিনিট পরপর (Android-এর নিয়ম)। ব্যাটারি সেভার / Doze-এ কিছুটা দেরি হতে পারে।
  কিছু কোম্পানির ফোনে (Xiaomi, Oppo, Vivo, Realme…) অ্যাপের Battery setting "No restrictions" করতে হতে পারে।
- উইজেটের ঘড়ি সবসময় সঠিক থাকে। ব্যাটারি/খালি জায়গা ১৫ মিনিট পরপর, ওয়ালপেপার বদলালে আর অ্যাপ খুললে হালনাগাদ হয়।
- CPU ব্যবহারের শতাংশ দেখানো হয় না, কারণ Android 8-এর পর থেকে সাধারণ অ্যাপ এটা পড়তে পারে না।
- APK-তে তিন ধরনের প্রসেসরের কোড একসাথে থাকে বলে আকার ~৫২ MB। শুধু আধুনিক ফোনের জন্য ছোট APK চাইলে:
  `flutter build apk --release --split-per-abi` (তখন `app-arm64-v8a-release.apk` অনেক ছোট)।
- প্রজেক্ট D: ড্রাইভে আর Flutter প্যাকেজ C: ড্রাইভে থাকায় `android/gradle.properties`-এ
  `kotlin.incremental=false` রাখা আছে — এটা সরালে বিল্ড ভেঙে যাবে।

লাইসেন্স: MIT (Windows ভার্সনের মতোই)।
