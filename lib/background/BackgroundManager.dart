import 'dart:io';
//import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'package:mira_finance_tracker/frontend/error_pages/ErrorManager.dart';

import 'package:mira_finance_tracker/background/activity/BackgroundControl.dart';
import 'package:mira_finance_tracker/backend/cloud/operation/CloudFileExport.dart';
import 'package:mira_finance_tracker/backend/cloud/operation/CloudFileImport.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';

/* entry point required for 
mobile background workmanager */
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // print("[BG] Start task = $taskName");
    try{
      // debugger();
      if (taskName == "com.example.mira.backgroundControl") {
        WidgetsFlutterBinding.ensureInitialized();
        final service = BackgroundControl();
        // print("[BG] init...");
        await service.init();
        // print("[BG] init OK, execute...");
        await service.execute();
        // print("[BG] execute OK");
      }else if(taskName == "mira.importCloud"){
        CurrentSession? session = await CurrentSession.getFromMemory();
        if(session == null) return false; // return if the session has not been found

        /* create the importing trying 
        to connect to drive */
        CloudFileImport importer = CloudFileImport(session, showErrorFunction: ErrorManager.redirectToErrorPageExport);
        await importer.init();
        await importer.execute();
        await importer.dispose();
      }else if(taskName == "mira.exportCloud"){
        CurrentSession? session = await CurrentSession.getFromMemory();
        if(session == null) return false; // return if the session has not been found

        /* create the exporter and 
        complete the operation, allowing disconnection */
        CloudFileExport exporter = CloudFileExport(session, showErrorFunction: ErrorManager.redirectToErrorPageExport);
        await exporter.init();
        await exporter.execute();
        await exporter.dispose();
      }
      // print("[BG] END ok");
      return Future.value(true);
    }catch(e){
      // print("[BG] ERROR: $e");
      // print("[BG] STACKTRACE: $st");
      return Future.value(false);
    }
  });
}

class BackgroundManager {
  static final BackgroundManager instance = BackgroundManager._();
  BackgroundManager._();

  /// Function to enable daily background
  /// whatever platform has been used
  Future<void> enableDailyBackgroundCheck() async {
    if (kIsWeb) return; // web doesn't support background application when closed

    if (Platform.isAndroid || Platform.isIOS) {
      await _configureMobile();
    } else if (Platform.isWindows) {
      await _configureWindows();
    } else if (Platform.isLinux || Platform.isMacOS) {
      await _configureUnix();
    }
  }

  /// Function to disable daily background check
  /// whatever platform has been used
  Future<void> disableDailyBackgroundCheck() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Workmanager().cancelByUniqueName("background-control");
    } else if (Platform.isWindows) {
      await Process.run('schtasks', ['/Delete', '/TN', 'Mira_BackgroundCheck', '/F']);
    } else if (Platform.isLinux || Platform.isMacOS) {
      await _disableLinuxCrontab();
    }
  }

  /* function to disable linux crontab */
  Future<void> _disableLinuxCrontab() async {
    final exePath = Platform.resolvedExecutable;

    /* read actual crontab of the application */
    final process = await Process.start('crontab', ['-l']);
    final currentCron = await process.stdout
        .transform(const SystemEncoding().decoder)
        .join();

    /* remove only the rows containing the path
    matching the executable created */
    final lines = currentCron.split('\n');
    final updatedLines = lines.where((line) => !line.contains(exePath)).join('\n');

    /* override the crontab with the 
    updated list */
    final updateProcess = await Process.start('crontab', ['-']);
    updateProcess.stdin.write(updatedLines);
    await updateProcess.stdin.close();
  }

  /* --- MOBILE CONFIGURATION (Android / iOS) --- */
  Future<void> _configureMobile() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
    await Workmanager().registerPeriodicTask(
      "background-control",
      "com.example.mira.backgroundControl",
      frequency: const Duration(hours: 24), // default: 24 hours
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: Duration(minutes: 15)
    );
  }

  /* --- WINDOWS CONFIGURATION --- */
  Future<void> _configureWindows() async {
    final exePath = Platform.resolvedExecutable; // call the same executable of the function
    
    /* register a task which operates 
    on the computer daily */
    await Process.run('schtasks', [
      '/Create',
      '/TN', 'Mira_BackgroundCheck',
      '/TR', '"$exePath" --background-check',
      '/SC', 'DAILY',
      '/ST', '09:00',
      '/F' // override if already existing
    ]);
  }

  /* --- CONFIGURE Linux / MacOS (crontab) --- */
  Future<void> _configureUnix() async {
    final exePath = Platform.resolvedExecutable;
    final command = '"$exePath" --background-check';
    final cronJob = "0 9 * * * $command > /dev/null 2>&1\n";

    final process = await Process.start('crontab', ['-l']);
    final currentCron = await process.stdout.transform(const SystemEncoding().decoder).join();

    if (!currentCron.contains(exePath)) {
      final newCron = currentCron + cronJob;
      final updateProcess = await Process.start('crontab', ['-']);
      updateProcess.stdin.write(newCron);
      await updateProcess.stdin.close();
    }
  }

  /* debug function to test one off operations
  inside the device */
  /* Future<void> testOneOff() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
    await Workmanager().registerOneOffTask(
      "test-bg-2",                          // cambialo a ogni prova: test-bg-2, ...
      "com.example.mira.backgroundControl", // stesso nome del task vero
      initialDelay: const Duration(minutes: 1),
      constraints: Constraints(networkType: NetworkType.connected),
    );
    print('[BG] one-off registrato');
  } */
}