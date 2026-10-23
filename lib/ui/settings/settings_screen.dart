import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/measurement_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/services/backup_file_service.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/theme_controller.dart';
import 'backup_view_model.dart';

/// Ayarlar ekranı: tema seçimi ve veri dışa/içe aktarma.
///
/// Tema için [ThemeController], "Veriler" bölümü için [BackupViewModel] kullanılır.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BackupViewModel>(
      create: (context) => BackupViewModel(
        context.read<WorkoutRepository>(),
        context.read<MeasurementRepository>(),
        context.read<BackupFileService>(),
      ),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final backup = context.watch<BackupViewModel>();
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    _showPendingMessages(context, backup);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text('Tema', style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          for (final id in AppThemeId.values)
            _ThemeOption(
              id: id,
              selected: id == controller.themeId,
              onTap: () {
                controller.setTheme(id);
              },
            ),
          const SizedBox(height: AppSpacing.xl),
          Text('Veriler', style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          if (backup.isBusy) const LinearProgressIndicator(),
          _ActionOption(
            icon: Icons.table_chart_outlined,
            title: 'CSV olarak dışa aktar',
            description: 'Excel ve Google Sheets ile açılır',
            color: colorScheme.onSurfaceVariant,
            onTap: backup.isBusy ? null : backup.exportCsv,
          ),
          _ActionOption(
            icon: Icons.save_alt,
            title: 'Yedek al',
            description: 'Tüm verilerini telefona tek dosya olarak kaydet',
            color: colorScheme.onSurfaceVariant,
            onTap: backup.isBusy ? null : backup.exportJson,
          ),
          _ActionOption(
            icon: Icons.settings_backup_restore,
            title: 'Yedekten geri yükle',
            description: 'Mevcut verilerin korunur, yedektekiler eklenir',
            color: colorScheme.onSurfaceVariant,
            onTap: backup.isBusy ? null : backup.importJson,
          ),
        ],
      ),
    );
  }

  /// ViewModel'in bekleyen mesajını SnackBar ile gösterir ve temizler.
  void _showPendingMessages(BuildContext context, BackupViewModel backup) {
    if (backup.message == null && backup.errorMessage == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final error = backup.errorMessage;
      final message = backup.message;

      if (error != null) {
        backup.clearError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else if (message != null) {
        backup.clearMessage();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }
}

/// Veriler bölümündeki tek bir eylem satırı: ikon, başlık ve açıklama.
class _ActionOption extends StatelessWidget {
  const _ActionOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.bodyLarge),
                      Text(
                        description,
                        style: textTheme.bodySmall?.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek bir tema satırı: önizleme dairesi, ad ve seçiliyse onay işareti.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final AppThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                _ThemePreview(id: id),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(id.label, style: textTheme.bodyLarge)),
                if (selected)
                  Icon(Icons.check_circle, color: colorScheme.primary)
                else
                  const SizedBox(width: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Temanın arka plan ve vurgu renklerini gösteren küçük önizleme.
///
/// Bu sınıf, renkleri temadan değil [AppPalette]'ten okur: tüm temaları gösterebilmesi için.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.id});

  final AppThemeId id;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(id);

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.background,
        border: Border.all(color: palette.outline),
      ),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.primary,
        ),
      ),
    );
  }
}
