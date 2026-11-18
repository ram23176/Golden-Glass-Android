# Release বিল্ডে R8 অব্যবহৃত কোড মুছে ফেলে। নিচের ক্লাসগুলো reflection দিয়ে তৈরি হয়,
# তাই R8 বোঝে না যে এগুলো দরকার — মুছে ফেললে অ্যাপ চালু হতেই বন্ধ হয়ে যায়।

# WorkManager-এর ভেতরের Room ডেটাবেস (না রাখলে: NoSuchMethodException WorkDatabase_Impl.<init>)
-keep class * extends androidx.room.RoomDatabase { <init>(...); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# আমাদের নিজের Worker, Widget ও অন্যান্য native ক্লাস
-keep class io.github.ram23176.golden_glass.** { *; }
