import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Alt gezinme çubuğunun sekme tanımı. Ekranlar bunu `app_shell.dart` yerine buradan import eder;
// böylece kabuk ile ekranlar arasında döngüsel import oluşmaz.

/// Alt gezinme çubuğunun sekmeleri; sıra [NavigationBar] sırasıdır.
enum AppTab { workouts, program, exercises, profile }

/// Aktif sekmeyi tutar. Sekme değişince ve aynı sekme yeniden seçilince dinleyicilere haber verir.
///
/// Yalnızca değer değiştiğinde bildiren [ValueNotifier]'ın aksine, aynı sekmeye dönüşte de bildirir;
/// böylece ekranlar "sekmeye dönünce" yenilenebilir.
class AppTabNotifier extends ValueNotifier<AppTab> {
  AppTabNotifier(super.value);

  /// Sekmeyi seçer. Zaten seçiliyse yalnızca dinleyicilere haber verir.
  void select(AppTab tab) {
    if (value == tab) {
      notifyListeners();
    } else {
      value = tab;
    }
  }
}

/// Aktif sekmeyi alt ağaca sağlar; ekranlar [maybeOf] ile bulur.
class AppTabScope extends InheritedWidget {
  const AppTabScope({
    super.key,
    required this.notifier,
    required super.child,
  });

  final AppTabNotifier notifier;

  /// Seçili sekmeyi izlemek için [ValueListenable]; uygulama kökü dışında (tek başına test) `null`.
  static ValueListenable<AppTab>? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<AppTabScope>()
        ?.notifier;
  }

  @override
  bool updateShouldNotify(AppTabScope oldWidget) => notifier != oldWidget.notifier;
}
