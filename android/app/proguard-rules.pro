# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Flutter deferred components reference Play Core, which we don't bundle.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# mobile_scanner / ML Kit barcode scanning
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# SQLCipher (sqflite_sqlcipher)
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

# flutter_secure_storage
-keep class androidx.security.crypto.** { *; }

# local_auth biometric
-keep class androidx.biometric.** { *; }
