import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/prefs_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('boşken varsayılan tema döner', () async {
    final repository = PrefsSettingsRepository();

    expect(await repository.getThemeId(), AppThemeId.defaultTheme);
  });

  test('kaydedilen tema aynen okunur', () async {
    final repository = PrefsSettingsRepository();

    await repository.setThemeId(AppThemeId.yellowNavy);

    expect(await repository.getThemeId(), AppThemeId.yellowNavy);
  });

  test('tanınmayan kayıtlı değer varsayılan temaya düşer', () async {
    SharedPreferences.setMockInitialValues({'theme_id': 'bilinmeyen_tema'});
    final repository = PrefsSettingsRepository();

    expect(await repository.getThemeId(), AppThemeId.defaultTheme);
  });
}
