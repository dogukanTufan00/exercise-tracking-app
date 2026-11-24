import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

/// [RestStore]'un `shared_preferences` uygulaması: anahtar `rest_active`, değer [RestState.toJson] JSON metni.
class PrefsRestStore implements RestStore {
  static const String _key = 'rest_active';

  @override
  Future<RestState?> getRest() async {
    final prefs = await SharedPreferences.getInstance();
    // Saat olaylarını arka planda işleyen ekransız motor da yazar; önbellek değil disk okunur.
    await prefs.reload();
    final text = prefs.getString(_key);
    if (text == null) return null;
    try {
      return RestState.fromJson(jsonDecode(text) as Map<String, Object?>);
    } catch (_) {
      // Bozuk kayıt sayaç sayılmaz.
      return null;
    }
  }

  @override
  Future<void> setRest(RestState? rest) async {
    final prefs = await SharedPreferences.getInstance();
    if (rest == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(rest.toJson()));
    }
  }
}
