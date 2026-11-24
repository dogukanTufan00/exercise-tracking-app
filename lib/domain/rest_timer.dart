/// Dinlenme sayacının saf mantığı (bkz. docs/ARCHITECTURE.md §16.2). Flutter import etmez.
///
/// Sayaç bir **bitiş anı** ([RestState.endsAt]) olarak tutulur; telefon ve saat geri sayımı bu ana göre kendi
/// saatleriyle yapar. Böylece mesajlar gecikse de iki ekran aynı kalan süreyi gösterir.
/// Saat tarafındaki karşılığı `wear/.../domain/RestTimer.kt` ile aynı sınırları kullanır.
library;

const int restMinSeconds = 15;
const int restMaxSeconds = 600;
const int restStepSeconds = 15;
const int restDefaultSeconds = 90;

/// Süreyi 15 sn – 10 dk aralığına sınırlar.
int clampRestSeconds(int seconds) => seconds.clamp(restMinSeconds, restMaxSeconds);

/// Çalışan dinlenme sayacı.
class RestState {
  const RestState({
    required this.restId,
    required this.workoutId,
    required this.endsAt,
    required this.totalSeconds,
  });

  factory RestState.fromJson(Map<String, Object?> json) => RestState(
        restId: json['restId'] as String,
        workoutId: json['workoutId'] as int,
        endsAt: DateTime.parse(json['endsAt'] as String),
        totalSeconds: json['totalSeconds'] as int,
      );

  /// Saatte başlayanda tetikleyen `addSet` olayının id'si; telefonda başlayanda `phone-<mikrosaniye>`.
  final String restId;

  /// Sayacın ait olduğu antrenman.
  final int workoutId;

  /// Bitiş anı (saat dilimsiz yerel saat).
  final DateTime endsAt;

  /// Toplam süre; ±15 sn ile birlikte değişir (ilerleme çubuğu için). En az 1.
  final int totalSeconds;

  Map<String, Object?> toJson() => {
        'restId': restId,
        'workoutId': workoutId,
        'endsAt': endsAt.toIso8601String(),
        'totalSeconds': totalSeconds,
      };

  RestState copyWith({DateTime? endsAt, int? totalSeconds}) => RestState(
        restId: restId,
        workoutId: workoutId,
        endsAt: endsAt ?? this.endsAt,
        totalSeconds: totalSeconds ?? this.totalSeconds,
      );

  @override
  bool operator ==(Object other) =>
      other is RestState &&
      other.restId == restId &&
      other.workoutId == workoutId &&
      other.endsAt == endsAt &&
      other.totalSeconds == totalSeconds;

  @override
  int get hashCode => Object.hash(restId, workoutId, endsAt, totalSeconds);

  @override
  String toString() => 'RestState($restId, workout $workoutId, ends $endsAt, $totalSeconds s)';
}

/// [startedAt] anında başlayan, [seconds] (sınırlanır) süren sayaç.
RestState startRest({
  required String restId,
  required int workoutId,
  required DateTime startedAt,
  required int seconds,
}) {
  final total = clampRestSeconds(seconds);
  return RestState(
    restId: restId,
    workoutId: workoutId,
    endsAt: startedAt.add(Duration(seconds: total)),
    totalSeconds: total,
  );
}

/// Sayacı [deltaSeconds] kadar uzatır/kısaltır (bitiş anı ve toplam birlikte kayar, toplam en az 1).
/// Sonuç bitmiş olabilir; çağıran [isRestFinished] ile bakar.
RestState adjustRest(RestState state, int deltaSeconds) => state.copyWith(
      endsAt: state.endsAt.add(Duration(seconds: deltaSeconds)),
      totalSeconds: (state.totalSeconds + deltaSeconds) < 1 ? 1 : state.totalSeconds + deltaSeconds,
    );

/// Kalan süre; bittiyse [Duration.zero].
Duration restRemaining(RestState state, DateTime now) {
  final remaining = state.endsAt.difference(now);
  return remaining.isNegative ? Duration.zero : remaining;
}

/// Süre bittiyse true.
bool isRestFinished(RestState state, DateTime now) => restRemaining(state, now) == Duration.zero;

/// Ekranda gösterilecek kalan saniye; yukarı yuvarlanır (90 sn'nin ilk anı "1:30").
int restRemainingSeconds(RestState state, DateTime now) =>
    (restRemaining(state, now).inMilliseconds + 999) ~/ 1000;

/// Kalan oran, 1'den 0'a (ilerleme çubuğu için).
double restRemainingFraction(RestState state, DateTime now) {
  final totalMs = state.totalSeconds * 1000;
  if (totalMs <= 0) return 0;
  return (restRemaining(state, now).inMilliseconds / totalMs).clamp(0.0, 1.0);
}
