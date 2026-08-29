import 'dart:async';
import 'package:flutter/material.dart';

/// Text field that checks, with debounce, whether a name is already
/// registered, following the same real-time check pattern used for the
/// username field during signup. If the current value equals
/// [initialName] the field is treated as available without checking,
/// since that is the entry currently being edited.
class UniqueNameField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? initialName;
  final Future<bool> Function(String name) checkAvailability;
  final ValueChanged<bool> onAvailabilityChanged;

  const UniqueNameField({
    super.key,
    required this.controller,
    required this.label,
    required this.checkAvailability,
    required this.onAvailabilityChanged,
    this.initialName,
  });

  @override
  State<UniqueNameField> createState() => _UniqueNameFieldState();
}

class _UniqueNameFieldState extends State<UniqueNameField> {
  Timer? _debounceTimer;
  int _requestId = 0;
  bool _isChecking = false;
  bool _isAvailable = false;
  String? _availabilityMessage;

  @override
  void initState() {
    super.initState();
    _isAvailable = widget.controller.text == widget.initialName;
    widget.onAvailabilityChanged(_isAvailable);
  }

  @override
  void dispose() {
    _requestId++;
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    final requestId = ++_requestId;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    // unchanged value while editing: no need to check again
    if (value == widget.initialName) {
      setState(() {
        _isChecking = false;
        _isAvailable = true;
        _availabilityMessage = null;
      });
      widget.onAvailabilityChanged(true);
      return;
    }

    setState(() {
      _isChecking = true;
      _availabilityMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (value.isEmpty) {
        if (!mounted || requestId != _requestId) return;
        setState(() => _isChecking = false);
        widget.onAvailabilityChanged(false);
        return;
      }

      bool available;
      try {
        available = await widget.checkAvailability(value);
      } catch (e) {
        if (!mounted || requestId != _requestId) return;
        print(e);
        setState(() {
          _isChecking = false;
          _isAvailable = false;
          _availabilityMessage = 'Impossibile verificare il nome';
        });
        widget.onAvailabilityChanged(false);
        return;
      }
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _isChecking = false;
        _isAvailable = available;
        _availabilityMessage = available
            ? 'Nome disponibile'
            : 'Nome già in uso';
      });
      widget.onAvailabilityChanged(available);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      onChanged: _onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: _availabilityMessage,
        helperStyle: TextStyle(color: _isAvailable ? Colors.green : Colors.red),
        suffixIcon: _isChecking
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : (_availabilityMessage == null
                  ? null
                  : Icon(
                      _isAvailable ? Icons.check_circle : Icons.error,
                      color: _isAvailable ? Colors.green : Colors.red,
                    )),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Il valore deve essere impostato';
        }
        if (!_isAvailable) return 'Questo nome è già in uso';
        return null;
      },
    );
  }
}
