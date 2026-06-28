# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# MLKit Barcode Scanning
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# mobile_scanner plugin
-keep class dev.steenbakker.mobile_scanner.** { *; }

-dontwarn com.google.android.play.core.**
