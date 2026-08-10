import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mira_finance_tracker/backend/service/CurrentSession.dart';

import 'package:mira_finance_tracker/frontend/account/LoginPage.dart';
import 'package:mira_finance_tracker/frontend/HomePage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ensure all libraries have been loaded

  /* configure ffi system for desktop ios and platforms */
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  /* understand if the user is logged */
  bool userLogged = (await CurrentSession.getFromMemory()) != null;

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
    );
  }
}
