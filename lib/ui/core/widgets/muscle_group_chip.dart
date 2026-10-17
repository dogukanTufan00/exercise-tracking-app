import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../theme/app_spacing.dart';

/// Bir kas grubunu gösteren hap şeklinde etiket.
///
/// [onTap] verilirse dokunulabilir olur ve dokunma alanı en az 48 yüksekliktedir;
/// verilmezse sadece görsel bir etiket olarak çizilir.
class MuscleGroupChip extends StatelessWidget {
  const MuscleGroupChip({
    super.key,
    required this.group,
    this.selected = false,
    this.onTap,
  });

  /// Gösterilen kas grubu.
  final MuscleGroup group;

  /// Seçili görünümü (vurgu rengiyle kenarlık ve metin).
  final bool selected;

  /// Dokunulduğunda çalışacak işlem; null ise etiket dokunulamaz.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final accent = selected ? colorScheme.primary : colorScheme.outline;
    final textColor =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: accent, width: 1),
        ),
      ),
      child: Text(
        group.label,
        style: textTheme.labelMedium?.copyWith(color: textColor),
      ),
    );

    if (onTap == null) return chip;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: AppSpacing.minTouchTarget,
          child: Align(
            widthFactor: 1,
            child: chip,
          ),
        ),
      ),
    );
  }
}
