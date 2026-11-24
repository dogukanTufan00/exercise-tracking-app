import 'dart:async';

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

  static const String _title = 'Dinlenme';

  RestState? _rest;
  int _restSeconds = restDefaultSeconds;
  bool _vibrateOnPhone = true;
  Timer? _timer;
  StreamSubscription<void>? _subscription;
  bool _permissionAsked = false;
  bool _disposed = false;

  /// Çalışan sayaç; yoksa ya da süresi dolduysa `null`.
  RestState? get rest => _rest;

  /// Ayarlı süre (sn); [load]'dan önce `restDefaultSeconds`.
  int get restSeconds => _restSeconds;

  /// Dinlenme bitince telefon da titresin mi; [load]'dan önce `true`.
  bool get vibrateOnPhone => _vibrateOnPhone;

  /// Ayarları ve kayıtlı sayacı okur, bitiş zamanlayıcısını kurar, [WatchSyncService.restChanges]'i dinler.
  /// Uygulama açılışında bir kez çağrılır. Kayıtlı sayacın süresi dolmuşsa sessizce temizlenir.
  Future<void> load() async {
    await _guard('Dinlenme yüklenemedi', () async {
      await _readSettings();
      await _reload();
    });
    _subscription ??= watchSync?.restChanges.listen(
      (_) => unawaited(_guard('Saat dinlenmesi okunamadı', () async {
        await _readSettings();
        await _reload();
      })),
    );
    _notify();
  }

  /// [workoutId] için ayarlı süreyle yeni sayaç başlatır (çalışan varsa yerine geçer). "Set ekle"den sonra
  /// `WorkoutViewModel` çağırır. İlk seferde bildirim izni istenir.
  Future<void> start(int workoutId) async {
    await _guard('Dinlenme başlatılamadı', () async {
      if (!_permissionAsked) {
        _permissionAsked = true;
        await notifier.requestPermission();
      }
      final now = clock();
      final state = startRest(
        restId: 'phone-${now.microsecondsSinceEpoch}',
        workoutId: workoutId,
        startedAt: now,
        seconds: _restSeconds,
      );
      await store.setRest(state);
      await _showActive(state);
      await watchSync?.activeWorkoutChanged();
    });
    _notify();
  }

  /// Çalışan sayacı uzatır/kısaltır (±15 sn); sonuç bitmişse sayaç titreşimsiz biter. Sayaç yoksa bir şey yapmaz.
  Future<void> adjust(int deltaSeconds) async {
    await _guard('Dinlenme ayarlanamadı', () async {
      final current = await store.getRest();
      if (current == null) return;
      final next = adjustRest(current, deltaSeconds);
      if (isRestFinished(next, clock())) {
        await _clear();
      } else {
        await store.setRest(next);
        await _showActive(next);
      }
      await watchSync?.activeWorkoutChanged();
    });
    _notify();
  }

  /// Sayacı titreşimsiz durdurur.
  Future<void> skip() async {
    await _guard('Dinlenme atlanamadı', () async {
      await _clear();
      await watchSync?.activeWorkoutChanged();
    });
    _notify();
  }

  /// Sayaç [workoutId]'ye aitse titreşimsiz durdurur ("Bitir" ve antrenman silme için).
  Future<void> clearForWorkout(int workoutId) async {
    await _guard('Dinlenme temizlenemedi', () async {
      final current = await store.getRest();
      if (current == null || current.workoutId != workoutId) return;
      await _clear();
      await watchSync?.activeWorkoutChanged();
    });
    _notify();
  }

  /// Süre ayarını kaydeder (15–600'e sınırlar) ve saate yayınlar. Çalışan sayacı değiştirmez.
  Future<void> setRestSeconds(int seconds) async {
    await _guard('Dinlenme süresi kaydedilemedi', () async {
      final clamped = clampRestSeconds(seconds);
      await settings.setRestSeconds(clamped);
      _restSeconds = clamped;
      await watchSync?.restSettingsChanged();
    });
    _notify();
  }

  Future<void> setVibrateOnPhone(bool value) async {
    await _guard('Titreşim ayarı kaydedilemedi', () async {
      await settings.setRestVibrateOnPhone(value);
      _vibrateOnPhone = value;
    });
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }

  // ------------------------------------------------------------ Yardımcılar

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _guard(String label, Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      debugPrint('$label: $error');
    }
  }

  Future<void> _readSettings() async {
    _restSeconds = await settings.getRestSeconds();
    _vibrateOnPhone = await settings.getRestVibrateOnPhone();
  }

  /// Store'daki sayacı belleğe ve zamanlayıcıya yansıtır. Süresi dolmuş kayıt sessizce silinir.
  Future<void> _reload() async {
    var stored = await store.getRest();
    if (stored != null && isRestFinished(stored, clock())) {
      await store.setRest(null);
      stored = null;
    }
    if (stored == null) {
      final hadRest = _rest != null;
      _rest = null;
      _timer?.cancel();
      _timer = null;
      if (hadRest) await notifier.cancel();
    } else if (stored != _rest) {
      await _showActive(stored);
    } else {
      _scheduleTimer(stored);
    }
    _notify();
  }

  /// [state] çalışan sayaç olur: bellek, zamanlayıcı ve geri sayım bildirimi.
  Future<void> _showActive(RestState state) async {
    _rest = state;
    _scheduleTimer(state);
    await notifier.showCountdown(
      endsAt: state.endsAt,
      totalSeconds: state.totalSeconds,
      title: _title,
    );
  }

  /// Sayacı titreşimsiz temizler: store, zamanlayıcı, bildirim.
  Future<void> _clear() async {
    await store.setRest(null);
    _rest = null;
    _timer?.cancel();
    _timer = null;
    await notifier.cancel();
  }

  void _scheduleTimer(RestState state) {
    _timer?.cancel();
    final remaining = restRemaining(state, clock());
    _timer = Timer(remaining, () => unawaited(_onTimerFired()));
  }

  /// Süre doldu: sayaç hâlâ aynıysa temizler, titreşim/bildirim gösterir ve saate haber verir.
  Future<void> _onTimerFired() async {
    _timer = null;
    await _guard('Dinlenme bitişi işlenemedi', () async {
      final current = _rest;
      final stored = await store.getRest();
      if (current == null ||
          stored == null ||
          stored.restId != current.restId ||
          !isRestFinished(stored, clock())) {
        // Sayaç bu arada değişmiş (saat ya da başka bir işlem): store'u yeniden oku.
        await _reload();
        return;
      }
      await store.setRest(null);
      _rest = null;
      await notifier.notifyFinished(vibrate: _vibrateOnPhone);
      await watchSync?.activeWorkoutChanged();
    });
    _notify();
  }
}
