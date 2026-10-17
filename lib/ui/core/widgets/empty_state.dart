import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Liste ya da ekran boş olduğunda gösterilen ortalı bilgi alanı.
///
/// [actionLabel] ve [onAction] ikisi de verilirse bir buton da gösterilir.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Üstte gösterilen ikon.
  final IconData icon;

  /// Kısa başlık.
  final String title;

  /// Tek satırlık açıklama.
  final String message;

  /// Butonun metni; [onAction] ile birlikte verilmelidir.
  final String? actionLabel;

  /// Butona basılınca çalışacak işlem.
  final VoidCallback? onAction;

  /// Boş durum ikonunun boyutu.
  static const double _iconSize = 48;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final label = actionLabel;
    final action = onAction;
    final showAction = label != null && action != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: _iconSize,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (showAction) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: action,
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
