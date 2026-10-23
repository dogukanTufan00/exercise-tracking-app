import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/models.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/muscle_group_chip.dart';
import '../workout_view_model.dart';
import 'set_edit_sheet.dart';
import 'weight_reps_steppers.dart';

/// Antrenmandaki bir hareketi gösteren kart: setler, "geçen sefer", sıradaki set girişi ve not.
///
/// Kart açılıp kapanabilir. Kapalıyken başlığın altında tek satır özet görünür;
/// açıkken tüm içerik görünür.
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.entry,
    required this.previousSets,
    required this.isRecordSet,
    required this.draft,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onRemove,
    required this.onShowProgress,
    required this.onEditExercise,
    required this.onDraftWeightChanged,
    required this.onDraftRepsChanged,
    required this.onAddSet,
    required this.onRepeatLastSet,
    required this.onUpdateSet,
    required this.onDeleteSet,
    required this.onNoteChanged,
  });

  /// Antrenmandaki hareket, katalog bilgisi ve setleri.
  final WorkoutExerciseDetail entry;

  /// Hareketin bir önceki antrenmandaki setleri.
  final List<ExerciseSet> previousSets;

  /// Set, hareketin önceki antrenmanlardaki rekorlarını geçiyor mu; rekor setin yanında rozet çıkar.
  final bool Function(ExerciseSet set) isRecordSet;

  /// Sıradaki set için taslak değerler.
  final SetDraft draft;

  /// Kart açık mı; kapalıyken yalnızca başlık ve özet görünür.
  final bool expanded;

  /// Başlığa ya da açma/kapama okuna dokunulunca çalışır.
  final VoidCallback onToggleExpanded;

  final VoidCallback onRemove;

  /// Menüden "İlerleme" seçilince çalışır; hareketin detay ekranını açar.
  final VoidCallback onShowProgress;

  /// Menüden "Hareketi düzenle" seçilince çalışır; düzenleme diyaloğunu açar.
  final VoidCallback onEditExercise;
  final ValueChanged<double> onDraftWeightChanged;
  final ValueChanged<int> onDraftRepsChanged;
  final VoidCallback onAddSet;
  final VoidCallback onRepeatLastSet;
  final ValueChanged<ExerciseSet> onUpdateSet;
  final ValueChanged<int> onDeleteSet;
  final ValueChanged<String> onNoteChanged;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  /// Not alanının denetleyicisi State'te yaşar; kart kapanıp açılsa da yazılan not kaybolmaz.
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.entry.workoutExercise.note ?? '',
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _confirmRemove() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hareket kaldırılsın mı?'),
        content: const Text('Bu hareketin setleri de silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (remove == true) widget.onRemove();
  }

  void _openEditSheet(ExerciseSet set) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SetEditSheet(set: set, onSave: widget.onUpdateSet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final exercise = widget.entry.exercise;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onToggleExpanded,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise.name,
                              style: textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          MuscleGroupChip(group: exercise.muscleGroup),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                  tooltip: widget.expanded ? 'Daralt' : 'Genişlet',
                  onPressed: widget.onToggleExpanded,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Seçenekler',
                  onSelected: (value) {
                    if (value == 'progress') widget.onShowProgress();
                    if (value == 'edit') widget.onEditExercise();
                    if (value == 'remove') _confirmRemove();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'progress',
                      child: Text('İlerleme'),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Hareketi düzenle'),
                    ),
                    PopupMenuItem<String>(
                      value: 'remove',
                      child: Text('Hareketi kaldır'),
                    ),
                  ],
                ),
              ],
            ),
            if (widget.entry.workoutExercise.target case final target?)
              _buildTargetRow(context, target),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: widget.expanded ? _buildDetails(context) : _buildSummary(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Programdan gelen hedef satırı: "Hedef: 3 × 10 · 40 kg · 1/3 set". Hedef set sayısına ulaşınca sonda onay.
  Widget _buildTargetRow(BuildContext context, ExerciseTarget target) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final done = widget.entry.sets.length;
    final completed = done >= target.sets;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hedef: ${formatTarget(target)} · $done/${target.sets} set',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (completed) ...[
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              label: 'Hedef tamamlandı',
              container: true,
              child: Icon(Icons.check, size: 18, color: colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  /// Kapalıyken başlığın altında görünen tek satırlık özet.
  Widget _buildSummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sets = widget.entry.sets;
    final hasNote = _noteController.text.trim().isNotEmpty;

    final summary = sets.isEmpty
        ? 'Henüz set yok'
        : '${sets.length} set · ${_heaviestSummary(sets)}';

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (hasNote) ...[
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              label: 'Not var',
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Açıkken görünen tam içerik: geçen sefer, setler, sıradaki set girişi, butonlar ve not.
  Widget _buildDetails(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final sets = widget.entry.sets;
    final draft = widget.draft;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.previousSets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Geçen sefer: ${widget.previousSets.map((s) => formatSet(s.weightKg, s.reps)).join(', ')}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final set in sets)
          _SetRow(
            key: ValueKey('set-${set.id}'),
            set: set,
            isRecord: widget.isRecordSet(set),
            onTap: () => _openEditSheet(set),
            onDelete: () => widget.onDeleteSet(set.id),
          ),
        if (sets.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        Text(
          '${sets.length + 1}. set',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        WeightRepsSteppers(
          weightKg: draft.weightKg,
          reps: draft.reps,
          onWeightChanged: widget.onDraftWeightChanged,
          onRepsChanged: widget.onDraftRepsChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: sets.isEmpty ? null : widget.onRepeatLastSet,
                icon: const Icon(Icons.replay),
                label: const Text('Seti tekrarla'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onAddSet();
                },
                icon: const Icon(Icons.add),
                label: const Text('Set ekle'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _noteController,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Not ekle (ör. 2. sette formum bozuldu)',
          ),
          onChanged: widget.onNoteChanged,
        ),
      ],
    );
  }
}

/// En ağır seti özetler: en büyük ağırlık; eşitse en çok tekrar; o da eşitse ilk set.
String _heaviestSummary(List<ExerciseSet> sets) {
  var heaviest = sets.first;
  for (final set in sets.skip(1)) {
    final heavier = set.weightKg > heaviest.weightKg;
    final sameWeightMoreReps = set.weightKg == heaviest.weightKg &&
        set.reps > heaviest.reps;
    if (heavier || sameWeightMoreReps) heaviest = set;
  }
  return formatSet(heaviest.weightKg, heaviest.reps);
}

/// Bir setin özet satırı; dokununca düzenleme sayfası açılır.
class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.isRecord,
    required this.onTap,
    required this.onDelete,
  });

  final ExerciseSet set;

  /// Set hareketin önceki bir rekorunu geçtiyse true; satırda 🏆 rozeti görünür.
  final bool isRecord;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minTouchTarget,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${set.setNumber}',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                formatSet(set.weightKg, set.reps),
                style: textTheme.titleLarge,
              ),
            ),
            if (isRecord)
              Semantics(
                label: 'Kişisel rekor',
                container: true,
                child: Icon(Icons.emoji_events, color: colorScheme.primary),
              ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Seti sil',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
