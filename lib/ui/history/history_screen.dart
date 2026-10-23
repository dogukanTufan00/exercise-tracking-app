import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/week_grouping.dart';
import '../core/formatters.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/muscle_group_chip.dart';
import '../settings/settings_screen.dart';
import '../workout/workout_screen.dart';
import 'history_view_model.dart';

/// Geçmiş ekranı: uygulamanın açılış ekranı.
///
/// Antrenman kartlarını listeler; dokunulunca antrenmanı açar, uzun basılınca siletir.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          HistoryViewModel(context.read<WorkoutRepository>())..load(),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HistoryViewModel>();
    _showPendingError(context, viewModel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrenmanlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onPressed: () async {
              // Tam ekran: alt gezinme çubuğunun üstünü kaplar.
              await Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
              // Ayarlar'da yedekten geri yükleme yapılmış olabilir.
              if (context.mounted) await viewModel.load();
            },
          ),
        ],
      ),
      body: _buildBody(context, viewModel),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Antrenman başlat',
        onPressed: () => _startWorkout(context, viewModel),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HistoryViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.workouts.isEmpty) {
      return EmptyState(
        icon: Icons.fitness_center,
        title: 'İlk antrenmanını başlat',
        message: 'Yaptığın hareketleri, setleri ve notlarını buraya kaydet.',
        actionLabel: 'Antrenman başlat',
        onAction: () => _startWorkout(context, viewModel),
      );
    }

    final items = _flatten(viewModel.weeks);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: items.length,
      separatorBuilder: (_, index) =>
          SizedBox(height: _separatorHeight(items, index)),
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _WeekHeaderItem(:final group) => _WeekHeader(group: group),
          _WorkoutItem(:final summary) => _WorkoutCard(
              summary: summary,
              onTap: () => _openWorkout(context, viewModel, summary.workout.id),
              onLongPress: () =>
                  _confirmDelete(context, viewModel, summary.workout),
            ),
        };
      },
    );
  }

  /// Haftaları, her hafta başlığının altına o haftanın kartları gelecek şekilde düz bir listeye çevirir.
  List<_ListItem> _flatten(List<WeekGroup> weeks) {
    return [
      for (final week in weeks) ...[
        _WeekHeaderItem(week),
        for (final summary in week.workouts) _WorkoutItem(summary),
      ],
    ];
  }

  /// İki öğe arasındaki boşluk: başlıktan karta [AppSpacing.sm], gruplar arasında [AppSpacing.lg],
  /// kartlar arasında [AppSpacing.md].
  double _separatorHeight(List<_ListItem> items, int index) {
    if (items[index + 1] is _WeekHeaderItem) return AppSpacing.lg;
    if (items[index] is _WeekHeaderItem) return AppSpacing.sm;
    return AppSpacing.md;
  }

  /// Yeni antrenman oluşturup açar; dönünce listeyi yeniler.
  Future<void> _startWorkout(
    BuildContext context,
    HistoryViewModel viewModel,
  ) async {
    final id = await viewModel.startWorkout();
    if (id == null || !context.mounted) return;
    await _openWorkout(context, viewModel, id);
  }

  /// Antrenman ekranını açar; kapanınca listeyi yeniler.
  Future<void> _openWorkout(
    BuildContext context,
    HistoryViewModel viewModel,
    int workoutId,
  ) async {
    // Tam ekran: alt gezinme çubuğunun üstünü kaplar.
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutScreen(workoutId: workoutId),
      ),
    );
    if (!context.mounted) return;
    await viewModel.load();
  }

  /// Silme onayı sorar; onaylanırsa antrenmanı siler.
  Future<void> _confirmDelete(
    BuildContext context,
    HistoryViewModel viewModel,
    Workout workout,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Antrenman silinsin mi?'),
        content: const Text(
          'Bu antrenman ve içindeki tüm setler kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await viewModel.deleteWorkout(workout.id);
    if (!context.mounted) return;
    if (viewModel.errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antrenman silindi')),
      );
    }
  }

  /// ViewModel'in bekleyen hata mesajını SnackBar ile gösterir ve temizler.
  void _showPendingError(BuildContext context, HistoryViewModel viewModel) {
    if (viewModel.errorMessage == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final message = viewModel.errorMessage;
      if (message == null) return;

      viewModel.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }
}

/// Geçmiş listesinin düz öğeleri: hafta başlığı ya da antrenman kartı.
sealed class _ListItem {
  const _ListItem();
}

class _WeekHeaderItem extends _ListItem {
  const _WeekHeaderItem(this.group);

  final WeekGroup group;
}

class _WorkoutItem extends _ListItem {
  const _WorkoutItem(this.summary);

  final WorkoutSummary summary;
}

/// Bir haftanın başlığı: "13–19 Ekim" ve yanında soluk "3 antrenman · 48 set". Kart değildir, dokunulmaz.
class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.group});

  final WeekGroup group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Text(
          formatWeekRange(group.weekStart),
          style: textTheme.titleSmall,
        ),
        Text(
          '${group.workouts.length} antrenman · ${group.setCount} set',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Geçmiş listesindeki tek bir antrenman kartı.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.summary,
    required this.onTap,
    required this.onLongPress,
  });

  final WorkoutSummary summary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final workout = summary.workout;
    final title = workout.title;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? formatWorkoutDate(workout.startedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      DateFormat('d MMM', 'tr').format(workout.startedAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${summary.exerciseCount} hareket · ${summary.setCount} set',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (summary.muscleGroups.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final group in summary.muscleGroups)
                      MuscleGroupChip(group: group),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
