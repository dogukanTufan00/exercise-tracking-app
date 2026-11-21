import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'watch_sync_service.dart';

/// Telefon uygulaması kapalıyken saat olaylarını işleyen ekransız çalışma (bkz. docs/ARCHITECTURE.md §15.5).
///
/// Android'deki `WearBackgroundRunner`, saatten olay gelip uygulama açık değilse ekransız bir Flutter motoru
/// başlatır ve `main.dart`'taki `wearBackgroundMain` giriş noktasını çalıştırır. O da bu fonksiyonu çağırır:
/// kuyruktaki olaylar uygulamadaki aynı [WatchSyncService] mantığıyla işlenir (anlık durum ve işlenen olaylar
/// saate yayınlanır), sonra [onDone] ile motorun kapatılması istenir. Hata olsa da [onDone] mutlaka çağrılır.
Future<void> runWearBackground({
  required WatchSyncService service,
  required Future<void> Function() onDone,
}) async {
  try {
    await service.processPendingEvents();
  } catch (error) {
    debugPrint('Arka planda saat olayları işlenemedi: $error');
  } finally {
    await service.dispose();
    await onDone();
  }
}

/// Android tarafına "arka plan işi bitti" der; motor kapatılır. Kanal yoksa (testler) sessizce geçer.
Future<void> notifyWearBackgroundDone() async {
  try {
    await const MethodChannel('exercise_tracker/wear').invokeMethod<void>('backgroundDone');
  } on MissingPluginException {
    // Kanal yok: yapılacak bir şey yok.
  } on PlatformException catch (error) {
    debugPrint('Arka plan bitişi bildirilemedi: $error');
  }
}
