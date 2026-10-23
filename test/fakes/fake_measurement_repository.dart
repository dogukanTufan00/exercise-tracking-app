import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/measurement_repository.dart';
import 'package:exercise_tracking_app/data/utils/text_normalizer.dart';

/// Testler için tamamen bellekte çalışan [MeasurementRepository].
///
/// Gerçek SQLite uygulamasıyla aynı kuralları izler; bunu ortak sözleşme testleri doğrular
/// (bkz. `test/data/repositories/measurement_repository_contract.dart`).
/// Kurulduğunda yerleşik türler [builtinMeasurementTypes] sırasıyla (id 1..10) bulunur.
/// Silinen id'ler tekrar kullanılmaz (SQLite AUTOINCREMENT gibi).
class FakeMeasurementRepository implements MeasurementRepository {
  FakeMeasurementRepository() {
    for (final (position, type) in builtinMeasurementTypes.indexed) {
      final id = _nextTypeId++;
      _types[id] = MeasurementType(
        id: id,
        name: type.name,
        unit: type.unit,
        position: position,
        builtinKey: type.key,
      );
    }
  }

  final Map<int, MeasurementType> _types = {};
  final Map<int, BodyMeasurement> _measurements = {};

  int _nextTypeId = 1;
  int _nextMeasurementId = 1;

  // ------------------------------------------------------------------------ Türler

  @override
  Future<List<MeasurementType>> getMeasurementTypes() async {
    return List.unmodifiable(_sortedTypes());
  }

  @override
  Future<MeasurementType> createMeasurementType(String name, String unit) async {
    final cleanName = _cleanText(name);
    if (cleanName == null) {
      throw ArgumentError.value(name, 'name', 'Ölçüm adı boş olamaz');
    }
    final cleanUnit = _cleanText(unit);
    if (cleanUnit == null) {
      throw ArgumentError.value(unit, 'unit', 'Birim boş olamaz');
    }

    final key = normalizeForSearch(cleanName);
    if (_types.values.any((t) => normalizeForSearch(t.name) == key)) {
      throw DuplicateMeasurementTypeException(cleanName);
    }

    final type = MeasurementType(
      id: _nextTypeId++,
      name: cleanName,
      unit: cleanUnit,
      position: _nextPosition(),
    );
    _types[type.id] = type;
    return type;
  }

  @override
  Future<void> deleteMeasurementType(int typeId) async {
    final type = _types[typeId];
    if (type == null) return;
    if (type.isBuiltin) {
      throw ArgumentError.value(typeId, 'typeId', 'Yerleşik ölçüm türü silinemez');
    }

    _types.remove(typeId);
    _measurements.removeWhere((_, m) => m.typeId == typeId);
  }

  // --------------------------------------------------------------------- Ölçümler

  @override
  Future<List<MeasurementSummary>> getMeasurementSummaries() async {
    final summaries = <MeasurementSummary>[];
    for (final type in _sortedTypes()) {
      // En yeni önce: son iki ölçüm.
      final recent = _measurementsOf(type.id).reversed.toList();
      summaries.add(MeasurementSummary(
        type: type,
        latest: recent.isNotEmpty ? recent[0] : null,
        previous: recent.length > 1 ? recent[1] : null,
      ));
    }
    return List.unmodifiable(summaries);
  }

  @override
  Future<List<BodyMeasurement>> getMeasurements(int typeId) async {
    return List.unmodifiable(_measurementsOf(typeId));
  }

  @override
  Future<BodyMeasurement> addMeasurement(
    int typeId,
    double value, {
    DateTime? measuredAt,
  }) async {
    _validateValue(value);
    if (!_types.containsKey(typeId)) {
      throw ArgumentError.value(typeId, 'typeId', 'Ölçüm türü bulunamadı');
    }

    final measurement = BodyMeasurement(
      id: _nextMeasurementId++,
      typeId: typeId,
      measuredAt: measuredAt ?? DateTime.now(),
      value: value,
    );
    _measurements[measurement.id] = measurement;
    return measurement;
  }

  @override
  Future<void> updateMeasurement(BodyMeasurement measurement) async {
    _validateValue(measurement.value);
    final current = _measurements[measurement.id];
    if (current == null) return;
    _measurements[measurement.id] = current.copyWith(
      measuredAt: measurement.measuredAt,
      value: measurement.value,
    );
  }

