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
  });

  factory Workout.fromMap(Map<String, Object?> map) {
    return Workout(
      id: map['id'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      title: map['title'] as String?,
    );
  }

  final int id;
  final DateTime startedAt;
  final String? title;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'started_at': startedAt.toIso8601String(),
      'title': title,
    };
  }

  /// [title] için `null` geçmek başlığı siler; hiç geçmemek mevcut başlığı korur.
  Workout copyWith({int? id, DateTime? startedAt, Object? title = _unset}) {
    return Workout(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      title: identical(title, _unset) ? this.title : title as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Workout &&
        other.id == id &&
        other.startedAt == startedAt &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, startedAt, title);

  @override
  String toString() => 'Workout($id, $startedAt, $title)';
}
