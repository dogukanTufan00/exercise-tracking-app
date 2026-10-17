import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/models.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/muscle_group_chip.dart';
import '../../core/widgets/number_stepper.dart';
import '../workout_view_model.dart';
import 'set_edit_sheet.dart';

/// Antrenmandaki bir hareketi gösteren kart: setler, "geçen sefer", sıradaki set girişi ve not.
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.entry,
    required this.previousSets,
    required this.draft,
    required this.onRemove,
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

  /// Sıradaki set için taslak değerler.
  final SetDraft draft;

  final VoidCallback onRemove;
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
    final colorScheme = Theme.of(context).colorScheme;
    final exercise = widget.entry.exercise;
    final sets = widget.entry.sets;
    final draft = widget.draft;

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
                  child: Text(
                    exercise.name,
                    style: textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                MuscleGroupChip(group: exercise.muscleGroup),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Seçenekler',
                  onSelected: (value) {
                    if (value == 'remove') _confirmRemove();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'remove',
                      child: Text('Hareketi kaldır'),
                    ),
                  ],
                ),
              ],
            ),
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
            Row(
              children: [
                Expanded(
                  child: NumberStepper(
                    value: draft.weightKg,
                    step: 2.5,
                    unit: 'kg',
                    label: 'Ağırlık',
                    onChanged: widget.onDraftWeightChanged,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: NumberStepper(
                    value: draft.reps.toDouble(),
                    step: 1,
                    min: 1,
                    allowDecimal: false,
                    label: 'Tekrar',
                    onChanged: (v) => widget.onDraftRepsChanged(v.round()),
                  ),
                ),
              ],
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
        ),
      ),
    );
  }
}

/// Bir setin özet satırı; dokununca düzenleme sayfası açılır.
class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.onTap,
    required this.onDelete,
  });

  final ExerciseSet set;
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
