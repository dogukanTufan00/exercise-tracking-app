import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/theme_controller.dart';

/// Ayarlar ekranı: tema seçimi.
///
/// ViewModel olarak [ThemeController] kullanılır.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final textTheme = Theme.of(context).textTheme;

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
        ],
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
