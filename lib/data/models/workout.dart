/// copyWith içinde "bu alan verilmedi" ile "bu alan null yapılsın"ı ayırt etmek için kullanılır.
const Object _unset = Object();

/// Bir antrenman oturumu.
///
/// [title] isteğe bağlıdır; null ise arayüz başlık yerine [startedAt] tarih ve saatini gösterir.
class Workout {
  const Workout({
    required this.id,
    required this.startedAt,
    this.title,
    this.programDayId,
    this.finishedAt,
  });

  factory Workout.fromMap(Map<String, Object?> map) {
    return Workout(
      id: map['id'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      title: map['title'] as String?,
      programDayId: map['program_day_id'] as int?,
      finishedAt: map['finished_at'] == null
          ? null
          : DateTime.parse(map['finished_at'] as String),
    );
  }

  final int id;
  final DateTime startedAt;
  final String? title;

  /// Programdan başlatıldıysa o program günü (şema 3); değilse ya da gün silindiyse `null`.
  final int? programDayId;

  /// "Bitir" ile (telefonda ya da saatte) kaydedilen bitiş anı (şema 4, §16.3); bitirilmemişse `null`.
  /// Süre = [finishedAt] − [startedAt]. Şema 4'ten önceki antrenmanlarda hep `null`'dır.
  final DateTime? finishedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'started_at': startedAt.toIso8601String(),
      'title': title,
      'program_day_id': programDayId,
      'finished_at': finishedAt?.toIso8601String(),
    };
  }

  /// [title] için `null` geçmek başlığı siler; hiç geçmemek mevcut başlığı korur.
  /// [finishedAt] için de aynı kural geçerlidir.
  Workout copyWith({
    int? id,
    DateTime? startedAt,
    Object? title = _unset,
    Object? finishedAt = _unset,
  }) {
    return Workout(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      title: identical(title, _unset) ? this.title : title as String?,
      programDayId: programDayId,
      finishedAt: identical(finishedAt, _unset) ? this.finishedAt : finishedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Workout &&
        other.id == id &&
        other.startedAt == startedAt &&
        other.title == title &&
        other.programDayId == programDayId &&
        other.finishedAt == finishedAt;
  }

  @override
  int get hashCode => Object.hash(id, startedAt, title, programDayId, finishedAt);

  @override
  String toString() => 'Workout($id, $startedAt, $title)';
}
