import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/muscle_group_chip.dart';
import 'exercise_picker_view_model.dart';

/// Hareket seçme ekranı. Seçilen (ya da yeni oluşturulan) hareketle kapanır:
/// `Navigator.pop<Exercise>(context, exercise)`. Kullanıcı geri dönerse sonuç `null`'dır.
///
/// Kullanım:
/// ```dart
/// final exercise = await Navigator.push<Exercise>(
///   context,
///   MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
/// );
/// ```
class ExercisePickerScreen extends StatelessWidget {
  const ExercisePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ExercisePickerViewModel(context.read<WorkoutRepository>())..load(),
      child: const _ExercisePickerView(),
    );
  }
}

class _ExercisePickerView extends StatefulWidget {
  const _ExercisePickerView();

  @override
  State<_ExercisePickerView> createState() => _ExercisePickerViewState();
}

class _ExercisePickerViewState extends State<_ExercisePickerView> {
  late final ExercisePickerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<ExercisePickerViewModel>();
    _viewModel.addListener(_showPendingError);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_showPendingError);
    super.dispose();
  }

  /// Hata varsa SnackBar ile gösterir ve ViewModel'deki hatayı temizler.
  void _showPendingError() {
    final message = _viewModel.errorMessage;
    if (message == null || !mounted) return;

    _viewModel.clearError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _createExercise() async {
    final exercise = await _viewModel.createExercise();
    if (exercise == null || !mounted) return;
    Navigator.of(context).pop(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExercisePickerViewModel>();
    final showEmptyCatalog = !viewModel.isLoading &&
        viewModel.results.isEmpty &&
        viewModel.query.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Hareket seç')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => viewModel.search(value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Hareket ara',
              ),
            ),
          ),
          Expanded(
            child: showEmptyCatalog
                ? const EmptyState(
                    icon: Icons.search,
                    title: 'Kataloğun boş',
                    message: 'Yukarıya bir hareket adı yazarak ilk hareketini ekle.',
                  )
                : _buildList(viewModel),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ExercisePickerViewModel viewModel) {
    final rows = <Widget>[];

    if (viewModel.canCreate) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: _NewExerciseBox(
            viewModel: viewModel,
            onCreate: _createExercise,
          ),
        ),
      );
    }

    for (var i = 0; i < viewModel.results.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1));
      final exercise = viewModel.results[i];
      rows.add(
        _ExerciseRow(
          exercise: exercise,
          onTap: () => Navigator.of(context).pop(exercise),
        ),
      );
    }

    return ListView(children: rows);
  }
}

/// Sorguyu yeni bir hareket adı olarak öneren, kas grubu seçtirip ekletten kutu.
class _NewExerciseBox extends StatelessWidget {
  const _NewExerciseBox({required this.viewModel, required this.onCreate});

  final ExercisePickerViewModel viewModel;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = viewModel.selectedGroup;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${viewModel.query.trim()}" adıyla yeni hareket',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Kas grubu',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final group in MuscleGroup.values)
                MuscleGroupChip(
                  group: group,
                  selected: group == selected,
                  onTap: () => viewModel.selectGroup(group),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
            ),
            onPressed: selected == null ? null : () => onCreate(),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

/// Katalogdaki bir hareketin satırı: ad ve kas grubu. Dokunulunca hareket seçilir.
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(exercise.name, style: textTheme.titleMedium),
              ),
              const SizedBox(width: AppSpacing.sm),
              MuscleGroupChip(group: exercise.muscleGroup),
            ],
          ),
        ),
      ),
    );
  }
}
