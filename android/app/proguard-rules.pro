# Troskit Onboarding — R8 / ProGuard rules (release)

-ignorewarnings
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Flutter ──────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# App package
-keep class ai.foxwel.troskitOnboardingApp.** { *; }

# ── Native methods ───────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── ML Kit / mobile_scanner (barcode) ────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.vision.barcode.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.mlkit.common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_barcode.**
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.android.gms.internal.mlkit_**

# CameraX (used by mobile_scanner on many devices)
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ── Play Services / Geolocator ───────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ── image_picker ─────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ── path_provider / shared_preferences ───────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── audioplayers ─────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ── gal (save to gallery) ────────────────────────────────
-keep class studio.midoridesign.gal.** { *; }
-dontwarn studio.midoridesign.gal.**

# ── OkHttp / HTTP (http package) ─────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ── Kotlin / coroutines ──────────────────────────────────
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**
-keep class kotlin.Metadata { *; }

# ── Desugar / multidex ───────────────────────────────────
-dontwarn com.android.tools.r8.**
-keep class androidx.multidex.** { *; }

# ── Google Play In-App Updates ───────────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-keep class de.jonasbark.inappupdate.** { *; }
-dontwarn de.jonasbark.inappupdate.**

# ── Image compression ────────────────────────────────────
-keep class com.example.flutterimagecompress.** { *; }
-dontwarn com.example.flutterimagecompress.**
