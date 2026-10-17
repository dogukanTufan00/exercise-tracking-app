import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/utils/text_normalizer.dart';

/// Hareket seçme ekranının durumu: arama sorgusu, sonuçlar ve yeni hareket oluşturma.
class ExercisePickerViewModel extends ChangeNotifier {
  ExercisePickerViewModel(this._repository);

  final WorkoutRepository _repository;

  String _query = '';
  List<Exercise> _results = const [];
  bool _isLoading = false;
  String? _errorMessage;
  MuscleGroup? _selectedGroup;
  bool _disposed = false;

  /// Her aramaya artan bir numara verilir; yalnızca en son aramanın yanıtı kabul edilir.
  int _latestRequestId = 0;

  /// Kullanıcının yazdığı arama metni.
  String get query => _query;

  /// Son (en güncel) aramanın sonuçları.
  List<Exercise> get results => _results;

  bool get isLoading => _isLoading;

  /// Ekranda gösterilecek hata; gösterildikten sonra [clearError] ile temizlenmeli.
  String? get errorMessage => _errorMessage;

  /// Yeni hareket için seçilen kas grubu.
  MuscleGroup? get selectedGroup => _selectedGroup;

  /// Sorgu boş değilse ve sonuçlarda normalleştirilmiş adı birebir aynı bir hareket yoksa true.
  bool get canCreate {
    final name = _query.trim();
    if (name.isEmpty) return false;

    final key = normalizeForSearch(name);
    return !_results.any((exercise) => normalizeForSearch(exercise.name) == key);
  }

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
      _results = found;
    } catch (_) {
      if (!_isLatest(requestId)) return;
      _errorMessage = 'Hareketler yüklenemedi';
    }

    _isLoading = false;
    _notify();
  }

  void selectGroup(MuscleGroup group) {
    _selectedGroup = group;
    _notify();
  }

  /// Sorguyu adı, seçili grubu kas grubu olarak yeni bir hareket oluşturur.
  ///
  /// Grup seçili değilse ya da ad boşsa `null` döner. Aynı adlı hareket varsa
  /// [errorMessage] dolar ve `null` döner.
  Future<Exercise?> createExercise() async {
    final group = _selectedGroup;
    final name = _query.trim();
    if (group == null || name.isEmpty) return null;

    try {
      return await _repository.createExercise(name, group);
    } on DuplicateExerciseException {
      _errorMessage = 'Bu hareket zaten katalogda var';
    } catch (_) {
      _errorMessage = 'Hareket eklenemedi';
    }

    _notify();
    return null;
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
