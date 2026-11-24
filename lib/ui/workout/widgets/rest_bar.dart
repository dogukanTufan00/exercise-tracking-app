import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/rest/rest_controller.dart';
import '../../../domain/rest_timer.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_spacing.dart';

/// Antrenman ekranının altındaki dinlenme şeridi (§16.2).
///
/// Sayaç bu antrenmana aitse görünür: kalan süre, ince ilerleme çubuğu, "−15", "+15" ve "Atla".
/// Saniyede bir yenilenir; zamanlayıcı yalnızca sayaç etkinken çalışır ve dispose'da iptal edilir.
/// Dolu (`FilledButton`) düğme kullanmaz; ekrandaki tek dolu düğme kuralı korunur.
class RestBar extends StatefulWidget {
  const RestBar({super.key, required this.controller, required this.workoutId});

  final RestController controller;
  final int workoutId;

  @override
  State<RestBar> createState() => _RestBarState();
}

class _RestBarState extends State<RestBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant RestBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    _syncTicker();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  void _onControllerChanged() {
    _syncTicker();
    if (mounted) setState(() {});
  }

  /// Sayaç bu antrenmana aitse saniyelik zamanlayıcıyı başlatır, değilse durdurur.
  void _syncTicker() {
    if (_isActive()) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  bool _isActive() {
    final rest = widget.controller.rest;
    return rest != null && rest.workoutId == widget.workoutId;
  }

  @override
  Widget build(BuildContext context) {
    final rest = widget.controller.rest;
    if (rest == null || rest.workoutId != widget.workoutId) {
      return const SizedBox.shrink();
    }

    final controller = widget.controller;
    final now = controller.clock();
    final seconds = restRemainingSeconds(rest, now);
    final fraction = restRemainingFraction(rest, now);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outline)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.sm,
          AppSpacing.screenPadding,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Dinlenme', style: textTheme.bodySmall),
                const Spacer(),
                Text(
                  formatRestClock(seconds),
                  style: textTheme.headlineMedium?.copyWith(fontSize: 36),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(
              value: fraction,
              minHeight: 3,
              color: colorScheme.primary,
              backgroundColor: colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => controller.adjust(-restStepSeconds),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(72, AppSpacing.minTouchTarget),
                  ),
                  child: const Text('−15'),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => controller.adjust(restStepSeconds),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(72, AppSpacing.minTouchTarget),
                  ),
                  child: const Text('+15'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => controller.skip(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(72, AppSpacing.minTouchTarget),
                  ),
                  child: const Text('Atla'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
