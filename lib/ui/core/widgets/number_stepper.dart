import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formatters.dart';
import '../theme/app_spacing.dart';

/// Değeri `−` ve `+` butonlarıyla adım adım değiştiren kontrol.
///
/// Değerin üstüne dokunulursa klavyeyle doğrudan girilebilir. Ağırlık için
/// `step: 2.5`, tekrar için `step: 1, allowDecimal: false` kullanılır.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.step,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.unit,
    required this.label,
    this.allowDecimal = true,
  });

  /// Gösterilen değer.
  final double value;

  /// Butonların her basışta değiştireceği miktar.
  final double step;

  /// Değer değiştiğinde yeni değerle çağrılır.
  final ValueChanged<double> onChanged;

  /// Girilebilecek en küçük değer.
  final double min;

  /// Girilebilecek en büyük değer; null ise üst sınır yoktur.
  final double? max;

  /// Değerin yanında küçük yazılan birim (ör. "kg").
  final String? unit;

  /// Ekran okuyucu ve giriş diyaloğu başlığı (ör. "Ağırlık").
  final String label;

  /// Ondalıklı değere izin verilip verilmediği.
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final lower = _round(value - step);
    final upper = _round(value + step);
    final canDecrease = lower >= min;
    final canIncrease = max == null || upper <= max!;

    final valueText = formatWeight(value);

    return Semantics(
      label: label,
      value: unit == null ? valueText : '$valueText $unit',
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Azalt',
              color: colorScheme.onSurface,
              disabledColor: colorScheme.onSurfaceVariant,
              onPressed: canDecrease
                  ? () {
                      HapticFeedback.selectionClick();
                      onChanged(lower);
                    }
                  : null,
            ),
            Expanded(
              child: InkWell(
                onTap: () => _editValue(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    // Dar alanda değer ve birim küçülerek sığar; taşmaz.
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              valueText,
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (unit != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                unit!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Artır',
              color: colorScheme.onSurface,
              disabledColor: colorScheme.onSurfaceVariant,
              onPressed: canIncrease
                  ? () {
                      HapticFeedback.selectionClick();
                      onChanged(upper);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editValue(BuildContext context) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _NumberInputDialog(
        label: label,
        initialValue: value,
        min: min,
        max: max,
        allowDecimal: allowDecimal,
      ),
    );
    if (result != null) {
      onChanged(_round(result));
    }
  }

  /// Kayan nokta hatalarını (ör. 60.1 + 2.5) gidermek için 2 basamağa yuvarlar.
  static double _round(double v) => double.parse(v.toStringAsFixed(2));
}

/// Değeri klavyeyle girmek için açılan diyalog. Geçerli değer girilene kadar kapanmaz.
class _NumberInputDialog extends StatefulWidget {
  const _NumberInputDialog({
    required this.label,
    required this.initialValue,
    required this.min,
    required this.max,
    required this.allowDecimal,
  });

  final String label;
  final double initialValue;
  final double min;
  final double? max;
  final bool allowDecimal;

  @override
  State<_NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<_NumberInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final text = formatWeight(widget.initialValue);
    _controller = TextEditingController(text: text)
      ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = parseDecimal(_controller.text);
    final error = _validate(parsed);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  /// Girdi geçerliyse null, değilse kullanıcıya gösterilecek hata metnini döner.
  String? _validate(double? value) {
    if (value == null) return 'Geçerli bir sayı girin';
    if (!widget.allowDecimal && value % 1 != 0) {
      return 'Bu alanda ondalıklı değer girilemez';
    }
    if (value < widget.min) {
      return 'En az ${formatWeight(widget.min)} olmalı';
    }
    final max = widget.max;
    if (max != null && value > max) {
      return 'En fazla ${formatWeight(max)} olmalı';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.allowDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
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
          child: const Text('Tamam'),
        ),
      ],
    );
  }
}
