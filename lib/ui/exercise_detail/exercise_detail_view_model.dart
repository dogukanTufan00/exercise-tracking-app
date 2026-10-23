import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/progress.dart';

/// Grafikte gösterilebilen metrikler (bkz. docs/ARCHITECTURE.md §12).
enum ProgressMetric {
  estimatedOneRepMax('Tahmini 1RM'),
  heaviest('En ağır'),
  volume('Hacim'),

  /// Yalnızca ağırlıksız hareketlerde kullanılır.
  reps('Tekrar');

  const ProgressMetric(this.label);

  /// Seçim düğmesinde görünen kısa ad.
  final String label;

  /// Değerin birimi; tekrar için yok.
  String? get unit => this == reps ? null : 'kg';

  /// Bir antrenmanın bu metrikteki değeri.
  double valueOf(SessionStats stats) {
    return switch (this) {
      estimatedOneRepMax => stats.bestEstimatedOneRepMax,
      heaviest => stats.heaviestKg,
      volume => stats.volumeKg,
      reps => stats.maxReps.toDouble(),
    };
  }
}

/// Hareket detay ekranının durumu: geçmiş, antrenman başına değerler, rekorlar ve seçili metrik.
class ExerciseDetailViewModel extends ChangeNotifier {
  ExerciseDetailViewModel(this._repository, {required Exercise exercise}) {
    _exercise = exercise;
  }

  final WorkoutRepository _repository;

  /// Detayı gösterilen hareket; düzenlenince güncellenir.
  late Exercise _exercise;

  List<ExerciseSession> _sessionsNewestFirst = const [];
  List<SessionStats> _stats = const [];
  PersonalRecords _records = PersonalRecords.empty;
  ProgressMetric _selectedMetric = ProgressMetric.estimatedOneRepMax;
  bool _isLoading = true;
  String? _errorMessage;
  bool _disposed = false;

  /// Detayı gösterilen hareket (güncel hali).
  Exercise get exercise => _exercise;

  /// Hareketin yapıldığı antrenmanlar, en yeni üstte (liste için).
  List<ExerciseSession> get sessionsNewestFirst => _sessionsNewestFirst;

  /// Antrenman başına değerler, en eskiden en yeniye (grafik için).
  List<SessionStats> get stats => _stats;

  PersonalRecords get records => _records;

  bool get isLoading => _isLoading;

  /// Gösterilmeyi bekleyen Türkçe hata mesajı; yoksa `null`.
  String? get errorMessage => _errorMessage;

  /// Hiç kayıtlı set yoksa `true`.
  bool get isEmpty => _stats.isEmpty;

  /// Tüm setler 0 kg ise `true` (barfiks gibi); grafik tekrarı gösterir.
  bool get isBodyweight =>
      _stats.isNotEmpty && _stats.every((s) => s.heaviestKg == 0);

  /// Seçim düğmesinde sunulan metrikler.
  List<ProgressMetric> get availableMetrics => isBodyweight
      ? const [ProgressMetric.reps]
      : const [
          ProgressMetric.estimatedOneRepMax,
          ProgressMetric.heaviest,
          ProgressMetric.volume,
        ];

  /// Grafikte gösterilen metrik.
  ProgressMetric get selectedMetric =>
      isBodyweight ? ProgressMetric.reps : _selectedMetric;

  /// Seçili metriğin antrenman başına değerleri, en eskiden en yeniye.
  List<double> get values => [
        for (final s in _stats) selectedMetric.valueOf(s),
      ];

  void selectMetric(ProgressMetric metric) {
    if (!availableMetrics.contains(metric) || metric == _selectedMetric) return;
    _selectedMetric = metric;
    _notify();
  }

  /// Hata mesajını temizler; ekran mesajı SnackBar ile gösterdikten sonra çağırır.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  /// Hareketi günceller. Başarılıysa `true`. Hata mesajları:
  /// aynı ad → 'Bu adda bir hareket zaten var.'; diğer → 'Hareket güncellenemedi.'
  Future<bool> updateExercise(String name, MuscleGroup muscleGroup) async {
    if (name.trim() == _exercise.name && muscleGroup == _exercise.muscleGroup) {
      return true;
    }

    try {
      _exercise = await _repository.updateExercise(
        _exercise.id,
        name: name,
        muscleGroup: muscleGroup,
      );
    } on DuplicateExerciseException {
      _errorMessage = 'Bu adda bir hareket zaten var.';
      _notify();
      return false;
    } catch (_) {
      _errorMessage = 'Hareket güncellenemedi.';
      _notify();
      return false;
    }

    _notify();
    return true;
  }

  /// Hareketin geçmişini repository'den okur ve değerleri hesaplar.
  Future<void> load() async {
    _isLoading = true;
    _notify();

    try {
      final history = await _repository.getExerciseHistory(_exercise.id);
      if (_disposed) return;
      _sessionsNewestFirst = history.reversed.toList();
      _stats = [for (final session in history) SessionStats.fromSession(session)];
      _records = PersonalRecords.fromStats(_stats);
    } on Exception {
      if (_disposed) return;
      _errorMessage = 'Hareket geçmişi yüklenemedi.';
    }

    _isLoading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
