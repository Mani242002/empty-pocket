# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native sqflite and local_auth classes
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
