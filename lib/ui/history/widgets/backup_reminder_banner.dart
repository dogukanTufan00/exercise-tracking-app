import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Geçmiş ekranının üstündeki kapatılabilir yedek hatırlatması (§16.4).
///
/// DESIGN.md kart stili: ince çerçeve, dolgu yok. "Yedekle" ve kapat (×) düğmeleri 48 px'tir;
/// ekranda dolu düğme kullanılmaz.
class BackupReminderBanner extends StatelessWidget {
  const BackupReminderBanner({
    super.key,
    required this.title,
    required this.onBackup,
    required this.onDismiss,
  });

  /// "Henüz yedek almadın" ya da "Son yedeğin N gün önce".
  final String title;

  /// "Yedekle" düğmesi: Ayarlar ekranını açar.
  final VoidCallback onBackup;

  /// Kapat (×) düğmesi.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(
                  'Verilerin yalnızca bu telefonda.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onBackup,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.minTouchTarget),
            ),
            child: const Text('Yedekle'),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Kapat',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
