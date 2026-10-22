import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/frontend/account/LoginPage.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Page shown after signup to optionally connect a Google account.
/// The user can skip this step and continue to the login page.
class GoogleConnectionPage extends StatefulWidget {
  final SystemDatabaseWrapper database;
  final User user;

  /// Creates a [GoogleConnectionPage] widget instance.
  GoogleConnectionPage({super.key, required this.user})
    : database = SystemDatabaseWrapper();

  @override
  State<GoogleConnectionPage> createState() => _GoogleConnectionPageState();
}

class _GoogleConnectionPageState extends State<GoogleConnectionPage> {
  bool _isConnecting = false;
  String? _connectedEmail;
  String? _errorMessage;

  /// Checks whether Google account connection is available on this platform.
  bool get _canConnectGoogle {
    if (kIsWeb) return true;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  /// Connects the Google account and saves its credentials to the system database.
  Future<void> _connectGoogleAccount() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final authenticationManager = GoogleAuthenticationManager();
    try {
      await authenticationManager.init();
      await authenticationManager.signIn();

      if (!mounted) return;
      await widget.database.init();
      await widget.database.updateUserEmail(
        widget.user,
        authenticationManager.email!,
      );
      await widget.database.closeDatabase();
      setState(() {
        _connectedEmail = authenticationManager.email;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connessione a Google non riuscita: $error';
      });
    } finally {
      try {
        await authenticationManager.close();
      } catch (error) {
        if (mounted) {
          setState(() {
            _errorMessage ??= 'Errore durante la chiusura del database: $error';
          });
        }
      }
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  /// Replaces this page with the login page.
  void _continueToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectedEmail = _connectedEmail;
    final canConnectGoogle = _canConnectGoogle;

    return Scaffold(
      appBar: AppBar(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      connectedEmail == null
                          ? Icons.cloud_outlined
                          : Icons.cloud_done_rounded,
                      size: 72,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      connectedEmail == null
                          ? 'Account creato!'
                          : 'Account Google collegato',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      connectedEmail == null
                          ? 'Vuoi collegare il tuo account Google per usare le funzionalità cloud? '
                                'Puoi farlo ora oppure saltare questo passaggio.'
                          : 'È stato collegato l\'account $connectedEmail.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (connectedEmail == null && canConnectGoogle)
                      ElevatedButton.icon(
                        onPressed: _isConnecting ? null : _connectGoogleAccount,
                        icon: _isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.account_circle_outlined),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        label: Text(
                          _isConnecting
                              ? 'Connessione in corso...'
                              : 'COLLEGA ACCOUNT GOOGLE',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    if (connectedEmail == null && !canConnectGoogle)
                      Text(
                        'La connessione Google non è disponibile su questa '
                        'piattaforma. Usa Android, iOS, macOS, Windows o la '
                        'versione web.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    if (connectedEmail != null)
                      ElevatedButton(
                        onPressed: _continueToLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'CONTINUA AL LOGIN',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    if (connectedEmail == null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isConnecting ? null : _continueToLogin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(
                            color: Colors.teal,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'SALTA E TORNA AL LOGIN',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
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
