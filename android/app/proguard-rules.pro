# Release derlemesinde R8, kullanılmadığını düşündüğü kodu siler ve sınıf/metot adlarını kısaltır.
# Aşağıdaki sınıflar Dart'tan JNI ile doğrudan, adlarıyla çağrılır; R8 bu çağrıları göremez.
# Kural olmadan uygulama açılışta "NoSuchMethodError ... SharedPreferencesApiRegistrar.getAll"
# hatasıyla takılır (v0.1.0 ve v0.2.0-beta.1).

# shared_preferences_android (tema seçimi)
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# path_provider_android (yedek dosyaları)
-keep class io.flutter.plugins.pathprovider.** { *; }

# package:jni'nin Android tarafı
-keep class com.github.dart_lang.jni.** { *; }

# JNI çağrıları Kotlin sınıflarını da tam adlarıyla kullanır: `suspend` metotlarının
# kotlin.coroutines.Continuation parametresi, sonuçlar için kotlin.Result vb. R8 bunları
# silerse ya da adlarını kısaltırsa (ör. Continuation → "a5") Dart onları bulamaz.
# Tek tek eklemek yerine Kotlin standart kütüphanesi ve coroutine'ler bütünüyle korunur.
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
