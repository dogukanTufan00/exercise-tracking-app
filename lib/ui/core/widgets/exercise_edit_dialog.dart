import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../theme/app_spacing.dart';
import 'muscle_group_chip.dart';

/// Düzenlenmiş değerler.
typedef ExerciseEdit = ({String name, MuscleGroup muscleGroup});

/// Hareketin adını ve kas grubunu düzenleme diyaloğunu açar. İptalde `null` döner.
Future<ExerciseEdit?> showExerciseEditDialog(BuildContext context, Exercise exercise) {
  return showDialog<ExerciseEdit>(
    context: context,
    builder: (_) => _ExerciseEditDialog(exercise: exercise),
  );
}

/// Mevcut değerlerle dolu düzenleme diyaloğu. Ad boşsa Kaydet devre dışıdır.
class _ExerciseEditDialog extends StatefulWidget {
  const _ExerciseEditDialog({required this.exercise});

  final Exercise exercise;

  @override
  State<_ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<_ExerciseEditDialog> {
  late final TextEditingController _nameController;
  late MuscleGroup _selectedGroup;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise.name);
    _selectedGroup = widget.exercise.muscleGroup;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop<ExerciseEdit>(
      (name: _nameController.text.trim(), muscleGroup: _selectedGroup),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canSave = _nameController.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Hareketi düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Ad'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Kas grubu',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final group in MuscleGroup.values)
                  MuscleGroupChip(
                    group: group,
                    selected: group == _selectedGroup,
                    onTap: () => setState(() => _selectedGroup = group),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
