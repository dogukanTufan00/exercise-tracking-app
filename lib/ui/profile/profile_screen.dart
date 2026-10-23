import 'package:flutter/material.dart';

/// Profil sekmesi: kilo, boy ve mezura ölçümleri (#14).
///
/// İSKELET: Dalga 9 Ajan R dolduracak (bkz. docs/agent-briefs/wave9-r-profile-screen.md).
/// Kurucu imzası değişmez; alt gezinme çubuğu bu ekranı `const ProfileScreen()` olarak kullanır.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: const SizedBox.shrink(),
    );
  }
}
