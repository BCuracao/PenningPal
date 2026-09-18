# Keep Hive models & adapters
-keep class io.hive.** { *; }
-keep class * extends io.hive.TypeAdapter { *; }

# Keep RevenueCat Purchases SDK
-keep class com.revenuecat.purchases.** { *; }

# Play Billing interfaces used by RevenueCat for anonymous receipt validation
-keep class com.android.billingclient.** { *; }
-dontwarn com.revenuecat.purchases.**
-dontwarn io.hive.**
