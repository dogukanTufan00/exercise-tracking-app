import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/program_repository.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import 'programs_view_model.dart';

/// Programlar ekranı: tüm programları listeler; birine dokunmak onu etkin yapar.
///
/// Program sekmesinin ⋮/liste simgesinden açılır; seçim sonrası geri döner.
class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ProgramsViewModel(context.read<ProgramRepository>())..load(),
      child: const _ProgramsView(),
    );
  }
}

/// Ad isteyen diyaloğu açar (program ya da gün adı). İptalde `null`, onaylanınca kırpılmış ad döner.
///
/// Program sekmesi de bu diyaloğu kullanır; bu yüzden burada tanımlanır.
Future<String?> showProgramNameDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialName = '',
  String confirmLabel = 'Kaydet',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ProgramNameDialog(
      title: title,
      label: label,
      initialName: initialName,
      confirmLabel: confirmLabel,
    ),
  );
}

class _ProgramNameDialog extends StatefulWidget {
  const _ProgramNameDialog({
    required this.title,
    required this.label,
    required this.initialName,
    required this.confirmLabel,
  });

  final String title;
  final String label;
  final String initialName;
  final String confirmLabel;

  @override
  State<_ProgramNameDialog> createState() => _ProgramNameDialogState();
}

class _ProgramNameDialogState extends State<_ProgramNameDialog> {
  late final TextEditingController _controller;

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

  void _save() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (_) => setState(() {}),
        onSubmitted: canSave ? (_) => _save() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _ProgramsView extends StatefulWidget {
  const _ProgramsView();

  @override
  State<_ProgramsView> createState() => _ProgramsViewState();
}

class _ProgramsViewState extends State<_ProgramsView> {
  late final ProgramsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<ProgramsViewModel>();
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

  /// Dokunulan programı etkin yapar ve ekranı kapatır (hata varsa ekranda kalır).
  Future<void> _activate(Program program) async {
    final ok = await _viewModel.setActiveProgram(program.id);
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProgramsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni program',
            onPressed: _createProgram,
          ),
        ],
      ),
      body: _buildBody(viewModel),
    );
  }

  Widget _buildBody(ProgramsViewModel viewModel) {
    if (viewModel.programs.isEmpty) {
      if (viewModel.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const EmptyState(
        icon: Icons.event_note,
        title: 'Henüz program yok',
        message: 'Yeni program ekleyerek başla.',
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView.separated(
      itemCount: viewModel.programs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final program = viewModel.programs[index];
        return ListTile(
          title: Text(
            program.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: program.isActive
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Etkin',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : null,
          onTap: () => _activate(program),
        );
      },
    );
  }
}
