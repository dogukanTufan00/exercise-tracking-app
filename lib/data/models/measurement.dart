// Vücut ölçümleri (kilo, boy, mezura ölçümleri). Bkz. docs/ARCHITECTURE.md §4 ve §13.

/// Uygulamayla gelen ölçüm türleri: ilk açılışta (ya da v1 → v2 geçişinde) bu sırayla oluşturulur.
///
/// [key] kalıcı bir kimliktir (değişmez); [name] kullanıcıya görünen addır.
const List<({String key, String name, String unit})> builtinMeasurementTypes = [
  (key: 'weight', name: 'Kilo', unit: 'kg'),
  (key: 'height', name: 'Boy', unit: 'cm'),
  (key: 'right_arm', name: 'Sağ kol', unit: 'cm'),
  (key: 'left_arm', name: 'Sol kol', unit: 'cm'),
  (key: 'right_leg', name: 'Sağ bacak', unit: 'cm'),
  (key: 'left_leg', name: 'Sol bacak', unit: 'cm'),
  (key: 'waist', name: 'Bel', unit: 'cm'),
  (key: 'chest', name: 'Göğüs', unit: 'cm'),
  (key: 'hips', name: 'Kalça', unit: 'cm'),
  (key: 'neck', name: 'Boyun', unit: 'cm'),
];

/// Bir ölçüm türü: yerleşik (Kilo, Sağ kol…) ya da kullanıcının eklediği (ör. "Ön kol", "cm").
class MeasurementType {
  const MeasurementType({
    required this.id,
    required this.name,
    required this.unit,
    required this.position,
    this.builtinKey,
  });

  factory MeasurementType.fromMap(Map<String, Object?> map) {
    return MeasurementType(
      id: map['id'] as int,
      name: map['name'] as String,
      unit: map['unit'] as String,
      position: map['position'] as int,
      builtinKey: map['builtin_key'] as String?,
    );
  }

  final int id;
  final String name;

  /// Birim metni ("kg", "cm" ya da kullanıcının yazdığı).
  final String unit;

  /// Listedeki sıra; yerleşikler önce, özel türler eklenme sırasıyla sonra.
  final int position;

  /// Yerleşik türün kalıcı anahtarı ([builtinMeasurementTypes]); özel türlerde `null`.
  final String? builtinKey;

  /// Yerleşik türler silinemez.
  bool get isBuiltin => builtinKey != null;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'position': position,
      'builtin_key': builtinKey,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is MeasurementType &&
        other.id == id &&
        other.name == name &&
        other.unit == unit &&
        other.position == position &&
        other.builtinKey == builtinKey;
  }

  @override
  int get hashCode => Object.hash(id, name, unit, position, builtinKey);

  @override
  String toString() => 'MeasurementType($id, $name, $unit)';
}

/// Tarihli tek bir ölçüm (ör. 18 Ekim, Bel, 82 cm).
class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.typeId,
    required this.measuredAt,
    required this.value,
  });

  factory BodyMeasurement.fromMap(Map<String, Object?> map) {
    return BodyMeasurement(
      id: map['id'] as int,
      typeId: map['type_id'] as int,
      measuredAt: DateTime.parse(map['measured_at'] as String),
      // SQLite REAL sütunu tam sayı gibi görünen değerleri int döndürebilir.
      value: (map['value'] as num).toDouble(),
    );
  }

  final int id;
  final int typeId;
  final DateTime measuredAt;

  /// Her zaman 0'dan büyük; birimi türünden gelir.
  final double value;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type_id': typeId,
      'measured_at': measuredAt.toIso8601String(),
      'value': value,
    };
  }

  BodyMeasurement copyWith({DateTime? measuredAt, double? value}) {
    return BodyMeasurement(
      id: id,
      typeId: typeId,
      measuredAt: measuredAt ?? this.measuredAt,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BodyMeasurement &&
        other.id == id &&
        other.typeId == typeId &&
        other.measuredAt == measuredAt &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(id, typeId, measuredAt, value);

  @override
  String toString() => 'BodyMeasurement($id, type $typeId, $value @ $measuredAt)';
}

/// Profil ekranındaki bir satır: tür, en son ölçüm ve ondan önceki ölçüm (değişimi göstermek için).
class MeasurementSummary {
  const MeasurementSummary({required this.type, this.latest, this.previous});

  final MeasurementType type;

  /// En yeni ölçüm; hiç ölçüm yoksa `null`.
  final BodyMeasurement? latest;

  /// [latest]'tan bir önceki ölçüm; yoksa `null`.
  final BodyMeasurement? previous;

  /// Son iki ölçüm arasındaki fark (son − önceki); ikisi de yoksa `null`.
  double? get change {
    final a = latest;
    final b = previous;
    if (a == null || b == null) return null;
    return a.value - b.value;
  }
}
