import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/number_stepper.dart';

/// Ağırlık ve tekrar adımlayıcılarını birlikte gösterir.
///
/// Yer yeterliyse yan yana, dar ekranda (ya da büyük sistem yazısında) alt alta dizilir;
/// böylece sayılar küçülmek zorunda kalmaz.
class WeightRepsSteppers extends StatelessWidget {
  const WeightRepsSteppers({
    super.key,
    required this.weightKg,
    required this.reps,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  /// Bir adımlayıcıda değer + birim için ayrılması istenen en küçük genişlik (yazı ölçeği 1.0'da).
  ///
  /// 64, "102.5 kg" gibi bir değerin titleLarge boyutunda neredeyse küçülmeden sığdığı genişliktir.
  static const double minValueWidth = 64;

  final double weightKg;
  final int reps;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;

  /// Yan yana dizmek için gereken toplam genişlik.
  ///
  /// Her adımlayıcı: iki buton (2 × 48) + yazı ölçeğiyle büyüyen değer alanı.
  /// Yazı ölçeği 1.0'da 2 × (96 + 64) + 8 = 328; 1.3'te 2 × (96 + 83) + 8 ≈ 366.
  /// Örnek: 411 dp telefonda kartın içi ~339 dp → yan yana; 360 dp'de ~288 dp → alt alta.
  static double sideBySideMinWidth(TextScaler textScaler) {
    final perStepper =
        2 * AppSpacing.minTouchTarget + textScaler.scale(minValueWidth);
    return 2 * perStepper + AppSpacing.sm;
  }

  @override
  Widget build(BuildContext context) {
    final weight = NumberStepper(
      key: const ValueKey('weight-stepper'),
      value: weightKg,
      step: 2.5,
      unit: 'kg',
      label: 'Ağırlık',
      onChanged: onWeightChanged,
    );
    final repsStepper = NumberStepper(
      key: const ValueKey('reps-stepper'),
      value: reps.toDouble(),
      step: 1,
      min: 1,
      allowDecimal: false,
      label: 'Tekrar',
      onChanged: (v) => onRepsChanged(v.round()),
    );

    final minWidth = sideBySideMinWidth(MediaQuery.textScalerOf(context));

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minWidth) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              weight,
              const SizedBox(height: AppSpacing.sm),
              repsStepper,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: weight),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: repsStepper),
          ],
        );
      },
    );
  }
}
