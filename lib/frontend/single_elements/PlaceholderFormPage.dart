import 'package:flutter/material.dart';

/// Temporary placeholder page used for add/edit flows whose real form
/// isn't built yet (fees, cashback, direct debits, periodic credits, ...).
/// Replace usages of this widget with the real forms once the
/// corresponding models/pages are ready.
class PlaceholderFormPage extends StatelessWidget {
  final String title;

  const PlaceholderFormPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: const Center(child: Text('Form in arrivo')),
    );
  }
}