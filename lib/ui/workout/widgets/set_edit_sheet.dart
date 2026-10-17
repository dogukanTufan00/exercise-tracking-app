import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../core/theme/app_spacing.dart';
import 'weight_reps_steppers.dart';

/// Bir seti düzenlemek için alttan açılan sayfa.
///
/// Kaydet'e basılınca [onSave] çağrılır ve sayfa kapanır.
class SetEditSheet extends StatefulWidget {
  const SetEditSheet({
    super.key,
    required this.set,
    required this.onSave,
  });

  /// Düzenlenen set; [ExerciseSet.setNumber] başlıkta gösterilir.
  final ExerciseSet set;

  /// Yeni değerlerle kaydedilen set.
  final ValueChanged<ExerciseSet> onSave;

  @override
  State<SetEditSheet> createState() => _SetEditSheetState();
}

class _SetEditSheetState extends State<SetEditSheet> {
  late double _weightKg;
  late int _reps;

  @override
  void initState() {
    super.initState();
    _weightKg = widget.set.weightKg;
    _reps = widget.set.reps;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.set.setNumber}. set',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            WeightRepsSteppers(
              weightKg: _weightKg,
              reps: _reps,
              onWeightChanged: (v) => setState(() => _weightKg = v),
              onRepsChanged: (v) => setState(() => _reps = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () {
                widget.onSave(
                  widget.set.copyWith(weightKg: _weightKg, reps: _reps),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
