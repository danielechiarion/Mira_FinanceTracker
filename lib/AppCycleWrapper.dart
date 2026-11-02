import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

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

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();

    _listener = AppLifecycleListener(
      /* when pause save the content inside the drive
      and disconnect to it to let the resources
      free to other application instances */
      onPause: () async {
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

        await _exportCloudInForeground(session);
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

  Future<void> _exportCloudInForeground(CurrentSession session) async {
    final exporter = CloudFileExport(
      session,
      showErrorFunction: ErrorManager.redirectToErrorPageExport,
    );
    try {
      await exporter.init();
      final succeeded = await exporter.execute();
      debugPrint(
        '[AppLifecycleWrapper] Export cloud diretto '
        '${succeeded ? "completato" : "non riuscito"}.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[AppLifecycleWrapper] Export cloud diretto fallito: '
        '$error\n$stackTrace',
      );
    } finally {
      try {
        await exporter.dispose();
      } catch (error, stackTrace) {
        debugPrint(
          '[AppLifecycleWrapper] Rilascio risorse export cloud fallito: '
          '$error\n$stackTrace',
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _listener.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
