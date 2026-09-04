# R8 is enabled on the release build (see build.gradle.kts). Flutter's own
# Dart code is AOT compiled into libapp.so and is untouched by this; what
# R8 sees is the Java/Kotlin shim around it, plus whatever the plugins
# bring with them.
#
# Flutter's embedding is reached by reflection from native code, so it has
# to be kept by name or the app fails at launch rather than at build time.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core is referenced by Flutter's deferred-components support, which
# this app does not use. Without this R8 warns about the missing classes
# and fails the build.
-dontwarn com.google.android.play.core.**

# Keep the line numbers so a crash report from a tester is still readable,
# and rename the source file so the mapping is not given away for free.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
