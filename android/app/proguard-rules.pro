# Flutter / Dart エンジン（難読化で動作が壊れないように保持）
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core（遅延コンポーネント用・任意依存）。未使用でも Flutter エンベディングが参照するため R8 警告を抑制。
-dontwarn com.google.android.play.core.**

# Retrofit / JSON 等（将来のプラグイン追加時の保険）
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Kotlin メタデータ（リフレクション利用箇所の保険）
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Firebase / Crashlytics（R8 難読化時のクラッシュレポート送信）
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
