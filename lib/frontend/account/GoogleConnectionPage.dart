import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackupCleaner.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackupReader.dart';
import 'package:mira_finance_tracker/backend/operation/account/GoogleAccountConnection.dart';
import 'package:mira_finance_tracker/frontend/account/LoginPage.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Page shown after signup to optionally connect a Google account.
/// The user can skip this step and continue to the login page.
class GoogleConnectionPage extends StatefulWidget {
  final User user;
  final bool returnToSettings;

  /// Creates a [GoogleConnectionPage] widget instance.
  const GoogleConnectionPage({
    super.key,
    required this.user,
    this.returnToSettings = false,
  });

  @override
  State<GoogleConnectionPage> createState() => _GoogleConnectionPageState();
}

class _GoogleConnectionPageState extends State<GoogleConnectionPage> {
  final TextEditingController _decryptionKeyController =
      TextEditingController();
  bool _isConnecting = false;
  String? _connectedEmail;
  String? _errorMessage;
  String? _importStatus;

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

  @override
  void dispose() {
    _decryptionKeyController.dispose();
    super.dispose();
  }

  /// Connects Google after validating the encrypted cloud key.
  Future<void> _connectGoogleAccount() async {
    final decryptionKey = _decryptionKeyController.text.trim();

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _importStatus = null;
    });

    final authenticationManager = GoogleAuthenticationManager();
    try {
      // Invoke the backend operation to validate cloud ownership and decryption
      // before it saves Google credentials or associates the email with this user.
      final connection = GoogleAccountConnection(
        widget.user,
        authenticationManager,
      );
      await connection.execute(decryptionKey.isEmpty ? null : decryptionKey);

      final email = authenticationManager.email;
      if (email == null || email.isEmpty) {
        throw StateError('Google non ha restituito un indirizzo email.');
      }

      if (!mounted) return;
      setState(() {
        _connectedEmail = email;
        _importStatus = 'Controllo dei dati su Google Drive...';
      });

      try {
        final hasBackup = await _importInitialBackup(authenticationManager);
        if (!mounted) return;
        setState(() {
          _importStatus = hasBackup
              ? 'Importazione iniziale completata.'
              : 'Account collegato. Non è stato trovato un backup da importare.';
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Account collegato, ma importazione iniziale non riuscita: $error';
          _importStatus = null;
        });
      }
    } on CloudAccountOwnershipException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connessione a Google non riuscita: $error';
      });
      final googleEmail = authenticationManager.email;
      if (googleEmail != null && googleEmail.isNotEmpty) {
        await _offerCloudReset(authenticationManager, googleEmail);
      }
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

  /// Offers a destructive cloud reset only after a cloud ownership conflict.
  Future<void> _offerCloudReset(
    GoogleAuthenticationManager authenticationManager,
    String googleEmail,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account Mira diverso trovato'),
        content: const Text(
          'Lo spazio Google contiene dati associati a un altro account Mira. '
          'Puoi eliminare definitivamente tutti i dati cloud di questa '
          'app e poi riprovare. Questa operazione riguarda anche gli altri '
          'dispositivi collegati e non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('RESETTA CLOUD'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    try {
      final localAuth = LocalAuthentication();
      if (!await localAuth.isDeviceSupported()) {
        throw StateError('Lo sblocco del dispositivo non è disponibile.');
      }
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Sblocca per confermare il reset dei dati cloud',
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) {
        throw StateError('Autenticazione del dispositivo non riuscita.');
      }
      if (!mounted) return;

      setState(() {
        _errorMessage = null;
        _importStatus = 'Reset dei dati cloud in corso...';
      });

      final cleaner = CloudBackupCleaner(
        widget.user,
        authentication: authenticationManager,
        email: googleEmail,
        forceReset: true,
      );
      try {
        await cleaner.init();
        await cleaner.execute();
      } finally {
        await cleaner.dispose();
      }

      if (!mounted) return;
      setState(() {
        _importStatus =
            'Dati cloud eliminati. Puoi riprovare a collegare l’account Google.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _importStatus = null;
        _errorMessage = 'Reset dei dati cloud non riuscito: $error';
      });
    }
  }

  Future<bool> _importInitialBackup(
    GoogleAuthenticationManager authenticationManager,
  ) async {
    final reader = CloudBackupReader(
      widget.user,
      authentication: authenticationManager,
      strictImport: true,
    );
    try {
      await reader.init();
      if (await reader.isDriveEmpty()) return false;

      await reader.execute();
      return true;
    } finally {
      await reader.dispose();
    }
  }

  /// Replaces this page with the login page.
  void _continueToLogin() {
    if (widget.returnToSettings) {
      Navigator.of(context).pop(_connectedEmail != null);
      return;
    }

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
                          ? widget.returnToSettings
                                ? 'Collega Google'
                                : 'Account creato!'
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
                          ? widget.returnToSettings
                                ? 'Collega Google Drive al tuo account Mira. '
                                      'La chiave di decifratura sarà richiesta '
                                      'solo se lo spazio cloud contiene già dati.'
                                : 'Collega Google per verificare lo spazio cloud. '
                                      'La chiave di decifratura sarà necessaria solo '
                                      'se esistono già dati cloud o altri dispositivi collegati.'
                          : 'È stato collegato l\'account $connectedEmail.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (_importStatus != null) ...[
                      const SizedBox(height: 20),
                      if (_isConnecting)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.teal),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        _importStatus!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (connectedEmail == null) ...[
                      TextField(
                        controller: _decryptionKeyController,
                        obscureText: true,
                        enabled: !_isConnecting,
                        decoration: InputDecoration(
                          labelText: 'Chiave di decifratura (se richiesta)',
                          hintText: 'Necessaria solo per dati cloud esistenti',
                          prefixIcon: const Icon(Icons.key, color: Colors.teal),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.teal.shade300,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.teal,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                        onPressed: _isConnecting ? null : _continueToLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'CONTINUA',
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
                        child: Text(
                          widget.returnToSettings
                              ? 'TORNA ALLE IMPOSTAZIONI'
                              : 'SALTA E TORNA AL LOGIN',
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
