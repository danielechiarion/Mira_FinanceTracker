import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/classes/financial_instruments/elements/StepInterest.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/frontend/single_elements/LongDurationField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/NumericAmountField.dart';

/// Reusable widget to manage the list of [StepInterest] entries of a
/// bond model: it shows every step already configured and lets the
/// user add, edit or remove one of them.
///
/// Positions are always kept sequential (0, 1, 2, ...) matching the
/// order shown on screen, so the caller doesn't have to deal with
/// position bookkeeping.
class StepInterestEditor extends StatefulWidget {
  final List<StepInterest> initialInterests;
  final ValueChanged<List<StepInterest>> onChanged;

  const StepInterestEditor({
    super.key,
    required this.onChanged,
    this.initialInterests = const [],
  });

  @override
  State<StepInterestEditor> createState() => _StepInterestEditorState();
}

class _StepInterestEditorState extends State<StepInterestEditor> {
  late List<StepInterest> _interests;

  @override
  void initState() {
    super.initState();
    _interests = widget.initialInterests.map((i) => i.clone()).toList()..sort();
  }

  /// Re-assigns positions sequentially (matching the order shown on
  /// screen) and notifies the caller of the updated list.
  void _commitChanges() {
    for (int i = 0; i < _interests.length; i++) {
      _interests[i].position = i;
    }
    widget.onChanged(List.from(_interests));
    setState(() {});
  }

  /// Opens a dialog to create a new step interest or edit an
  /// [existing] one.
  Future<void> _openStepDialog({StepInterest? existing}) async {
    LongDuration duration = existing?.duration ?? const LongDuration();
    final rateController = TextEditingController(
      text: existing != null ? existing.interestRate.toString() : '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existing == null ? 'Nuovo step interesse' : 'Modifica step interesse',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LongDurationField(
              label: 'Durata dello step',
              initialValue: duration,
              onChanged: (value) => duration = value,
            ),
            const SizedBox(height: 16),
            InterestAmountField(
              controller: rateController,
              label: 'Tasso di interesse',
              isRequired: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ANNULLA', style: TextStyle(color: Colors.teal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('SALVA'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final double? rate = double.tryParse(rateController.text);
    if (rate == null || rate <= 0) return;

    final int position = existing?.position ?? _interests.length;
    final newInterest = StepInterest(position, duration, rate);

    if (existing != null) {
      final index = _interests.indexWhere((i) => i.position == existing.position);
      if (index != -1) _interests[index] = newInterest;
    } else {
      _interests.add(newInterest);
    }

    _interests.sort();
    _commitChanges();
  }

  void _removeStep(StepInterest interest) {
    _interests.removeWhere((i) => i.position == interest.position);
    _commitChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step di interesse', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_interests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nessuno step configurato', style: TextStyle(color: Colors.black54)),
          ),
        ..._interests.map(
          (interest) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: Text('Step ${interest.position + 1}: ${interest.duration}'),
              subtitle: Text('Tasso: ${interest.interestRate}%'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.teal, size: 20),
                    onPressed: () => _openStepDialog(existing: interest),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _removeStep(interest),
                  ),
                ],
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _openStepDialog(),
          icon: const Icon(Icons.add, color: Colors.indigo),
          label: const Text('Aggiungi step', style: TextStyle(color: Colors.indigo)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.indigo),
          ),
        ),
      ],
    );
  }
}