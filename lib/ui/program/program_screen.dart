import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/program_repository.dart';
import '../app_tab.dart';
import '../core/formatters.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import 'day_edit_screen.dart';
import 'program_view_model.dart';
import 'programs_screen.dart';

/// Program sekmesinin kökü: etkin programın günleri ve hareket hedefleri (#16).
///
/// Günlere dokunulunca gün düzenleme ekranı açılır; dönünce liste yenilenir.
class ProgramScreen extends StatelessWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ProgramViewModel(context.read<ProgramRepository>())..load(),
      child: const _ProgramView(),
    );
  }
}

/// Program başlığındaki ⋮ menüsünün seçenekleri.
enum _ProgramAction { rename, delete }

class _ProgramView extends StatefulWidget {
  const _ProgramView();

  @override
  State<_ProgramView> createState() => _ProgramViewState();
}

class _ProgramViewState extends State<_ProgramView> {
  late final ProgramViewModel _viewModel;

  /// Seçili sekmeyi izleyen kaynak; ekran tek başına açıldıysa `null`.
  ValueListenable<AppTab>? _tabs;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<ProgramViewModel>();
    _viewModel.addListener(_showPendingError);
    _tabs = AppTabScope.maybeOf(context);
    _tabs?.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    _viewModel.removeListener(_showPendingError);
    super.dispose();
  }

  /// Program sekmesi seçilince (yeniden seçimler dahil) etkin programı yeniler.
  void _onTabChanged() {
    if (_tabs?.value != AppTab.program || !mounted) return;
    _viewModel.refresh();
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

  /// Yeni program: ad sorulur, program oluşturulur (ilk programsa etkin olur).
  Future<void> _createProgram() async {
    final name = await showProgramNameDialog(
      context,
      title: 'Yeni program',
      label: 'Program adı',
      confirmLabel: 'Oluştur',
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _viewModel.createProgram(name);
  }

  Future<void> _renameProgram(ProgramDetail detail) async {
    final name = await showProgramNameDialog(
      context,
      title: 'Yeniden adlandır',
      label: 'Program adı',
      initialName: detail.program.name,
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _viewModel.renameActiveProgram(name);
  }

  Future<void> _confirmDeleteProgram() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Programı sil'),
        content: const Text(
          'Program ve tüm günleri silinecek. Bu programla yapılmış antrenmanlar kalır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _viewModel.deleteActiveProgram();
  }

  /// Yeni gün: ad sorulur, gün eklenir ve gün düzenleme ekranı açılır.
  Future<void> _addDay() async {
    final name = await showProgramNameDialog(
      context,
      title: 'Yeni gün',
      label: 'Gün adı',
      confirmLabel: 'Oluştur',
    );
    if (name == null || name.isEmpty || !mounted) return;

    final dayId = await _viewModel.addDay(name);
    if (dayId == null || !mounted) return;
    await _openDay(dayId);
  }

  /// Gün düzenleme ekranını açar; dönünce programı yeniler.
  Future<void> _openDay(int dayId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => DayEditScreen(dayId: dayId)),
    );
    if (!mounted) return;
    await _viewModel.refresh();
  }

  /// Programlar ekranını açar; dönünce etkin program değişmiş olabileceği için yeniler.
  Future<void> _openPrograms() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ProgramsScreen()),
    );
    if (!mounted) return;
    await _viewModel.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProgramViewModel>();
    final detail = viewModel.detail;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.program.name ?? 'Program',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (viewModel.hasPrograms)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Programlar',
              onPressed: _openPrograms,
            ),
          if (detail != null)
            SizedBox.square(
              dimension: AppSpacing.minTouchTarget,
              child: Center(
                child: PopupMenuButton<_ProgramAction>(
                  tooltip: 'Program seçenekleri',
                  onSelected: (action) {
                    switch (action) {
                      case _ProgramAction.rename:
                        _renameProgram(detail);
                      case _ProgramAction.delete:
                        _confirmDeleteProgram();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ProgramAction.rename,
                      child: Text('Yeniden adlandır'),
                    ),
                    PopupMenuItem(
                      value: _ProgramAction.delete,
                      child: Text('Programı sil'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: detail == null
          ? null
          : FloatingActionButton(
              tooltip: 'Gün ekle',
              onPressed: _addDay,
              child: const Icon(Icons.add),
            ),
      body: _buildBody(viewModel),
    );
  }

  Widget _buildBody(ProgramViewModel viewModel) {
    final detail = viewModel.detail;

    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (detail != null) {
      return _buildDays(detail);
    }
    if (!viewModel.hasPrograms) {
      return EmptyState(
        icon: Icons.event_note,
        title: 'Henüz program yok',
        message: 'Haftalık programını oluştur; antrenman başlatırken günü önerilsin.',
        actionLabel: 'Program oluştur',
        onAction: _createProgram,
      );
    }
    return EmptyState(
      icon: Icons.event_note,
      title: 'Etkin program yok',
      message: "Programlar'dan birini seç.",
      actionLabel: 'Programlar',
      onAction: _openPrograms,
    );
  }

  Widget _buildDays(ProgramDetail detail) {
    if (detail.days.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'Henüz gün yok',
        message: 'Gün eklemek için + düğmesine dokun.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        88, // Yüzen düğmenin son karttan ayrı kalması için.
      ),
      itemCount: detail.days.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final day = detail.days[index];
        return _DayCard(
          day: day,
          isFirst: index == 0,
          isLast: index == detail.days.length - 1,
          onOpen: () => _openDay(day.day.id),
          onMove: (offset) => _viewModel.moveDay(index, offset),
        );
      },
    );
  }
}

/// Programın bir günü: ad, planlanan gün, hareketler ve hedefleri. Dokununca düzenlenir.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.isFirst,
    required this.isLast,
    required this.onOpen,
    required this.onMove,
  });

  final ProgramDayDetail day;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onOpen;

  /// Günü -1 (yukarı) ya da +1 (aşağı) kaydırır.
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.day.name, style: textTheme.titleMedium),
                        Text(formatWeekday(day.day.weekday), style: muted),
                      ],
                    ),
                  ),
                  SizedBox.square(
                    dimension: AppSpacing.minTouchTarget,
                    child: Center(
                      child: PopupMenuButton<int>(
                        tooltip: 'Gün seçenekleri',
                        onSelected: onMove,
                        itemBuilder: (_) => [
                          if (!isFirst)
                            const PopupMenuItem(
                              value: -1,
                              child: Text('Yukarı taşı'),
                            ),
                          if (!isLast)
                            const PopupMenuItem(
                              value: 1,
                              child: Text('Aşağı taşı'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (day.exercises.isEmpty)
                Text('Henüz hareket yok', style: muted)
              else
                for (final entry in day.exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '${entry.exercise.name} · ${formatTarget(entry.dayExercise.target)}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
