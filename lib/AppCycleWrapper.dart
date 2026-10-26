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
  void initState(){
    super.initState();

    _listener = AppLifecycleListener(
      /* when pause save the content inside the drive
      and disconnect to it to let the resources
      free to other application instances */
      onPause: () async {
        if(Platform.isIOS || Platform.isAndroid){
          await Workmanager().registerOneOffTask(
            "upload_drive_job_${DateTime.now().millisecondsSinceEpoch}",
            "mira.exportCloud",
            constraints: Constraints(
              networkType: NetworkType.connected,
            ),
          );
        }else{
          CurrentSession? session = await CurrentSession.getFromMemory();
          if(session == null) return; // if the session is not found, end the function

          /* create the exporter
          and execute all the operations */
          CloudFileExport exporter = CloudFileExport(session, showErrorFunction: ErrorManager.redirectToErrorPageExport);
          await exporter.init();
          await exporter.execute();
          await exporter.dispose();
        }
      },
      /* when it's time to resume try to 
      connect and get the data, otherwise display errors */
      onResume: () async {
        if(Platform.isIOS || Platform.isAndroid){
          await Workmanager().registerOneOffTask(
            "upload_drive_job_${DateTime.now().millisecondsSinceEpoch}",
            "mira.importCloud",
            constraints: Constraints(
              networkType: NetworkType.connected,
            ),
          );
        }else{
          CurrentSession? session = await CurrentSession.getFromMemory();
          if(session == null) return; // if the session is not found, end the function

          /* create the importer and execute all the operations */
          CloudFileImport importer = CloudFileImport(session, showErrorFunction: ErrorManager.redirectToErrorPageImport);
          await importer.init();
          await importer.execute();
          await importer.dispose();
        }
      }
    );
  }

  @override
  void dispose(){
    super.dispose();
    _listener.dispose();
  }      

  @override
  Widget build(BuildContext context){
    return widget.child;
  }
}