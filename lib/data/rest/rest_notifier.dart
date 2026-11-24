import 'package:flutter/services.dart';

/// Telefonda dinlenme bildirimi ve titreşimi (§16.2). Gerçeği Kotlin köprüsüyle konuşur
/// (MethodChannel `exercise_tracker/rest`, Kotlin: `android/app/src/main/kotlin/.../RestNotifications.kt`);
/// testlerde `FakeRestNotifier`. Hiçbir metot hata fırlatmaz; Android dışında ya da izin yoksa sessizce geçer.
abstract interface class RestNotifier {
  /// Kalıcı (kaydırılamaz) "Dinlenme" bildirimini gösterir ya da günceller: Android'in geri sayan kronometresi
  /// [endsAt]'e kadar sayar, süre dolunca bildirim kendiliğinden kalkar. Sesiz ve titreşimsizdir.
  /// [title] bildirimin başlığıdır (ör. antrenman adı).
  Future<void> showCountdown({required DateTime endsAt, required int totalSeconds, required String title});

  /// Geri sayım bildirimini kaldırır (atla, bitir, antrenman değişti).
  Future<void> cancel();

  /// Süre doldu: geri sayımı kaldırır; [vibrate] true ise "Dinlenme bitti" bildirimini titreşimle gösterir
  /// (bildirim izni yoksa yalnızca titrer). [vibrate] false ise hiçbir şey göstermez.
  Future<void> notifyFinished({required bool vibrate});

  /// Android 13+ bildirim iznini (POST_NOTIFICATIONS) bir kez ister; izin varsa ya da gerekmiyorsa `true`.
  /// İlk dinlenme başlatılırken çağrılır; reddedilirse tekrar sorulmaz (Android'in kendi kuralı).
  Future<bool> requestPermission();
}

/// MethodChannel `exercise_tracker/rest` metotları (Kotlin aynı adları uygular):
/// - `showCountdown` argüman `{"endsAtMillis": int (epoch ms), "totalSeconds": int, "title": String}`
/// - `cancel`
/// - `notifyFinished` argüman `{"vibrate": bool}`
/// - `requestPermission` → bool
class MethodChannelRestNotifier implements RestNotifier {
  static const MethodChannel _channel = MethodChannel('exercise_tracker/rest');

  @override
  Future<void> showCountdown({
    required DateTime endsAt,
    required int totalSeconds,
    required String title,
  }) =>
      _invoke('showCountdown', {
        'endsAtMillis': endsAt.millisecondsSinceEpoch,
        'totalSeconds': totalSeconds,
        'title': title,
      });

  @override
  Future<void> cancel() => _invoke('cancel');

  @override
  Future<void> notifyFinished({required bool vibrate}) =>
      _invoke('notifyFinished', {'vibrate': vibrate});

  @override
  Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Bildirim kanalı ya da izin yoksa sessizce geçilir.
    } on MissingPluginException {
      // Testlerde ya da Android dışı platformlarda kanal yok.
    }
  }
}
