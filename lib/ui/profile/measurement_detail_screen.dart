import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/measurement_repository.dart';
import '../core/formatters.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import 'measurement_detail_view_model.dart';
import 'widgets/measurement_dialogs.dart';

/// Tek bir ölçüm türünün detay ekranı: grafik, ölçüm listesi ve (özel türse) türü silme.
class MeasurementDetailScreen extends StatelessWidget {
  const MeasurementDetailScreen({super.key, required this.type});

  final MeasurementType type;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MeasurementDetailViewModel(
        context.read<MeasurementRepository>(),
        type: type,
      )..load(),
      child: const _MeasurementDetailView(),
    );
  }
}

/// Üst menünün seçenekleri.
enum _DetailMenuAction { deleteType }

class _MeasurementDetailView extends StatelessWidget {
  const _MeasurementDetailView();

  /// Grafiğin yüksekliği.
  static const double _chartHeight = 220;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MeasurementDetailViewModel>();
    _showPendingError(context, viewModel);
    final type = viewModel.type;

    return Scaffold(
      appBar: AppBar(
        title: Text(type.name),
        actions: [
          if (!type.isBuiltin)
            PopupMenuButton<_DetailMenuAction>(
              tooltip: 'Seçenekler',
              onSelected: (_) => _confirmDeleteType(context, viewModel),
              itemBuilder: (_) => const [
                PopupMenuItem<_DetailMenuAction>(
                  value: _DetailMenuAction.deleteType,
                  child: Text('Ölçümü sil'),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ölçüm ekle',
        onPressed: () => _add(context, viewModel),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, MeasurementDetailViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.isEmpty) {
      return const EmptyState(
        icon: Icons.straighten,
        title: 'Henüz ölçüm yok',
        message: 'İlk ölçümünü eklediğinde burada görünür.',
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final mutedStyle = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final unit = viewModel.type.unit;
    final measurements = viewModel.measurements; // en eskiden en yeniye

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
        88, // Ekleme düğmesinin altta kalmaması için boşluk.
      ),
      children: [
        if (measurements.length >= 2)
          SizedBox(
            height: _chartHeight,
            child: _MeasurementChart(measurements: measurements, unit: unit),
          )
        else
          Text('Grafik için en az iki ölçüm gerekli.', style: mutedStyle),
        const SizedBox(height: AppSpacing.xl),
        Text('Ölçümler', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final measurement in measurements.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _MeasurementRow(
              measurement: measurement,
              unit: unit,
              onTap: () => _edit(context, viewModel, measurement),
              onDelete: () => _delete(context, viewModel, measurement),
            ),
          ),
      ],
    );
  }

  /// Ölçüm ekleme diyaloğunu açar; kaydedilirse listeyi yeniler.
  Future<void> _add(BuildContext context, MeasurementDetailViewModel viewModel) async {
    final result = await showMeasurementDialog(context, type: viewModel.type);
    if (result == null) return;
    await viewModel.addMeasurement(result.value, result.measuredAt);
  }

  /// Düzenleme diyaloğunu açar (değer ve tarih); onaylanırsa ölçümü günceller.
  Future<void> _edit(
    BuildContext context,
    MeasurementDetailViewModel viewModel,
    BodyMeasurement measurement,
  ) async {
    final result = await showMeasurementDialog(
      context,
      type: viewModel.type,
      initial: measurement,
    );
    if (result == null) return;
    await viewModel.updateMeasurement(
      measurement,
      value: result.value,
      measuredAt: result.measuredAt,
    );
  }

  /// Tek bir kaydı siler; SnackBar'daki "Geri al" ile geri ekler.
  Future<void> _delete(
    BuildContext context,
    MeasurementDetailViewModel viewModel,
    BodyMeasurement measurement,
  ) async {
    final deleted = await viewModel.deleteMeasurement(measurement);
    if (!deleted || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kayıt silindi.'),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => viewModel.restoreMeasurement(measurement),
        ),
      ),
    );
  }

  /// Özel türü silmek için onay ister; onaylanırsa türü siler ve ekranı kapatır.
  Future<void> _confirmDeleteType(
    BuildContext context,
    MeasurementDetailViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ölçümü sil'),
        content: const Text('Bu ölçüm ve tüm kayıtları silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await viewModel.deleteType();
    if (!deleted || !context.mounted) return;
    Navigator.of(context).pop();
  }

  /// ViewModel'in bekleyen hata mesajını SnackBar ile gösterir ve temizler.
  void _showPendingError(BuildContext context, MeasurementDetailViewModel viewModel) {
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

/// Bir ölçüm satırı: tarih, değer ve silme düğmesi. Dokununca düzenlenir.
class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({
    required this.measurement,
    required this.unit,
    required this.onTap,
    required this.onDelete,
  });

  final BodyMeasurement measurement;
  final String unit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.sm,
        ),
        title: Text(
          DateFormat('d MMMM y', 'tr').format(measurement.measuredAt),
          style: textTheme.bodyLarge,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${formatWeight(measurement.value)} $unit',
              style: textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Kaydı sil',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ölçümlerin çizgi grafiği: x ekseni sırayla ölçümler, alt eksende kısa tarihler. Renkler temadan gelir.
class _MeasurementChart extends StatelessWidget {
  const _MeasurementChart({required this.measurements, required this.unit});

  /// En eskiden en yeniye.
  final List<BodyMeasurement> measurements;
  final String unit;

  /// Alt eksende en fazla bu kadar tarih yazılır; fazlası üst üste biner.
  static const int _maxDateLabels = 4;

  static const double _lineWidth = 3;
  static const double _dotRadius = 4;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    final values = [for (final m in measurements) m.value];

    // Y ekseni: verinin biraz altı ve üstü; tüm değerler eşitse yine de bir aralık olsun.
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    var padding = (highest - lowest) * 0.1;
    if (padding == 0) padding = math.max(1, highest * 0.1);

    final dateStep = (measurements.length / _maxDateLabels).ceil();

    return Semantics(
      label: 'Ölçüm grafiği: ilk değer ${formatWeight(values.first)} $unit, '
          'son değer ${formatWeight(values.last)} $unit',
      child: ExcludeSemantics(
        child: LineChart(
          LineChartData(
            minY: math.max(0, lowest - padding),
            maxY: highest + padding,
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v),
                ],
                color: colorScheme.primary,
                barWidth: _lineWidth,
                dotData: FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: _dotRadius,
                    color: colorScheme.primary,
                    strokeWidth: 0,
                  ),
                ),
              ),
            ],
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: colorScheme.outline, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: textScaler.scale(AppSpacing.xxl + AppSpacing.lg),
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(formatWeight(value.roundToDouble()), style: labelStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: textScaler.scale(AppSpacing.xxl),
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    // Son ölçümden geriye doğru her dateStep'te bir tarih.
                    final show = value == i &&
                        i >= 0 &&
                        i < measurements.length &&
                        (measurements.length - 1 - i) % dateStep == 0;
                    if (!show) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        DateFormat('d MMM', 'tr').format(measurements[i].measuredAt),
                        style: labelStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${formatWeight(spot.y)} $unit\n'
                      '${DateFormat('d MMM y', 'tr').format(measurements[spot.x.round()].measuredAt)}',
                      textTheme.bodySmall!.copyWith(color: colorScheme.onSurface),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
