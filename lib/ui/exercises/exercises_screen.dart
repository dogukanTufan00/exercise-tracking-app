import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/muscle_group_chip.dart';
import '../exercise_detail/exercise_detail_screen.dart';
import 'exercises_view_model.dart';

/// Hareketler ekranı: katalogdaki tüm hareketleri listeler ve arar.
///
/// Bir harekete dokunulunca o hareketin detay ekranı açılır.
class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ExercisesViewModel(context.read<WorkoutRepository>())..load(),
      child: const _ExercisesView(),
    );
  }
}

class _ExercisesView extends StatefulWidget {
  const _ExercisesView();

  @override
  State<_ExercisesView> createState() => _ExercisesViewState();
}

class _ExercisesViewState extends State<_ExercisesView> {
  late final ExercisesViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<ExercisesViewModel>();
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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExercisesViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Hareketler')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: TextField(
              textInputAction: TextInputAction.search,
              onChanged: (value) => viewModel.search(value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Hareket ara',
              ),
            ),
          ),
          Expanded(child: _buildBody(viewModel)),
        ],
      ),
    );
  }

  Widget _buildBody(ExercisesViewModel viewModel) {
    final isSearching = viewModel.query.trim().isNotEmpty;

    if (viewModel.exercises.isEmpty) {
      if (viewModel.isLoading) {
        // Aramada boş bir sonuç ekranı kısa süre görünmesin diye yalnızca ilk yüklemede spinner.
        return isSearching
            ? const SizedBox.shrink()
            : const Center(child: CircularProgressIndicator());
      }
      if (isSearching) {
        return Center(
          child: Text(
            'Eşleşen hareket yok',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }
      return const EmptyState(
        icon: Icons.fitness_center,
        title: 'Henüz hareket yok',
        message: 'Antrenmana hareket eklediğinde burada listelenir.',
      );
    }

    return ListView.separated(
      itemCount: viewModel.exercises.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final exercise = viewModel.exercises[index];
        return ListTile(
          title: Text(
            exercise.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: MuscleGroupChip(group: exercise.muscleGroup),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openDetail(context, exercise),
        );
      },
    );
  }

  Future<void> _openDetail(BuildContext context, Exercise exercise) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseDetailScreen(exercise: exercise),
      ),
    );
  }
}
