import 'package:flutter/foundation.dart';

import '../../domain/rest_timer.dart';
import '../repositories/settings_repository.dart';
import '../watch/watch_sync_service.dart';
import 'rest_notifier.dart';
import 'rest_store.dart';

/// Telefon uygulamasındaki dinlenme sayacı (§16.2). Uygulama boyunca tek örnek (`main.dart`,
/// `ChangeNotifierProvider<RestController>`); ekransız motorda kullanılmaz.
///
/// - Durum [RestStore]'dadır; saat olaylarıyla değişince [WatchSyncService.restChanges] haber verir ve
///   denetleyici yeniden okur. Kendi değişikliklerinden sonra [WatchSyncService.activeWorkoutChanged] ile
///   saate yayınlar.
/// - Bitişte bir [Timer] çalışır: süre dolunca [RestNotifier.notifyFinished] (titreşim [vibrateOnPhone]'a göre),
///   [rest] `null` olur ve dinleyicilere haber verilir. Sayaç başlayınca / değişince geri sayım bildirimi
///   güncellenir.
/// - Saniyelik ekran tazelemesini ekran yapar ([rest] ve [clock] ile kalan süreyi hesaplar); denetleyici yalnızca
///   durum değişince bildirir.
/// - Hata fırlatmaz; sorunlar `debugPrint` ile yazılır.
class RestController extends ChangeNotifier {
  RestController({
    required this.store,
    required this.settings,
    required this.notifier,
    this.watchSync,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final RestStore store;
  final SettingsRepository settings;
  final RestNotifier notifier;

  /// Testlerde ve saatsiz kurulumda `null`.
  final WatchSyncService? watchSync;
  final DateTime Function() clock;

  /// Çalışan sayaç; yoksa ya da süresi dolduysa `null`.
  RestState? get rest => throw UnimplementedError();

  /// Ayarlı süre (sn); [load]'dan önce `restDefaultSeconds`.
  int get restSeconds => throw UnimplementedError();

  /// Dinlenme bitince telefon da titresin mi; [load]'dan önce `true`.
  bool get vibrateOnPhone => throw UnimplementedError();

  /// Ayarları ve kayıtlı sayacı okur, bitiş zamanlayıcısını kurar, [WatchSyncService.restChanges]'i dinler.
  /// Uygulama açılışında bir kez çağrılır. Kayıtlı sayacın süresi dolmuşsa sessizce temizlenir.
  Future<void> load() => throw UnimplementedError();

  /// [workoutId] için ayarlı süreyle yeni sayaç başlatır (çalışan varsa yerine geçer). "Set ekle"den sonra
  /// `WorkoutViewModel` çağırır. İlk seferde bildirim izni istenir.
  Future<void> start(int workoutId) => throw UnimplementedError();

  /// Çalışan sayacı uzatır/kısaltır (±15 sn); sonuç bitmişse sayaç titreşimsiz biter. Sayaç yoksa bir şey yapmaz.
  Future<void> adjust(int deltaSeconds) => throw UnimplementedError();

  /// Sayacı titreşimsiz durdurur.
  Future<void> skip() => throw UnimplementedError();

  /// Sayaç [workoutId]'ye aitse titreşimsiz durdurur ("Bitir" ve antrenman silme için).
  Future<void> clearForWorkout(int workoutId) => throw UnimplementedError();

  /// Süre ayarını kaydeder (15–600'e sınırlar) ve saate yayınlar. Çalışan sayacı değiştirmez.
  Future<void> setRestSeconds(int seconds) => throw UnimplementedError();

  Future<void> setVibrateOnPhone(bool value) => throw UnimplementedError();
}