  @override
  Future<void> deleteMeasurement(int measurementId) async {
    _measurements.remove(measurementId);
  }

  // -------------------------------------------------------------------- Yedekleme

  @override
  Future<({List<BackupMeasurementType> types, List<BackupMeasurement> measurements})>
      exportMeasurements() async {
    final measurements = _measurements.values.toList()..sort(_oldestFirst);
    return (
      types: [
        for (final type in _sortedTypes())
          if (!type.isBuiltin)
            BackupMeasurementType(name: type.name, unit: type.unit),
      ],
      measurements: [
        for (final m in measurements)
          BackupMeasurement(
            typeName: _types[m.typeId]!.name,
            unit: _types[m.typeId]!.unit,
            measuredAt: m.measuredAt,
            value: m.value,
          ),
      ],
    );
  }

  @override
  Future<int> importMeasurements({
    required List<BackupMeasurementType> types,
    required List<BackupMeasurement> measurements,
  }) async {
    // Yazmadan önce tüm girdi doğrulanır: hata varsa hiçbir değişiklik kalmaz.
    for (final type in types) {
      if (type.name.trim().isEmpty) {
        throw ArgumentError.value(type.name, 'name', 'Ölçüm adı boş olamaz');
      }
      if (type.unit.trim().isEmpty) {
        throw ArgumentError.value(type.unit, 'unit', 'Birim boş olamaz');
      }
    }
    for (final measurement in measurements) {
      if (measurement.typeName.trim().isEmpty) {
        throw ArgumentError.value(measurement.typeName, 'typeName', 'Ölçüm adı boş olamaz');
      }
      if (measurement.unit.trim().isEmpty) {
        throw ArgumentError.value(measurement.unit, 'unit', 'Birim boş olamaz');
      }
      _validateValue(measurement.value);
    }

    // Ad anahtarı (normalleştirilmiş) → tür id'si.
    final typeIds = <String, int>{
      for (final type in _types.values) normalizeForSearch(type.name): type.id,
    };

    int ensureType(String name, String unit) {
      final cleanName = name.trim();
      final key = normalizeForSearch(cleanName);
      final existing = typeIds[key];
      if (existing != null) return existing;

      final type = MeasurementType(
        id: _nextTypeId++,
        name: cleanName,
        unit: unit.trim(),
        position: _nextPosition(),
      );
      _types[type.id] = type;
      typeIds[key] = type.id;
      return type.id;
    }

    for (final type in types) {
      ensureType(type.name, type.unit);
    }

    // Aynı tür ve aynı zamanlı ölçüm zaten varsa atlanır.
    final taken = {
      for (final m in _measurements.values) (m.typeId, m.measuredAt),
    };

    var added = 0;
    for (final measurement in measurements) {
      final typeId = ensureType(measurement.typeName, measurement.unit);
      if (!taken.add((typeId, measurement.measuredAt))) continue;

      final stored = BodyMeasurement(
        id: _nextMeasurementId++,
        typeId: typeId,
        measuredAt: measurement.measuredAt,
        value: measurement.value,
      );
      _measurements[stored.id] = stored;
      added++;
    }
    return added;
  }

  // ------------------------------------------------------------------ Yardımcılar

  /// Türler [MeasurementType.position] sırasıyla (yerleşikler önce).
  List<MeasurementType> _sortedTypes() {
    return _types.values.toList()
      ..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
      });
  }

  /// Bir türün ölçümleri, en eskiden en yeniye (eşitlikte id sırasıyla).
  List<BodyMeasurement> _measurementsOf(int typeId) {
    return _measurements.values
        .where((m) => m.typeId == typeId)
        .toList()
      ..sort(_oldestFirst);
  }

  /// Mevcut en büyük konumun bir fazlası (SQLite'taki MAX(position) + 1 ile aynı).
  int _nextPosition() {
    var max = -1;
    for (final type in _types.values) {
      if (type.position > max) max = type.position;
    }
    return max + 1;
  }

  static int _oldestFirst(BodyMeasurement a, BodyMeasurement b) {
    final byDate = a.measuredAt.compareTo(b.measuredAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  void _validateValue(double value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, 'value', 'Ölçüm değeri 0\'dan büyük olmalı');
    }
  }

  /// Kırpılmış metni döndürür; boşsa `null`.
  String? _cleanText(String? text) {
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
