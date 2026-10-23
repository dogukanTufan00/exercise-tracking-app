import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/progress.dart';
import '../core/formatters.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/exercise_edit_dialog.dart';
import '../core/widgets/muscle_group_chip.dart';
import 'exercise_detail_view_model.dart';

/// Hareket detay ekranı: kişisel rekorlar, ilerleme grafiği ve antrenman antrenman setler.
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ExerciseDetailViewModel(
        context.read<WorkoutRepository>(),
        exercise: exercise,
      )..load(),
      child: const _ExerciseDetailView(),
    );
  }
}

class _ExerciseDetailView extends StatelessWidget {
  const _ExerciseDetailView();

  /// Grafiğin yüksekliği.
  static const double _chartHeight = 220;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExerciseDetailViewModel>();
    _showPendingError(context, viewModel);

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.exercise.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Hareketi düzenle',
            onPressed: () => _edit(context, viewModel),
          ),
        ],
      ),
      body: _buildBody(context, viewModel),
    );
  }

  /// Düzenleme diyaloğunu açar; onaylanırsa hareketi günceller.
  Future<void> _edit(BuildContext context, ExerciseDetailViewModel viewModel) async {
    final edit = await showExerciseEditDialog(context, viewModel.exercise);
    if (edit == null) return;
    await viewModel.updateExercise(edit.name, edit.muscleGroup);
  }

  Widget _buildBody(BuildContext context, ExerciseDetailViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'Henüz set yok',
        message: 'Bu hareketle set kaydettiğinde ilerlemen burada görünür.',
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final mutedStyle = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final metric = viewModel.selectedMetric;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MuscleGroupChip(group: viewModel.exercise.muscleGroup),
        ),
        const SizedBox(height: AppSpacing.lg),
        _RecordsCard(
          records: viewModel.records,
          isBodyweight: viewModel.isBodyweight,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('İlerleme', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (viewModel.availableMetrics.length > 1) ...[
          SegmentedButton<ProgressMetric>(
            showSelectedIcon: false,
            segments: [
              for (final m in viewModel.availableMetrics)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {metric},
            onSelectionChanged: (selection) =>
                viewModel.selectMetric(selection.single),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (viewModel.stats.length >= 2)
          SizedBox(
            height: _chartHeight,
            child: _ProgressChart(
              stats: viewModel.stats,
              values: viewModel.values,
              metric: metric,
            ),
          )
        else
          Text(
            'Son değer: ${formatMetricValue(viewModel.values.single, metric)}. '
            'Grafik için en az iki antrenman gerekli.',
            style: mutedStyle,
          ),
        if (metric == ProgressMetric.estimatedOneRepMax) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tahmini 1RM, tek tekrarda kaldırabileceğin ağırlığın tahminidir '
            '(Epley: ağırlık × (1 + tekrar / 30)). 12 tekrarın üstünde isabeti düşer.',
            style: mutedStyle,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Antrenmanlar', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final session in viewModel.sessionsNewestFirst)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SessionCard(session: session),
          ),
      ],
    );
  }

  /// ViewModel'in bekleyen hata mesajını SnackBar ile gösterir ve temizler.
  void _showPendingError(
    BuildContext context,
    ExerciseDetailViewModel viewModel,
  ) {
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

/// Bir metrik değerini okunur metne çevirir: "82,3 kg", "12 tekrar".
///
/// Tahmini 1RM ondalıklı çıkabildiği için tek basamağa yuvarlanır.
String formatMetricValue(double value, ProgressMetric metric) {
  final unit = metric.unit;
  if (unit == null) return '${value.round()} tekrar';
  return '${formatWeight(double.parse(value.toStringAsFixed(1)))} $unit';
}

/// Kısa tarih: "8 Eki".
String _shortDate(DateTime date) => DateFormat('d MMM', 'tr').format(date);

/// Kişisel rekorlar kartı.
class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.records, required this.isBodyweight});

  final PersonalRecords records;
  final bool isBodyweight;

  @override
  Widget build(BuildContext context) {
    final rows = isBodyweight
        ? [
            ('En çok tekrar', records.mostReps, ProgressMetric.reps),
          ]
        : [
            ('En ağır', records.heaviest, ProgressMetric.heaviest),
            (
              'Tahmini 1RM',
              records.bestEstimatedOneRepMax,
              ProgressMetric.estimatedOneRepMax,
            ),
            ('En yüksek hacim', records.bestVolume, ProgressMetric.volume),
          ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Kişisel rekorlar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            for (final (label, record, metric) in rows)
              if (record != null)
                _RecordRow(label: label, record: record, metric: metric),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.label,
    required this.record,
    required this.metric,
  });

  final String label;
  final PersonalRecord record;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMetricValue(record.value, metric),
                style: textTheme.titleMedium,
              ),
              Text(
                _shortDate(record.workout.startedAt),
                style: textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Seçili metriğin antrenman başına çizgi grafiği. Renkler temadan gelir.
class _ProgressChart extends StatelessWidget {
  const _ProgressChart({
    required this.stats,
    required this.values,
    required this.metric,
  });

  /// En eskiden en yeniye; [values] ile aynı uzunlukta.
  final List<SessionStats> stats;
  final List<double> values;
  final ProgressMetric metric;

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

    // Y ekseni: verinin biraz altı ve üstü; tüm değerler eşitse yine de bir aralık olsun.
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    var padding = (highest - lowest) * 0.1;
    if (padding == 0) padding = math.max(1, highest * 0.1);

    final dateStep = (stats.length / _maxDateLabels).ceil();

    return Semantics(
      label: '${metric.label} grafiği: ilk değer '
          '${formatMetricValue(values.first, metric)}, son değer '
          '${formatMetricValue(values.last, metric)}',
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
                    // Son antrenmandan geriye doğru her dateStep'te bir tarih.
                    final show = value == i &&
                        i >= 0 &&
                        i < stats.length &&
                        (stats.length - 1 - i) % dateStep == 0;
                    if (!show) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _shortDate(stats[i].workout.startedAt),
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
                      '${formatMetricValue(spot.y, metric)}\n'
                      '${_shortDate(stats[spot.x.round()].workout.startedAt)}',
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

/// Bir antrenmandaki setler: tarih ve "60 kg × 10, 62,5 kg × 8".
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final workout = session.workout;
    final title = workout.title;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title == null
                  ? formatWorkoutDate(workout.startedAt)
                  : '$title · ${DateFormat('d MMMM y', 'tr').format(workout.startedAt)}',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              session.sets.map((s) => formatSet(s.weightKg, s.reps)).join(', '),
              style: textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
