import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/models.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_spacing.dart';

/// Ölçüm ekleme/düzenleme diyaloğunu açar. [initial] verilirse düzenleme (değer ve tarih dolu).
/// Kaydedilen tarih o günün 12:00'sidir. İptalde `null` döner.
Future<({double value, DateTime measuredAt})?> showMeasurementDialog(
  BuildContext context, {
  required MeasurementType type,
  BodyMeasurement? initial,
}) {
  return showDialog<({double value, DateTime measuredAt})>(
    context: context,
    builder: (_) => _MeasurementDialog(type: type, initial: initial),
  );
}

/// Özel ölçüm türü diyaloğu: ad + birim (varsayılan "cm"). İptalde `null` döner.
Future<({String name, String unit})?> showMeasurementTypeDialog(BuildContext context) {
  return showDialog<({String name, String unit})>(
    context: context,
    builder: (_) => const _MeasurementTypeDialog(),
  );
}

/// Bir tarihin gün kısmı (saat sıfırlanmış).
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Ölçüm değeri ve tarihi için diyalog. Değer 0'dan büyük olmalı; değilse Kaydet kapalıdır.
class _MeasurementDialog extends StatefulWidget {
  const _MeasurementDialog({required this.type, this.initial});

  final MeasurementType type;
  final BodyMeasurement? initial;

  @override
  State<_MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<_MeasurementDialog> {
  static const String _invalidMessage = "0'dan büyük bir değer girin";

  late final TextEditingController _valueController;
  late DateTime _date;

  /// Kullanıcı alana bir şey yazdıktan sonra hata mesajı gösterilir.
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _valueController = TextEditingController(
      text: initial == null ? '' : formatWeight(initial.value),
    );

    // Gelecek tarih seçilemez: başlangıç tarihi bugünü geçemez.
    final today = _dateOnly(DateTime.now());
    final start = _dateOnly(initial?.measuredAt ?? today);
    _date = start.isAfter(today) ? today : start;
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  double? get _value => parseDecimal(_valueController.text);

  bool get _isValid {
    final value = _value;
    return value != null && value > 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: _dateOnly(DateTime.now()),
    );
    if (picked == null) return;
    setState(() => _date = _dateOnly(picked));
  }

  void _save() {
    final value = _value;
    if (value == null || value <= 0) return;
    Navigator.of(context).pop((
      value: value,
      measuredAt: DateTime(_date.year, _date.month, _date.day, 12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showError = _touched && !_isValid;

    return AlertDialog(
      title: Text(widget.type.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _valueController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Değer',
                suffixText: widget.type.unit,
                errorText: showError ? _invalidMessage : null,
              ),
              onChanged: (_) => setState(() => _touched = true),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.calendar_today_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              title: Text(DateFormat('d MMMM y', 'tr').format(_date)),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _isValid ? _save : null,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Özel ölçüm türü için ad ve birim diyaloğu. Ad ve birim boşsa Kaydet kapalıdır.
class _MeasurementTypeDialog extends StatefulWidget {
  const _MeasurementTypeDialog();

  @override
  State<_MeasurementTypeDialog> createState() => _MeasurementTypeDialogState();
}

class _MeasurementTypeDialogState extends State<_MeasurementTypeDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: 'cm');

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _unitController.text.trim().isNotEmpty;

  void _save() {
    Navigator.of(context).pop((
      name: _nameController.text.trim(),
      unit: _unitController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Özel ölçüm ekle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ad'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Birim'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
