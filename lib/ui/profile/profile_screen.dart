import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/measurement_repository.dart';
import '../app_tab.dart';
import '../core/formatters.dart';
import '../core/theme/app_spacing.dart';
import 'measurement_detail_screen.dart';
import 'profile_view_model.dart';
import 'widgets/measurement_dialogs.dart';

/// Profil sekmesi: kilo, boy ve mezura ölçümleri (#14).
///
/// Her ölçüm türü için son değer ve değişim gösterilir; dokununca ölçüm detayı açılır.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ProfileViewModel(context.read<MeasurementRepository>())..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  late final ProfileViewModel _viewModel;

  /// Seçili sekmeyi izleyen kaynak; ekran tek başına açıldıysa `null`.
  ValueListenable<AppTab>? _tabs;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<ProfileViewModel>();
    _tabs = AppTabScope.maybeOf(context);
    _tabs?.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    super.dispose();
  }

  /// Profil sekmesi seçilince (yeniden seçimler dahil) özetleri yükleme göstergesi olmadan yeniler.
  void _onTabChanged() {
    if (_tabs?.value != AppTab.profile || !mounted) return;
    _viewModel.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfileViewModel>();
    _showPendingError(context, viewModel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Özel ölçüm ekle',
            onPressed: () => _createType(context, viewModel),
          ),
        ],
      ),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ProfileViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        for (final summary in viewModel.summaries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _MeasurementSummaryCard(
              summary: summary,
              onTap: () => _openDetail(context, viewModel, summary.type),
              onAdd: () => _addMeasurement(context, viewModel, summary.type),
            ),
          ),
      ],
    );
  }

  /// Özel ölçüm türü diyaloğunu açar; onaylanırsa türü oluşturur.
  Future<void> _createType(BuildContext context, ProfileViewModel viewModel) async {
    final result = await showMeasurementTypeDialog(context);
    if (result == null) return;
    await viewModel.createType(result.name, result.unit);
  }

  /// Bu tür için ölçüm ekleme diyaloğunu açar; kaydedilirse listeyi yeniler.
  Future<void> _addMeasurement(
    BuildContext context,
    ProfileViewModel viewModel,
    MeasurementType type,
  ) async {
    final result = await showMeasurementDialog(context, type: type);
    if (result == null) return;
    await viewModel.addMeasurement(type.id, result.value, result.measuredAt);
  }

  /// Ölçüm detay ekranını açar; dönünce özetler yeniden okunur.
  Future<void> _openDetail(
    BuildContext context,
    ProfileViewModel viewModel,
    MeasurementType type,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeasurementDetailScreen(type: type),
      ),
    );
    if (!context.mounted) return;
    await viewModel.refresh();
  }

  /// ViewModel'in bekleyen hata mesajını SnackBar ile gösterir ve temizler.
  void _showPendingError(BuildContext context, ProfileViewModel viewModel) {
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

/// Değişimi okunur metne çevirir: "+0,5 cm", "−1 kg". Değişim yoksa ya da 0'a yuvarlanıyorsa `null`.
String? _formatChange(MeasurementSummary summary) {
  final change = summary.change;
  if (change == null) return null;

  final magnitude = formatWeight(change.abs());
  if (magnitude == '0') return null;

  final sign = change > 0 ? '+' : '−';
  return '$sign$magnitude ${summary.type.unit}';
}

/// Profil listesindeki bir ölçüm türü satırı: ad, son değer, tarih ve değişim.
class _MeasurementSummaryCard extends StatelessWidget {
  const _MeasurementSummaryCard({
    required this.summary,
    required this.onTap,
    required this.onAdd,
  });

  final MeasurementSummary summary;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final mutedStyle = textTheme.bodySmall?.copyWith(color: muted);
    final latest = summary.latest;
    final change = _formatChange(summary);

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        title: Text(summary.type.name, style: textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (latest == null)
              Text('Henüz ölçüm yok', style: mutedStyle),
            if (latest != null) ...[
              Text(
                '${formatWeight(latest.value)} ${summary.type.unit}',
                style: textTheme.bodyMedium,
              ),
              Text(
                DateFormat('d MMM y', 'tr').format(latest.measuredAt),
                style: mutedStyle,
              ),
            ],
            if (change != null) Text(change, style: mutedStyle),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Ölçüm ekle',
          onPressed: onAdd,
        ),
      ),
    );
  }
}
