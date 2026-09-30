import 'dart:io';
//import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:mira_finance_tracker/backend/service/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationManager.dart';
import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/background/BackgroundManager.dart';
import 'package:mira_finance_tracker/background/activity/BackgroundControl.dart';

import 'package:mira_finance_tracker/frontend/account/LoginPage.dart';
import 'package:mira_finance_tracker/frontend/HomePage.dart';
import 'package:mira_finance_tracker/frontend/ActionsPage.dart';
import 'package:mira_finance_tracker/frontend/CustomCheckPage.dart';
import 'package:mira_finance_tracker/frontend/SettingsPage.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized(); // ensure all libraries have been loaded
  await initializeDateFormatting('it_IT', null); // define the language for dates

  /* configure ffi system for desktop ios and platforms */
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  /* --- CATCH BACKGROUND TASK ---
  when it's called from the backend */
  if(args.contains("--background-check")){
    //debugger();
    /* call the service to execute
    in background */
    print("=== Avvio controllo automatico Desktop (App Chiusa) ===");
    final service = BackgroundControl();
    await service.init();
    await service.execute();
    print("=== Controllo completato ===");

    exit(0); // exit the proces
  }

  /* ask permission for notification in
  order to send messages about the state of the accounts */
  await NotificationManager().requestPermissions();

  /* understand if the user is logged */
  bool userLogged = (await CurrentSession.getFromMemory()) != null;

  /* enable background manager daily task
  throughout all platforms */
  await BackgroundManager.instance.enableDailyBackgroundCheck();

  runApp(MainApp(isLogged: userLogged));
}

class MainApp extends StatelessWidget {
  final bool isLogged; // attribute to understand if the user is logged

  const MainApp({super.key, required this.isLogged});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Mia App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      /* sets login page as the 
      page opened on first access */
      home: isLogged ? const HomePage() : const LoginPage(),
      routes: {
        AppRoutes.home:(context) => const HomePage(),
        AppRoutes.check:(context) => const CustomCheckPage(),
        AppRoutes.actions:(context) => const ActionsPage(),
        AppRoutes.settings:(context) => const SettingsPage()
      },
    );
  }
}
