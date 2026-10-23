import 'package:flutter/material.dart';

/// Program gününü düzenleme ekranı: ad, planlanan gün, hareketler ve hedefleri (#16).
///
/// İSKELET: Dalga 11 Ajan W2 dolduracak (bkz. docs/agent-briefs/wave11-w2-day-editor.md).
/// Kurucu imzası değişmez; program ekranı bu ekranı `DayEditScreen(dayId: ...)` ile açar.
class DayEditScreen extends StatelessWidget {
  const DayEditScreen({super.key, required this.dayId});

  /// Düzenlenen günün id'si.
  final int dayId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Günü düzenle')),
      body: const SizedBox.shrink(),
    );
  }
}
