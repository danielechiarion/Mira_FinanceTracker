import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/backend/operation/account/GoogleAccountDisconnection.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';

/// Base page used to show a cloud connection error and recovery actions.
/// The user can reload the application or disconnect Google to continue
/// without cloud backup. The user cannot navigate back from this page.
class CloudErrorPage extends StatefulWidget {
  /// Icon representing the error
  final IconData icon;

  /// Main color of the icon
  final Color color;

  /// Short title of the error
  final String title;

  /// Description of the error
  final String message;

  /// Callback executed when the user presses the reload button
  final VoidCallback? onReload;

  /// Creates a [CloudErrorPage] widget instance.
  const CloudErrorPage({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.onReload,
  });

  @override
  State<CloudErrorPage> createState() => _CloudErrorPageState();
}

class _CloudErrorPageState extends State<CloudErrorPage> {
  bool _isDisconnectingGoogle = false;

  /// Confirms and disconnects Google, then returns to the app without backup.
  Future<void> _disconnectGoogleAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnettere Google?'),
        content: const Text(
          'I dati presenti nello spazio cloud verranno eliminati se non ci '
          'sono altri dispositivi registrati. Questa operazione non è reversibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Disconnetti'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDisconnectingGoogle = true);
    try {
      final session = await CurrentSession.getFromMemory();
      if (session == null) {
        throw StateError('Nessuna sessione attiva.');
      }
      final result = await GoogleAccountDisconnection(
        session.user,
      ).execute();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Disconnessione completata'),
          content: Text(result.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continua'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Disconnessione Google non riuscita: $error'),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isDisconnectingGoogle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope blocks the back button: no other page can be reached
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Image.asset(
              'assets/logos/extended_logo.png',
              height: 80,
              fit: BoxFit.contain,
            ),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.color.withOpacity(0.12),
                          ),
                          child: Icon(
                            widget.icon,
                            size: 72,
                            color: widget.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: _isDisconnectingGoogle
                            ? null
                            : _disconnectGoogleAccount,
                        icon: _isDisconnectingGoogle
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link_off),
                        label: Text(
                          _isDisconnectingGoogle
                              ? 'Disconnessione in corso...'
                              : 'Disconnetti account Google',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isDisconnectingGoogle
                            ? null
                            : widget.onReload ??
                                  () => Navigator.of(context)
                                      .pushNamedAndRemoveUntil(
                                        AppRoutes.home,
                                        (route) => false,
                                      ),
                        icon: const Icon(Icons.refresh),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        label: const Text(
                          'Ricarica applicazione',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}