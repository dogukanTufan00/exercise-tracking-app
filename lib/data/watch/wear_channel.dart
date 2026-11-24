import 'package:flutter/services.dart';

/// Telefonun Kotlin köprüsüyle (Wearable Data Layer) konuşan kanal (bkz. docs/ARCHITECTURE.md §15.5).
///
/// [WatchSyncService] bu arayüzü kullanır; testlerde `FakeWearChannel` verilir.
/// Eşli saat ya da Play Services yoksa çağrılar sessizce hiçbir şey yapmaz (hata fırlatmaz).
abstract interface class WearChannel {
  /// Anlık durum JSON'unu `/workout/active` DataItem'ına yazar (öncekinin yerine).
  Future<void> publishSnapshot(String json);

  /// `/workout/active` DataItem'ını siler (saat boş durumu gösterir).
  Future<void> clearSnapshot();

  /// Etkin program JSON'unu `/program/active` DataItem'ına yazar (§15.8).
  Future<void> publishProgram(String json);

  /// `/program/active` DataItem'ını siler (etkin program yok).
  Future<void> clearProgram();

  /// İşlenmiş olay id'leri JSON'unu `/events/applied` DataItem'ına yazar (§15.8).
  Future<void> publishApplied(String json);

  /// Seçili temanın adını (`AppThemeId.name`) `/settings/theme` DataItem'ına yazar.
  Future<void> publishTheme(String themeId);

  /// Dinlenme süresini (sn) `/settings/rest` DataItem'ına `restSeconds` (int) olarak yazar (§16.2).
  Future<void> publishRestSettings(int restSeconds);

  /// Kuyruktaki, henüz onaylanmamış olayların ham JSON metinleri (gelme sırasıyla). Kuyruktan silmez.
  Future<List<String>> drainEvents();

  /// Verilen id'li olayları kuyruktan siler.
  Future<void> ackEvents(List<String> eventIds);

  /// Kuyruğa yeni olay eklenince bir değer yayar.
  Stream<void> get eventsAvailable;
}

/// [WearChannel]'ın gerçek uygulaması.
///
/// Kotlin tarafı (`android/app/src/main/kotlin/.../MainActivity.kt`) şu adları uygular:
/// - MethodChannel `exercise_tracker/wear`:
///   `publishSnapshot` (argüman: String), `clearSnapshot`, `publishTheme` (argüman: String),
///   `publishProgram` (argüman: String), `clearProgram`, `publishApplied` (argüman: String),
///   `publishRestSettings` (argüman: int),
///   `drainEvents` (döner: `List<String>`),
///   `ackEvents` (argüman: `List<String>`)
/// - EventChannel `exercise_tracker/wear/events`: kuyruğa olay eklenince `null` yayar.
class MethodChannelWearChannel implements WearChannel {
  static const MethodChannel _methods = MethodChannel('exercise_tracker/wear');
  static const EventChannel _events = EventChannel('exercise_tracker/wear/events');

  @override
  Future<void> publishSnapshot(String json) => _call('publishSnapshot', json);

  @override
  Future<void> clearSnapshot() => _call('clearSnapshot');

  @override
  Future<void> publishProgram(String json) => _call('publishProgram', json);

  @override
  Future<void> clearProgram() => _call('clearProgram');

  @override
  Future<void> publishApplied(String json) => _call('publishApplied', json);

  @override
  Future<void> publishTheme(String themeId) => _call('publishTheme', themeId);

  @override
  Future<void> publishRestSettings(int restSeconds) => _call('publishRestSettings', restSeconds);

  @override
  Future<List<String>> drainEvents() async {
    try {
      final result = await _methods.invokeListMethod<String>('drainEvents');
      return result ?? const <String>[];
    } on PlatformException {
      return const <String>[];
    } on MissingPluginException {
      return const <String>[];
    }
  }

  @override
  Future<void> ackEvents(List<String> eventIds) => _call('ackEvents', eventIds);

  @override
  Stream<void> get eventsAvailable => _events
      .receiveBroadcastStream()
      .map<void>((_) {})
      .handleError((Object _) {}, test: (error) => error is PlatformException || error is MissingPluginException);

  Future<void> _call(String method, [Object? arguments]) async {
    try {
      await _methods.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Saat yok ya da Play Services erişilemiyor: telefon uygulaması etkilenmez.
    } on MissingPluginException {
      // Testlerde ya da Android dışı platformlarda kanal yok.
    }
  }
}
