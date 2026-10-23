import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/program_repository.dart';
import '../core/formatters.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import '../exercise_picker/exercise_picker_screen.dart';
import 'day_edit_view_model.dart';
import 'widgets/target_dialog.dart';

/// Program gününü düzenleme ekranı: ad, planlanan gün, hareketler ve hedefleri (#16).
///
/// Kurucu imzası değişmez; program ekranı bu ekranı `DayEditScreen(dayId: ...)` ile açar.
class DayEditScreen extends StatelessWidget {
  const DayEditScreen({super.key, required this.dayId});

  /// Düzenlenen günün id'si.
  final int dayId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DayEditViewModel(context.read<ProgramRepository>(), dayId)..load(),
      child: const _DayEditView(),
    );
  }
}

/// Gün menüsündeki eylemler.
enum _DayMenu { delete }

/// Hareket satırının ⋮ menüsündeki eylemler.
enum _ExerciseMenu { up, down, remove }

class _DayEditView extends StatefulWidget {
  const _DayEditView();

  @override
  State<_DayEditView> createState() => _DayEditViewState();
}

class _DayEditViewState extends State<_DayEditView> {
  late final DayEditViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<DayEditViewModel>();
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

  Future<void> _rename(String currentName) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDayDialog(initialName: currentName),
    );
    if (name == null || !mounted) return;
    await _viewModel.rename(name);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Günü sil'),
        content: const Text('Gün ve hareketleri programdan silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deleted = await _viewModel.deleteDay();
    if (deleted && mounted) Navigator.of(context).pop();
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null || !mounted) return;

    final target = await showTargetDialog(context, exerciseName: exercise.name);
    if (target == null || !mounted) return;
    await _viewModel.addExercise(exercise.id, target);
  }

  Future<void> _editTarget(ProgramDayExerciseDetail detail) async {
    final target = await showTargetDialog(
      context,
      exerciseName: detail.exercise.name,
      initial: detail.dayExercise.target,
    );
    if (target == null || target == detail.dayExercise.target || !mounted) return;
    await _viewModel.updateTarget(detail.dayExercise.id, target);
  }

  void _onExerciseMenu(_ExerciseMenu action, int index, ProgramDayExerciseDetail detail) {
    switch (action) {
      case _ExerciseMenu.up:
        _viewModel.moveExercise(index, -1);
      case _ExerciseMenu.down:
        _viewModel.moveExercise(index, 1);
      case _ExerciseMenu.remove:
        _viewModel.removeExercise(detail.dayExercise.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DayEditViewModel>();
    final day = viewModel.day;

    return Scaffold(
      appBar: AppBar(
        title: Text(day?.name ?? 'Günü düzenle'),
        actions: [
          if (day != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Günü yeniden adlandır',
              onPressed: () => _rename(day.name),
            ),
            PopupMenuButton<_DayMenu>(
              tooltip: 'Gün menüsü',
              padding: const EdgeInsets.all(AppSpacing.md),
              onSelected: (_) => _confirmDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _DayMenu.delete, child: Text('Günü sil')),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: day == null
          ? null
          : FloatingActionButton(
              tooltip: 'Hareket ekle',
              onPressed: _addExercise,
              child: const Icon(Icons.add),
            ),
      body: _buildBody(viewModel),
    );
  }

  Widget _buildBody(DayEditViewModel viewModel) {
    final day = viewModel.day;
    if (day == null) {
      if (viewModel.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'Gün bulunamadı',
        message: 'Bu gün silinmiş olabilir.',
      );
    }

    final exercises = viewModel.exercises;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.screenPadding,
            AppSpacing.screenPadding,
            AppSpacing.sm,
          ),
          child: _WeekdayPicker(
            selected: day.weekday,
            onSelected: _viewModel.setWeekday,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: exercises.isEmpty
              ? const EmptyState(
                  icon: Icons.fitness_center,
                  title: 'Henüz hareket yok',
                  message: 'Bu güne yapacağın hareketleri ekle.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.screenPadding,
                    AppSpacing.screenPadding,
                    AppSpacing.xxl * 3,
                  ),
                  itemCount: exercises.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _buildExerciseTile(exercises, index),
                ),
        ),
      ],
    );
  }

  Widget _buildExerciseTile(List<ProgramDayExerciseDetail> exercises, int index) {
    final detail = exercises[index];
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            title: Text(detail.exercise.name, style: textTheme.titleMedium),
            subtitle: Text(
              formatTarget(detail.dayExercise.target),
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            onTap: () => _editTarget(detail),
            trailing: PopupMenuButton<_ExerciseMenu>(
              tooltip: 'Hareket menüsü',
              padding: const EdgeInsets.all(AppSpacing.md),
              onSelected: (action) => _onExerciseMenu(action, index, detail),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _ExerciseMenu.up,
                  enabled: index > 0,
                  child: const Text('Yukarı taşı'),
                ),
                PopupMenuItem(
                  value: _ExerciseMenu.down,
                  enabled: index < exercises.length - 1,
                  child: const Text('Aşağı taşı'),
                ),
                const PopupMenuItem(
                  value: _ExerciseMenu.remove,
                  child: Text('Çıkar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Planlanan günü seçen çip sırası: "Esnek" ve Pazartesi … Pazar.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onSelected});

  /// Seçili gün; `null` = esnek.
  final int? selected;

  /// Yeni seçimle çağrılır (`null` = esnek).
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Planlanan gün',
          style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: const Text('Esnek'),
              selected: selected == null,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onSelected(null),
            ),
            for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
              ChoiceChip(
                label: Text(formatWeekdayShort(weekday)),
                selected: selected == weekday,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => onSelected(weekday),
              ),
          ],
        ),
      ],
    );
  }
}

/// Günün adını değiştiren diyalog. Ad boşsa kapanmaz; trim edilmiş adı döndürür.
class _RenameDayDialog extends StatefulWidget {
  const _RenameDayDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDayDialog> createState() => _RenameDayDialogState();
}

class _RenameDayDialogState extends State<_RenameDayDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Gün adı boş olamaz');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Günü yeniden adlandır'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(errorText: _errorText),
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
