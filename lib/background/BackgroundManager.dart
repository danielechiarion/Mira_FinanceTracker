import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'package:mira_finance_tracker/background/activity/BackgroundControl.dart';

/* entry point required for 
mobile background workmanager */
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == "com.example.mira.backgroundControl") {
      WidgetsFlutterBinding.ensureInitialized();
      final service = BackgroundControl();
      await service.init();
      await service.execute();
    }
    return Future.value(true);
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
      frequency: const Duration(hours: 24),
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
}