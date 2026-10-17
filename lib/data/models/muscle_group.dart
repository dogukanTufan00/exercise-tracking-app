/// Bir hareketin çalıştırdığı ana kas grubu.
///
/// Veritabanında [name] (ör. `chest`) olarak saklanır; kullanıcıya [label] gösterilir.
enum MuscleGroup {
  chest('Göğüs'),
  back('Sırt'),
  legs('Bacak'),
  shoulders('Omuz'),
  arms('Kol'),
  core('Karın'),
  other('Diğer');

  const MuscleGroup(this.label);

  /// Kullanıcıya gösterilen Türkçe ad.
  final String label;

  /// Veritabanındaki değeri enum'a çevirir. Bilinmeyen bir değer gelirse [other] döner.
  static MuscleGroup fromName(String name) {
    return MuscleGroup.values.firstWhere(
      (group) => group.name == name,
      orElse: () => MuscleGroup.other,
    );
  }
}
