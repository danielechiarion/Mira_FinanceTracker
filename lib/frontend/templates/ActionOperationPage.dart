import 'package:flutter/material.dart';

/// Reusable page structure for a single action.
/// Every action-specific page should be built on top of this widget:
/// it takes care of the general layout (title, input area, confirm and
/// cancel buttons) so that every action in the app looks and behaves
/// consistently, while leaving the actual input fields and the
/// save/processing logic to the caller.
///
/// * [title] shown in the app bar
/// * [inputBuilder] builds the action-specific input section
/// * [formKey] optional form key: if provided, validation is run
///   before [onConfirm] is called (pass it only if [inputBuilder]
///   wraps its fields inside a [Form] using the same key)
/// * [onConfirm] called after validation succeeds; this is where each
///   action should call its own save/processing function(s)
/// * [onCancel] optional custom behaviour for the cancel button,
///   defaults to simply popping the page
class ActionOperationPage extends StatefulWidget {
  final String title;
  final GlobalKey<FormState>? formKey;
  final WidgetBuilder inputBuilder;
  final Future<void> Function(BuildContext context) onConfirm;
  final VoidCallback? onCancel;

  const ActionOperationPage({
    super.key,
    required this.title,
    required this.inputBuilder,
    required this.onConfirm,
    this.formKey,
    this.onCancel,
  });

  @override
  State<ActionOperationPage> createState() => _ActionOperationPageState();
}

class _ActionOperationPageState extends State<ActionOperationPage> {
  late final Widget _input;

  /// Whether the confirm action is currently being processed.
  /// Used to disable the buttons and show a loading state while
  /// the save/processing function(s) are running.
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _input = Builder(builder: widget.inputBuilder);
  }

  /// Validates the form (if any) and delegates the actual
  /// save/processing work to the action-specific [ActionOperationPage.onConfirm].
  Future<void> _handleConfirm() async {
    if (widget.formKey != null &&
        !(widget.formKey!.currentState?.validate() ?? true)) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      /* this is where every specific action page plugs in
      its own save/processing function(s) */
      await widget.onConfirm(context);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Cancels the operation, either with the custom behaviour
  /// provided by the caller or by simply popping the page.
  void _handleCancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- ACTION-SPECIFIC INPUT AREA ---
                    _input,
                    const SizedBox(height: 32),

                    // --- CONFIRM BUTTON ---
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'CONFERMA',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // --- CANCEL BUTTON ---
                    OutlinedButton(
                      onPressed: _isProcessing ? null : _handleCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(
                          color: Color(0xFFD1D1D1),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'ANNULLA',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
