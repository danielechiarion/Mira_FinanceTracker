import 'package:flutter/widgets.dart';
import 'package:mira_finance_tracker/background/activity/BackgroundControl.dart';

/// Function to execute controls also in
/// desktop environment compiling this code
/// and executing it from the original application
/// using the [BackgroundControl] class
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // necessary to access to the system

  print("=== Avvio controllo automatico Desktop (App Chiusa) ===");
  final service = BackgroundControl();
  await service.init();
  await service.execute();
  print("=== Controllo completato ===");
}