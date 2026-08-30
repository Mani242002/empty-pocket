# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Native Plugins & SQLite
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-keep class flutter.overlay.window.flutter_overlay_window.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-dontwarn flutter.overlay.window.flutter_overlay_window.**
-dontwarn com.it_nomads.fluttersecurestorage.**
-dontwarn com.google.android.play.core.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn com.google.crypto.tink.**
