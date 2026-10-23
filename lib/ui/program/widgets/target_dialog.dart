import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/number_stepper.dart';

/// Hareket hedefi: set sayısı, tekrar ve isteğe bağlı ağırlık. İptalde `null` döner.
///
/// [initial] verilmezse varsayılan hedef 3 × 10'dur (ağırlık yok).
Future<ExerciseTarget?> showTargetDialog(
  BuildContext context, {
  required String exerciseName,
  ExerciseTarget? initial,
}) {
  return showDialog<ExerciseTarget>(
    context: context,
    builder: (_) => _TargetDialog(
      exerciseName: exerciseName,
      initial: initial ?? const ExerciseTarget(sets: 3, reps: 10),
    ),
  );
}

/// Ağırlık hedefi açılınca gösterilecek başlangıç değeri (kg).
const double _defaultWeightKg = 20;

/// Hedefi düzenleyen diyalog. Set ve tekrar alt alta dizilir; dar ekranda taşmaz.
class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.exerciseName, required this.initial});

  final String exerciseName;
  final ExerciseTarget initial;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late int _sets;
  late int _reps;
  late bool _useWeight;
  late double _weightKg;

  @override
  void initState() {
    super.initState();
    _sets = widget.initial.sets;
    _reps = widget.initial.reps;
    _useWeight = widget.initial.weightKg != null;
    _weightKg = widget.initial.weightKg ?? _defaultWeightKg;
  }

  void _save() {
    Navigator.of(context).pop(
      ExerciseTarget(
        sets: _sets,
        reps: _reps,
        weightKg: _useWeight ? _weightKg : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget labeled(String label, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      );
    }

    return AlertDialog(
      title: Text(widget.exerciseName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            labeled(
              'Set',
              NumberStepper(
                value: _sets.toDouble(),
                step: 1,
                min: 1,
                allowDecimal: false,
                label: 'Set',
                onChanged: (value) => setState(() => _sets = value.round()),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            labeled(
              'Tekrar',
              NumberStepper(
                value: _reps.toDouble(),
                step: 1,
                min: 1,
                allowDecimal: false,
                label: 'Tekrar',
                onChanged: (value) => setState(() => _reps = value.round()),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ağırlık hedefi'),
              value: _useWeight,
              onChanged: (value) => setState(() => _useWeight = value),
            ),
            if (_useWeight) ...[
              const SizedBox(height: AppSpacing.sm),
              labeled(
                'Ağırlık',
                NumberStepper(
                  value: _weightKg,
                  step: 2.5,
                  unit: 'kg',
                  label: 'Ağırlık',
                  onChanged: (value) => setState(() => _weightKg = value),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
