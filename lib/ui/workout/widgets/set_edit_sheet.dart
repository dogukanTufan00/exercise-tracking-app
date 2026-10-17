import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/number_stepper.dart';

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
            Row(
              children: [
                Expanded(
                  child: NumberStepper(
                    value: _weightKg,
                    step: 2.5,
                    unit: 'kg',
                    label: 'Ağırlık',
                    onChanged: (v) => setState(() => _weightKg = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: NumberStepper(
                    value: _reps.toDouble(),
                    step: 1,
                    min: 1,
                    allowDecimal: false,
                    label: 'Tekrar',
                    onChanged: (v) => setState(() => _reps = v.round()),
                  ),
                ),
              ],
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
