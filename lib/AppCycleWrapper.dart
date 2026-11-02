import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:mira_finance_tracker/globals.dart';
import 'package:mira_finance_tracker/backend/cloud/operation/CloudFileExport.dart';
import 'package:mira_finance_tracker/backend/cloud/operation/CloudFileImport.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/frontend/error_pages/ErrorManager.dart';

/// Create app lifecycle listener to undrstand whether
/// to connect to backup or save information to update information
/// throughout all the application instances connected to the same account
class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;
  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper>
    with WindowListener {
  late final AppLifecycleListener _listener;
  bool _isClosing = false;
  bool _showCloseProgress = false;
  String _closeProgressMessage =
      'Verifica sessione e salvataggio backup in corso. '
      'Attendi prima della chiusura.';

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      debugPrint('[AppLifecycleWrapper] Listener chiusura desktop attivo.');
    }

    _listener = AppLifecycleListener(
      /* when pause save the content inside the drive
      and disconnect to it to let the resources
      free to other application instances */
      onPause: () async {
        if (_isDesktop) return;

        final session = await CurrentSession.getFromMemory();
        if (session == null) return;

        if (Platform.isAndroid && session.user.isUserConnected) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final taskId = "upload_drive_job_$timestamp";
          try {
            await Workmanager().registerOneOffTask(
              taskId,
              "mira.exportCloud",
              inputData: {'taskId': taskId},
              constraints: Constraints(networkType: NetworkType.connected),
              expedited: true,
              outOfQuotaPolicy: OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
              foregroundServiceConfig: ForegroundServiceConfig(
                notificationTitle: 'Salvataggio backup in corso',
                notificationText: 'Sincronizzazione con Google Drive',
                notificationChannelId: 'mira_cloud_backup',
                notificationChannelName: 'Backup cloud',
                notificationId: timestamp.remainder(100000),
                foregroundServiceType: ForegroundServiceType.dataSync,
              ),
            );
            debugPrint(
              '[AppLifecycleWrapper] Export cloud avviato come servizio '
              'foreground ($taskId).',
            );
            return;
          } catch (error, stackTrace) {
            debugPrint(
              '[AppLifecycleWrapper] Avvio servizio foreground export '
              'fallito, provo export diretto: '
              '$error\n$stackTrace',
            );
          }
        }

        if (Platform.isIOS) {
          await _exportCloudInForeground(session);
        }
      },
      /* when it's time to resume try to 
      connect and get the data, otherwise display errors */
      onResume: () async {
        if (Platform.isIOS || Platform.isAndroid) {
          await Workmanager().registerOneOffTask(
            "upload_drive_job_${DateTime.now().millisecondsSinceEpoch}",
            "mira.importCloud",
            constraints: Constraints(networkType: NetworkType.connected),
          );
        } else {
          CurrentSession? session = await CurrentSession.getFromMemory();
          if (session == null)
            return; // if the session is not found, end the function

          /* create the importer and execute all the operations */
          CloudFileImport importer = CloudFileImport(
            session,
            showErrorFunction: ErrorManager.redirectToErrorPageImport,
          );
          await importer.init();
          await importer.execute();
          await importer.dispose();
        }
      },
    );
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void onWindowClose() {
    if (!_isDesktop) return;
    _writeCloseDiagnostic('Evento close ricevuto dal window manager.');
    debugPrint('[AppLifecycleWrapper] Richiesta chiusura finestra ricevuta.');
    unawaited(_handleDesktopClose());
  }

  void _writeCloseDiagnostic(String message) {
    final logFile = File(
      '${Directory.systemTemp.path}\\mira_finance_tracker_close.log',
    );
    try {
      logFile.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } on FileSystemException catch (error) {
      debugPrint(
        '[AppLifecycleWrapper] Scrittura log chiusura fallita: $error',
      );
    }
  }

  void _updateCloseProgress(String message, {bool visible = true}) {
    _closeProgressMessage = message;
    _showCloseProgress = visible;
    if (mounted) setState(() {});
  }

  BuildContext get _navigatorContext =>
      navigatorKey.currentState?.overlay?.context ?? context;

  Future<void> _handleDesktopClose() async {
    if (_isClosing) {
      _writeCloseDiagnostic('Richiesta close ignorata: chiusura già in corso.');
      debugPrint(
        '[AppLifecycleWrapper] Chiusura già in corso; richiesta ignorata.',
      );
      return;
    }
    _isClosing = true;
    _updateCloseProgress(
      'Verifica sessione e salvataggio backup in corso. '
      'Attendi prima della chiusura.',
    );
    _writeCloseDiagnostic('Avvio procedura di chiusura.');
    debugPrint('[AppLifecycleWrapper] Avvio procedura chiusura desktop.');

    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      _writeCloseDiagnostic('Recupero sessione corrente.');
      final session = await CurrentSession.getFromMemory();
      _writeCloseDiagnostic(
        session == null
            ? 'Sessione non trovata.'
            : 'Sessione trovata; account cloud collegato: '
                  '${session.user.isUserConnected}.',
      );
      if (session != null && session.user.isUserConnected) {
        _updateCloseProgress('Salvataggio backup cloud in corso...');
        debugPrint(
          '[AppLifecycleWrapper] Sessione cloud trovata; avvio export.',
        );
        while (true) {
          _writeCloseDiagnostic('Avvio export cloud.');
          final exportSucceeded = await _exportCloudInForeground(
            session,
            showErrors: false,
          );
          if (!mounted) break;
          _writeCloseDiagnostic(
            'Export cloud ${exportSucceeded ? "completato" : "fallito"}.',
          );
          if (exportSucceeded) break;

          _updateCloseProgress('', visible: false);
          final closeWithoutSaving = await showDialog<bool>(
            context: _navigatorContext,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Salvataggio cloud non riuscito'),
              content: const Text(
                'Il backup non è stato completato. Vuoi riprovare o chiudere '
                'senza salvare?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Chiudi senza salvare'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Riprova'),
                ),
              ],
            ),
          );
          if (!mounted || closeWithoutSaving != false) break;

          _updateCloseProgress(
            'Nuovo tentativo di salvataggio del backup in corso...',
          );
          await WidgetsBinding.instance.endOfFrame;
        }
      } else {
        debugPrint(
          '[AppLifecycleWrapper] Nessun account cloud collegato; '
          'chiusura senza export.',
        );
      }

      _updateCloseProgress('', visible: false);
      _writeCloseDiagnostic('Procedura completata; chiudo la finestra.');
      debugPrint('[AppLifecycleWrapper] Export concluso; chiudo finestra.');
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (error, stackTrace) {
      _isClosing = false;
      _updateCloseProgress('', visible: false);
      _writeCloseDiagnostic('Errore chiusura: $error\n$stackTrace');
      debugPrint(
        '[AppLifecycleWrapper] Chiusura desktop dopo export fallita: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: _navigatorContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Chiusura non completata'),
          content: Text('Si è verificato un errore: $error'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<bool> _exportCloudInForeground(
    CurrentSession session, {
    bool showErrors = true,
  }) async {
    final exporter = CloudFileExport(
      session,
      showErrorFunction: showErrors
          ? ErrorManager.redirectToErrorPageExport
          : null,
    );
    var succeeded = false;
    try {
      await exporter.init();
      succeeded = await exporter.execute();
      debugPrint(
        '[AppLifecycleWrapper] Export cloud diretto '
        '${succeeded ? "completato" : "non riuscito"}.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[AppLifecycleWrapper] Export cloud diretto fallito: '
        '$error\n$stackTrace',
      );
      succeeded = false;
    } finally {
      try {
        await exporter.dispose();
      } catch (error, stackTrace) {
        succeeded = false;
        debugPrint(
          '[AppLifecycleWrapper] Rilascio risorse export cloud fallito: '
          '$error\n$stackTrace',
        );
      }
    }
    return succeeded;
  }

  @override
  void dispose() {
    if (_isDesktop) windowManager.removeListener(this);
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showCloseProgress)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: Center(
                child: AlertDialog(
                  content: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 20),
                      Expanded(child: Text(_closeProgressMessage)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
