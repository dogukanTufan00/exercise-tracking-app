import '../../domain/rest_timer.dart';

/// Çalışan dinlenme sayacının kalıcı kaydı (§16.2).
///
/// Hem uygulama (`RestController`) hem saat olaylarını işleyen `WatchSyncService` (ekransız motorda da) yazar;
/// bu yüzden gerçek uygulama her okumada diski okur (`SharedPreferences.reload()`), önbelleğe güvenmez.
/// Gerçeği `PrefsRestStore` (bu dosyada), testlerde `FakeRestStore` (`test/fakes/fake_rest_store.dart`).
abstract interface class RestStore {
  /// Kayıtlı sayaç; yoksa `null`. Süresi dolmuş kayıt da döner (temizlemek çağıranın işi).
  Future<RestState?> getRest();

  /// `null` kaydı siler.
  Future<void> setRest(RestState? rest);
}

// TODO(dalga 16, CB): PrefsRestStore — anahtar 'rest_active', değer RestState.toJson() JSON metni.
