import '../models/models.dart';

/// Kullanıcı tercihleri. Uygulaması `shared_preferences` kullanır.
abstract interface class SettingsRepository {
  /// Kayıtlı tema; hiç seçilmemişse [AppThemeId.defaultTheme].
  Future<AppThemeId> getThemeId();

  Future<void> setThemeId(AppThemeId themeId);

  // ------------------------------------------------ Dinlenme (§16.2)
  // Saat olaylarını işleyen ekransız motor da okur/yazar: uygulama her okumada diski okumalıdır (reload).

  /// Dinlenme süresi (sn); hiç ayarlanmadıysa `restDefaultSeconds` (90). Her zaman 15–600 aralığında.
  Future<int> getRestSeconds();

  /// 15–600 aralığına sınırlayarak kaydeder.
  Future<void> setRestSeconds(int seconds);

  /// Dinlenme bitince telefon da titresin mi; varsayılan `true`.
  Future<bool> getRestVibrateOnPhone();

  Future<void> setRestVibrateOnPhone(bool value);

  // ------------------------------------------------ Yedek hatırlatması (§16.4)

  /// Son başarılı JSON yedeğinin zamanı; hiç alınmadıysa `null`.
  Future<DateTime?> getLastBackupAt();

  Future<void> setLastBackupAt(DateTime value);

  /// Hatırlatmanın en son kapatıldığı zaman; hiç kapatılmadıysa `null`.
  Future<DateTime?> getBackupReminderDismissedAt();

  Future<void> setBackupReminderDismissedAt(DateTime value);
}
