import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/week_grouping.dart';

/// Geçmiş ekranının durumu: antrenman özetleri, yükleme ve hata bilgisi.
class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(this._repository);

  final WorkoutRepository _repository;

  List<WorkoutSummary> _workouts = const [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _disposed = false;

  /// Repository'nin döndürdüğü sırayla (en yeni üstte).
  List<WorkoutSummary> get workouts => _workouts;

  /// [workouts] Pazartesi–Pazar haftalarına göre gruplanmış hali (en yeni hafta üstte).
  List<WeekGroup> get weeks => groupByWeek(workouts);

  /// İlk yüklemede `true`; her [load] çağrısında da true olur.
  bool get isLoading => _isLoading;

  /// Gösterilmeyi bekleyen Türkçe hata mesajı; yoksa `null`.
  String? get errorMessage => _errorMessage;

  /// Hata mesajını temizler; ekran mesajı SnackBar ile gösterdikten sonra çağırır.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  /// Antrenman özetlerini repository'den yeniden okur.
  Future<void> load() async {
    _isLoading = true;
    _notify();

    try {
      final summaries = await _repository.getWorkoutSummaries();
      if (_disposed) return;
      _workouts = summaries;
    } on Exception {
      if (_disposed) return;
      _errorMessage = 'Antrenmanlar yüklenemedi.';
    }

    _isLoading = false;
    _notify();
  }

  /// Yeni (başlıksız) bir antrenman oluşturur ve id'sini döndürür; hata olursa `null`.
  Future<int?> startWorkout() async {
    try {
      final workout = await _repository.createWorkout();
      return workout.id;
    } on Exception {
      _errorMessage = 'Antrenman başlatılamadı.';
      _notify();
      return null;
    }
  }

  /// Antrenmanı repository'den siler ve listeden çıkarır.
  Future<void> deleteWorkout(int id) async {
    try {
      await _repository.deleteWorkout(id);
      if (_disposed) return;
      _workouts = [
        for (final summary in _workouts)
          if (summary.workout.id != id) summary,
      ];
    } on Exception {
      _errorMessage = 'Antrenman silinemedi.';
    }
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
