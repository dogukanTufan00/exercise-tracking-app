import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';

/// Hareketler ekranının durumu: arama sorgusu ve katalogdaki hareketlerin listesi.
class ExercisesViewModel extends ChangeNotifier {
  ExercisesViewModel(this._repository);

  final WorkoutRepository _repository;

  String _query = '';
  List<Exercise> _exercises = const [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  /// Her aramaya artan bir numara verilir; yalnızca en son aramanın yanıtı kabul edilir.
  int _latestRequestId = 0;

  /// Kullanıcının yazdığı arama metni.
  String get query => _query;

  /// Son (en güncel) aramanın sonuçları.
  List<Exercise> get exercises => _exercises;

  bool get isLoading => _isLoading;

  /// Ekranda gösterilecek hata; gösterildikten sonra [clearError] ile temizlenmeli.
  String? get errorMessage => _errorMessage;

  /// Tüm kataloğu getirir (boş sorgu ile arama).
  Future<void> load() => search('');

  /// Sorguyu günceller ve sonuçları getirir. Eski bir aramanın yanıtı yok sayılır.
  Future<void> search(String query) async {
    final requestId = ++_latestRequestId;
    _query = query;
    _isLoading = true;
    _notify();

    try {
      final found = await _repository.searchExercises(query);
      if (!_isLatest(requestId)) return;
      _exercises = found;
    } catch (_) {
      if (!_isLatest(requestId)) return;
      _errorMessage = 'Hareketler yüklenemedi.';
    }

    _isLoading = false;
    _notify();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _isLatest(int requestId) => !_disposed && requestId == _latestRequestId;

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
