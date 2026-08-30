import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';

/// Reusable input widget to let the user compose a [LongDuration]
/// value from three separate numeric fields (years, months, days).
///
/// The widget keeps its own text controllers in sync with the
/// [initialValue] provided and notifies the caller through
/// [onChanged] every time one of the three fields is edited, so it
/// can be dropped inside any [Form] the same way a normal
/// [TextFormField] would be.
class LongDurationField extends StatefulWidget {
  final String label;
  final LongDuration? initialValue;
  final ValueChanged<LongDuration> onChanged;

  const LongDurationField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue,
  });

  @override
  State<LongDurationField> createState() => _LongDurationFieldState();
}

class _LongDurationFieldState extends State<LongDurationField> {
  late final TextEditingController _yearsController;
  late final TextEditingController _monthsController;
  late final TextEditingController _daysController;

  @override
  void initState() {
    super.initState();
    _yearsController = TextEditingController(text: '${widget.initialValue?.years ?? 0}');
    _monthsController = TextEditingController(text: '${widget.initialValue?.months ?? 0}');
    _daysController = TextEditingController(text: '${widget.initialValue?.days ?? 0}');
  }

  /// Builds a [LongDuration] out of the current controllers content
  /// and notifies the caller through [LongDurationField.onChanged].
  void _notifyChange() {
    final int years = int.tryParse(_yearsController.text) ?? 0;
    final int months = int.tryParse(_monthsController.text) ?? 0;
    final int days = int.tryParse(_daysController.text) ?? 0;

    widget.onChanged(LongDuration(years: years, months: months, days: days));
  }

  Widget _buildUnitField(TextEditingController controller, String suffix) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (_) => _notifyChange(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildUnitField(_yearsController, 'anni'),
            const SizedBox(width: 8),
            _buildUnitField(_monthsController, 'mesi'),
            const SizedBox(width: 8),
            _buildUnitField(_daysController, 'giorni'),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _yearsController.dispose();
    _monthsController.dispose();
    _daysController.dispose();
    super.dispose();
  }
}