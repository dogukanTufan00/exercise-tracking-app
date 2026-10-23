import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../utils/text_normalizer.dart';
import 'measurement_repository.dart';

/// [MeasurementRepository] arayüzünün SQLite (sqflite) uygulaması.
///
/// Metotların davranışı için bkz. `measurement_repository.dart` içindeki yorumlar.
class SqliteMeasurementRepository implements MeasurementRepository {
  SqliteMeasurementRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<Database> get _db => _databaseService.database;

  // ------------------------------------------------------------------------ Türler

  @override
  Future<List<MeasurementType>> getMeasurementTypes() async {
    final db = await _db;
    final rows = await db.query('measurement_types', orderBy: 'position, id');
    return [for (final row in rows) MeasurementType.fromMap(row)];
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
    final db = await _db;

    // COLLATE NOCASE Türkçe harfleri bilmediği için ad kontrolü Dart tarafında yapılır.
    return db.transaction<MeasurementType>((txn) async {
      final existing = await txn.query('measurement_types', columns: ['name']);
      final isDuplicate = existing.any(
        (row) => normalizeForSearch(row['name'] as String) == key,
      );
      if (isDuplicate) throw DuplicateMeasurementTypeException(cleanName);

      final rows = await txn.rawQuery(
        'SELECT COALESCE(MAX(position), -1) + 1 AS next_position FROM measurement_types',
      );
      final position = rows.single['next_position'] as int;

      final id = await txn.insert('measurement_types', {
        'name': cleanName,
        'unit': cleanUnit,
        'position': position,
        'builtin_key': null,
      });
      return MeasurementType(id: id, name: cleanName, unit: cleanUnit, position: position);
    });
  }

  @override
  Future<void> deleteMeasurementType(int typeId) async {
    final db = await _db;
    final rows = await db.query(
      'measurement_types',
      columns: ['builtin_key'],
      where: 'id = ?',
      whereArgs: [typeId],
    );
    if (rows.isEmpty) return;
    if (rows.single['builtin_key'] != null) {
      throw ArgumentError.value(typeId, 'typeId', 'Yerleşik ölçüm türü silinemez');
    }
    // Ölçümler ON DELETE CASCADE ile birlikte silinir.
    await db.delete('measurement_types', where: 'id = ?', whereArgs: [typeId]);
  }

  // --------------------------------------------------------------------- Ölçümler

  @override
  Future<List<MeasurementSummary>> getMeasurementSummaries() async {
    final types = await getMeasurementTypes();
    final db = await _db;

    final summaries = <MeasurementSummary>[];
    for (final type in types) {
      final rows = await db.query(
        'body_measurements',
        where: 'type_id = ?',
        whereArgs: [type.id],
        orderBy: 'measured_at DESC, id DESC',
        limit: 2,
      );
      final measurements = [for (final row in rows) BodyMeasurement.fromMap(row)];
      summaries.add(MeasurementSummary(
        type: type,
        latest: measurements.isNotEmpty ? measurements[0] : null,
        previous: measurements.length > 1 ? measurements[1] : null,
      ));
    }
    return summaries;
  }

  @override
  Future<List<BodyMeasurement>> getMeasurements(int typeId) async {
    final db = await _db;
    final rows = await db.query(
      'body_measurements',
      where: 'type_id = ?',
      whereArgs: [typeId],
      orderBy: 'measured_at, id',
    );
    return [for (final row in rows) BodyMeasurement.fromMap(row)];
  }

  @override
  Future<BodyMeasurement> addMeasurement(
    int typeId,
    double value, {
    DateTime? measuredAt,
  }) async {
    _validateValue(value);
    final db = await _db;
    final time = measuredAt ?? DateTime.now();

    return db.transaction<BodyMeasurement>((txn) async {
      await _requireExists(txn, 'measurement_types', typeId, 'Ölçüm türü bulunamadı');

      final id = await txn.insert('body_measurements', {
        'type_id': typeId,
        'measured_at': time.toIso8601String(),
        'value': value,
      });
      return BodyMeasurement(id: id, typeId: typeId, measuredAt: time, value: value);
    });
  }

  @override
  Future<void> updateMeasurement(BodyMeasurement measurement) async {
    _validateValue(measurement.value);
    final db = await _db;
    await db.update(
      'body_measurements',
      {
        'measured_at': measurement.measuredAt.toIso8601String(),
        'value': measurement.value,
      },
      where: 'id = ?',
      whereArgs: [measurement.id],
    );
  }

