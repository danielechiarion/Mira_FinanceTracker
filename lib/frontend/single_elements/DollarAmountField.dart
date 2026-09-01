import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable input widget for double values (interest rates, tax
/// rates, ...) that only allows numeric input and shows it with a
/// leading dollar symbol, so every monetary/percentage field in the
/// app looks and behaves the same way.
class DollarAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isRequired;

  const DollarAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // only digits and a single decimal point are allowed
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '€ ',
      ),
      validator: (value) {
        if (!isRequired) return null;
        if (value == null || value.trim().isEmpty) {
          return 'Campo obbligatorio';
        }
        final double? parsed = double.tryParse(value);
        if (parsed == null || parsed <= 0) {
          return 'Inserisci un valore valido';
        }
        return null;
      },
    );
  }
}

class InterestAmountField extends DollarAmountField {
  const InterestAmountField({
    super.key,
    required super.controller,
    required super.label,
    super.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // only digits and a single decimal point are allowed
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '% ',
      ),
      validator: (value) {
        if (!isRequired) return null;
        if (value == null || value.trim().isEmpty) {
          return 'Campo obbligatorio';
        }
        final double? parsed = double.tryParse(value);
        if (parsed == null || parsed <= 0) {
          return 'Inserisci un valore valido';
        }
        return null;
      },
    );
  }
}