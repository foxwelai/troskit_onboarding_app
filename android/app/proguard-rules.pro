# Ignore warnings during shrinking/optimization
-ignorewarnings
-dontwarn **

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

-keep class ai.foxwel.troskit_onboarding_app.** { *; }

# ML Kit / barcode (mobile_scanner)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_barcode.**
-keepclasseswithmembernames class * {
    native <methods>;
}

# Play Services / location
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.baseflow.geolocator.** { *; }
