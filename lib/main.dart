import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mira_finance_tracker/frontend/account/LoginPage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // ensure all libraries have been loaded

  /* configure ffi system for desktop ios and platforms */
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
      home: const LoginPage(),
    );
  }
}
