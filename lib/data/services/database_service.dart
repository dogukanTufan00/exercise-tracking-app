import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/measurement.dart';

/// Veritabanını açar, şemayı oluşturur ve tek bir [Database] örneği paylaşır.
///
/// Şema değişikliklerinde [schemaVersion] artırılır ve `onUpgrade` yazılır (bkz. docs/ARCHITECTURE.md §4).
class DatabaseService {
  /// [factory] verilmezse sqflite'ın varsayılan fabrikası, [path] verilmezse
  /// uygulamanın veritabanı klasöründe `exercise_tracking.db` kullanılır.
  DatabaseService({DatabaseFactory? factory, String? path})
    : this._(factory ?? databaseFactory, path);

  DatabaseService._(this._factory, this._path);

  static const int schemaVersion = 2;

  /// Her biri ayrı çalıştırılan şema ifadeleri (docs/ARCHITECTURE.md §4 ile birebir).
  static const List<String> _schemaStatements = [
    '''
    CREATE TABLE exercises (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      name          TEXT    NOT NULL UNIQUE COLLATE NOCASE,
      muscle_group  TEXT    NOT NULL
    )
    ''',
    '''
    CREATE TABLE workouts (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at  TEXT    NOT NULL,
      title       TEXT
    )
    ''',
    '''
    CREATE TABLE workout_exercises (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_id   INTEGER NOT NULL REFERENCES workouts(id)  ON DELETE CASCADE,
      exercise_id  INTEGER NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
      position     INTEGER NOT NULL,
      note         TEXT
    )
    ''',
    'CREATE INDEX idx_we_workout  ON workout_exercises(workout_id)',
    'CREATE INDEX idx_we_exercise ON workout_exercises(exercise_id)',
    '''
    CREATE TABLE exercise_sets (
      id                   INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_exercise_id  INTEGER NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
      set_number           INTEGER NOT NULL,
      weight_kg            REAL    NOT NULL CHECK (weight_kg >= 0),
      reps                 INTEGER NOT NULL CHECK (reps > 0)
    )
    ''',
    'CREATE INDEX idx_sets_we ON exercise_sets(workout_exercise_id)',
  ];

  /// Sürüm 2 ifadeleri: vücut ölçümleri (docs/ARCHITECTURE.md §4 "Şema 2" ile birebir).
  /// Mevcut tablolara dokunmaz.
  static const List<String> _schemaV2Statements = [
    '''
    CREATE TABLE measurement_types (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      name         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
      unit         TEXT    NOT NULL,
      position     INTEGER NOT NULL,
      builtin_key  TEXT    UNIQUE
    )
    ''',
    '''
    CREATE TABLE body_measurements (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      type_id      INTEGER NOT NULL REFERENCES measurement_types(id) ON DELETE CASCADE,
      measured_at  TEXT    NOT NULL,
      value        REAL    NOT NULL CHECK (value > 0)
    )
    ''',
    'CREATE INDEX idx_measurements_type ON body_measurements(type_id, measured_at)',
  ];

  /// Yalnızca testler için: sürüm 1 şema ifadeleri (gerçek bir v1 veritabanı kurmak için).
  static List<String> get schemaV1Statements => _schemaStatements;

  final DatabaseFactory _factory;
  final String? _path;

  /// Açılış işlemi; eşzamanlı çağrılar aynı Future'ı paylaşır, veritabanı bir kez açılır.
  Future<Database>? _openFuture;

  /// Veritabanı; ilk çağrıda açılır, sonraki çağrılarda aynı örnek döner.
  Future<Database> get database => _openFuture ??= _open();

  /// Açıksa veritabanını kapatır. Tekrar [database] çağrılırsa yeniden açılır.
  Future<void> close() async {
    final opening = _openFuture;
    _openFuture = null;
    if (opening == null) return;
    final db = await opening.then<Database?>((value) => value, onError: (_) => null);
    await db?.close();
  }

  Future<Database> _open() async {
    try {
      final path = _path ?? join(await getDatabasesPath(), 'exercise_tracking.db');
      return await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          // Her DatabaseService kendi bağlantısını açar; iki örnek aynı veritabanını paylaşmaz.
          singleInstance: false,
        ),
      );
    } catch (_) {
      // Açma başarısızsa bir sonraki çağrı yeniden denesin.
      _openFuture = null;
      rethrow;
    }
  }

  /// Yabancı anahtar kısıtları (ON DELETE CASCADE dahil) SQLite'ta varsayılan olarak kapalıdır.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Yeni kurulum: tüm sürümlerin ifadeleri ve yerleşik ölçüm türleri tek transaction'da.
  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      for (final statement in _schemaStatements) {
        await txn.execute(statement);
      }
      for (final statement in _schemaV2Statements) {
        await txn.execute(statement);
      }
      await _insertBuiltinMeasurementTypes(txn);
    });
  }

  /// Şema yükseltmesi. Her yeni sürüm için aynı desen: `if (oldVersion < N)` bloğu içinde yalnızca
  /// o sürümün yeni tablolarını/indexlerini ekle; mevcut tablolar silinmez, satırlar değişmez.
  /// Sürüm 1 → 2 (ölçümler): tek transaction'da yeni tablolar ve yerleşik türler.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        for (final statement in _schemaV2Statements) {
          await txn.execute(statement);
        }
        await _insertBuiltinMeasurementTypes(txn);
      });
    }
  }

  /// Yerleşik ölçüm türlerini [builtinMeasurementTypes] sırasıyla ekler (position 0, 1, 2…).
  static Future<void> _insertBuiltinMeasurementTypes(DatabaseExecutor executor) async {
    for (final (position, type) in builtinMeasurementTypes.indexed) {
      await executor.insert('measurement_types', {
        'name': type.name,
        'unit': type.unit,
        'position': position,
        'builtin_key': type.key,
      });
    }
  }
}
