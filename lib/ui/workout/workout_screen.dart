import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../core/formatters.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import '../exercise_picker/exercise_picker_screen.dart';
import 'widgets/exercise_card.dart';
import 'workout_view_model.dart';

/// Antrenman ekranı: var olan bir antrenmanı gösterir ve düzenler.
///
/// Değişiklikler anında veritabanına yazılır; ayrı bir "Kaydet" adımı yoktur.
/// Geri çıkışta bekleyen notlar kaydedilir ve hiç hareketi olmayan antrenman silinir.
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WorkoutViewModel(
        context.read<WorkoutRepository>(),
        workoutId,
      )..load(),
      child: const _WorkoutView(),
    );
  }
}

class _WorkoutView extends StatelessWidget {
  const _WorkoutView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkoutViewModel>();

    final error = vm.errorMessage;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        // Aynı frame'de birden çok çağrı olabilir; her seferinde güncel değere bakılır.
        final message = vm.errorMessage;
        if (message == null) return;
        vm.clearError();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await vm.flushNotes();
        await vm.discardIfEmpty();
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _TitleButton(
            title: vm.title,
            onTap: () => _editTitle(context, vm),
          ),
        ),
        body: _buildBody(context, vm),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WorkoutViewModel vm) {
    final detail = vm.detail;

    if (detail == null) {
      if (vm.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(child: Text('Antrenman bulunamadı.'));
    }

    if (detail.exercises.isEmpty) {
      return EmptyState(
        icon: Icons.fitness_center,
        title: 'İlk hareketini ekle',
        message: 'Yaptığın hareketi seç, setlerini kaydet.',
        actionLabel: 'Hareket ekle',
        onAction: () => _addExercise(context, vm),
      );
    }

    final hasTitle = detail.workout.title != null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        if (hasTitle) ...[
          Text(
            formatWorkoutDate(detail.workout.startedAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final entry in detail.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ExerciseCard(
              key: ValueKey('exercise-${entry.workoutExercise.id}'),
              entry: entry,
              previousSets: vm.previousSetsFor(entry.exercise.id),
              draft: vm.draftFor(entry.workoutExercise.id),
              expanded: vm.isExpanded(entry.workoutExercise.id),
              onToggleExpanded: () =>
                  vm.toggleExpanded(entry.workoutExercise.id),
              onRemove: () => vm.removeExercise(entry.workoutExercise.id),
              onDraftWeightChanged: (kg) =>
                  vm.setDraftWeight(entry.workoutExercise.id, kg),
              onDraftRepsChanged: (reps) =>
                  vm.setDraftReps(entry.workoutExercise.id, reps),
              onAddSet: () => vm.addSet(entry.workoutExercise.id),
              onRepeatLastSet: () => vm.repeatLastSet(entry.workoutExercise.id),
              onUpdateSet: vm.updateSet,
              onDeleteSet: vm.deleteSet,
              onNoteChanged: (note) =>
                  vm.updateNote(entry.workoutExercise.id, note),
            ),
          ),
        FilledButton.icon(
          onPressed: () => _addExercise(context, vm),
          icon: const Icon(Icons.add),
          label: const Text('Hareket ekle'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
          ),
        ),
      ],
    );
  }

  Future<void> _addExercise(BuildContext context, WorkoutViewModel vm) async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise != null) {
      await vm.addExercise(exercise);
    }
  }

  Future<void> _editTitle(BuildContext context, WorkoutViewModel vm) async {
    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => _TitleDialog(initialTitle: vm.detail?.workout.title ?? ''),
    );
    if (newTitle != null) {
      await vm.updateTitle(newTitle);
    }
  }
}

/// Uygulama çubuğundaki dokunulabilir antrenman başlığı.
class _TitleButton extends StatelessWidget {
  const _TitleButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minTouchTarget,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Antrenman adını değiştiren diyalog. Boş bırakılan ad, başlığı kaldırır.
class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Antrenman adı'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'ör. Upper, Göğüs günü, Pazartesi',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
