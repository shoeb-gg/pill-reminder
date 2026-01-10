# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Timezone
-keep class org.threeten.** { *; }
-keep class com.jakewharton.threetenabp.** { *; }

# Keep timezone data
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