  @override
  Future<void> deleteMeasurement(int measurementId) async {
    final db = await _db;
    await db.delete('body_measurements', where: 'id = ?', whereArgs: [measurementId]);
  }

  // -------------------------------------------------------------------- Yedekleme

  @override
  Future<({List<BackupMeasurementType> types, List<BackupMeasurement> measurements})>
      exportMeasurements() async {
    final db = await _db;

    // Tek bir okuma anlık görüntüsü için her şey bir transaction içinde okunur.
    return db.transaction<
        ({List<BackupMeasurementType> types, List<BackupMeasurement> measurements})>(
      (txn) async {
        final typeRows = await txn.query(
          'measurement_types',
          where: 'builtin_key IS NULL',
          orderBy: 'position, id',
        );

        final measurementRows = await txn.rawQuery('''
          SELECT t.name AS type_name, t.unit AS unit, m.measured_at, m.value
          FROM body_measurements m
          JOIN measurement_types t ON t.id = m.type_id
          ORDER BY m.measured_at, m.id
        ''');

        return (
          types: [
            for (final row in typeRows)
              BackupMeasurementType(
                name: row['name'] as String,
                unit: row['unit'] as String,
              ),
          ],
          measurements: [
            for (final row in measurementRows)
              BackupMeasurement(
                typeName: row['type_name'] as String,
                unit: row['unit'] as String,
                measuredAt: DateTime.parse(row['measured_at'] as String),
                value: (row['value'] as num).toDouble(),
              ),
          ],
        );
      },
    );
  }

  @override
  Future<int> importMeasurements({
    required List<BackupMeasurementType> types,
    required List<BackupMeasurement> measurements,
  }) async {
    // Yazmadan önce tüm girdi doğrulanır: hata varsa veritabanına hiçbir şey yazılmaz.
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

    final db = await _db;
    return db.transaction<int>((txn) async {
      // Ad anahtarı (normalleştirilmiş) → tür id'si.
      final typeIds = <String, int>{};
      var nextPosition = 0;
      for (final row in await txn.query('measurement_types', columns: ['id', 'name', 'position'])) {
        typeIds[normalizeForSearch(row['name'] as String)] = row['id'] as int;
        final position = row['position'] as int;
        if (position >= nextPosition) nextPosition = position + 1;
      }

      // Adla eşleşen türü bulur; yoksa yedekteki ad ve birimle özel tür oluşturur.
      Future<int> ensureType(String name, String unit) async {
        final cleanName = name.trim();
        final key = normalizeForSearch(cleanName);
        final existing = typeIds[key];
        if (existing != null) return existing;

        final id = await txn.insert('measurement_types', {
          'name': cleanName,
          'unit': unit.trim(),
          'position': nextPosition++,
          'builtin_key': null,
        });
        typeIds[key] = id;
        return id;
      }

      for (final type in types) {
        await ensureType(type.name, type.unit);
      }

      // Aynı tür ve aynı zamanlı ölçüm zaten varsa atlanır (metin olarak aynı biçimde saklanır).
      final takenKeys = <String>{};
      for (final row in await txn.query(
        'body_measurements',
        columns: ['type_id', 'measured_at'],
      )) {
        takenKeys.add('${row['type_id']}|${row['measured_at']}');
      }

      var added = 0;
      for (final measurement in measurements) {
        final typeId = await ensureType(measurement.typeName, measurement.unit);
        final measuredAt = measurement.measuredAt.toIso8601String();
        if (!takenKeys.add('$typeId|$measuredAt')) continue;

        await txn.insert('body_measurements', {
          'type_id': typeId,
          'measured_at': measuredAt,
          'value': measurement.value,
        });
        added++;
      }
      return added;
    });
  }

  // ------------------------------------------------------------------ Yardımcılar

  /// Kaydın var olduğunu doğrular; yoksa [ArgumentError] fırlatır.
  Future<void> _requireExists(
    DatabaseExecutor executor,
    String table,
    int id,
    String message,
  ) async {
    final rows = await executor.query(
      table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw ArgumentError.value(id, 'id', message);
  }

  /// Ölçüm değeri sonlu ve 0'dan büyük olmalı.
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
