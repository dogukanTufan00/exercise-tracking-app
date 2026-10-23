import '../models/models.dart';

/// Vücut ölçümlerine (kilo, boy, mezura) tek giriş kapısı. Bkz. docs/ARCHITECTURE.md §13.
///
/// Uygulamaları: `SqliteMeasurementRepository` (gerçek, antrenmanlarla aynı veritabanı) ve
/// testlerdeki `FakeMeasurementRepository` (bellekte).
///
/// Ortak kurallar:
/// - Ad ve birim metinleri kırpılarak saklanır.
/// - Ölçüm değeri her zaman 0'dan büyüktür; değilse [ArgumentError].
/// - Var olmayan bir id ile güncelleme/silme sessizce hiçbir şey yapmaz; ekleme işlemlerinde
///   tür yoksa [ArgumentError] fırlatılır.
abstract interface class MeasurementRepository {
  // ----------------------------------------------------------------------- Türler

  /// Tüm ölçüm türleri, [MeasurementType.position] sırasıyla (yerleşikler önce).
  Future<List<MeasurementType>> getMeasurementTypes();

  /// Kullanıcının kendi ölçüm türünü ekler; listenin sonuna gelir.
  ///
  /// Ad ya da birim boşsa [ArgumentError]. Adının normalleştirilmiş hali (`normalizeForSearch`)
  /// mevcut bir türünkiyle aynıysa [DuplicateMeasurementTypeException] ("SAĞ KOL" = "Sağ kol").
  Future<MeasurementType> createMeasurementType(String name, String unit);

  /// Kullanıcının eklediği türü ve tüm ölçümlerini siler.
  /// Yerleşik bir tür verilirse [ArgumentError] fırlatır (yerleşikler silinemez).
  Future<void> deleteMeasurementType(int typeId);

  // --------------------------------------------------------------------- Ölçümler

  /// Profil ekranı için: her tür ([getMeasurementTypes] sırasıyla) ve son iki ölçümü.
  Future<List<MeasurementSummary>> getMeasurementSummaries();

  /// Bir türün tüm ölçümleri, en eskiden en yeniye ([BodyMeasurement.measuredAt], eşitlikte id).
  Future<List<BodyMeasurement>> getMeasurements(int typeId);

  /// Yeni ölçüm ekler. [measuredAt] verilmezse şu anki zaman kullanılır.
  Future<BodyMeasurement> addMeasurement(
    int typeId,
    double value, {
    DateTime? measuredAt,
  });

  /// Ölçümün tarihini ve değerini günceller ([BodyMeasurement.id] ile bulunur).
  Future<void> updateMeasurement(BodyMeasurement measurement);

  Future<void> deleteMeasurement(int measurementId);

  // -------------------------------------------------------------------- Yedekleme

  /// Yedeğe girecek ölçüm verisi: kullanıcının eklediği türler (eklenme sırasıyla) ve tüm ölçümler
  /// (en eskiden en yeniye). Yerleşik türler her veritabanında olduğu için ayrıca yazılmaz.
  Future<({List<BackupMeasurementType> types, List<BackupMeasurement> measurements})>
      exportMeasurements();

  /// Yedekteki ölçümleri mevcut verilerle **birleştirir**; eklenen ölçüm sayısını döndürür.
  ///
  /// - Türler adla eşleşir (`normalizeForSearch`); bulunamayan tür, yedekteki ad ve birimle özel tür
  ///   olarak oluşturulur ([types] listesindekiler dahil, ölçümü olmasa bile).
  /// - Aynı türde aynı [BackupMeasurement.measuredAt] zamanlı ölçüm zaten varsa **atlanır**.
  /// - **Ya hep ya hiç:** geçersiz değer (boş ad/birim, değer <= 0) varsa [ArgumentError] fırlatılır ve
  ///   hiçbir değişiklik kalmaz.
  Future<int> importMeasurements({
    required List<BackupMeasurementType> types,
    required List<BackupMeasurement> measurements,
  });
}

/// Aynı adda bir ölçüm türü zaten olduğunda fırlatılır.
class DuplicateMeasurementTypeException implements Exception {
  const DuplicateMeasurementTypeException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateMeasurementTypeException: "$name" zaten var';
}
