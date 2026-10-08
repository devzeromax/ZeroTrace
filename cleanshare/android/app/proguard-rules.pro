# ZeroTrace release hardening — keep Flutter/plugin JNI and app entry points.

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

-keep class com.cleanshare.cleanshare.MainActivity { *; }
-keep class com.cleanshare.cleanshare.DeviceIntegrityHelper { *; }
-keep class com.cleanshare.cleanshare.SecureStoreHelper { *; }

-keep class androidx.security.crypto.** { *; }

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Flutter deferred components reference Play Core optionally — not bundled in sideload APK.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
