import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';

/// Class used to define the possibility for
/// financial instruments to control the cadence for each
/// financial instrument, if required,
/// so as to make operations regularly. 
abstract class CadenceCheck{
  /* attributes definition */
  abstract PeriodicAccountDuration timeInfo;

  /// Method to check and execute periodically operations
  /// with the attribute provided so as 
  /// to check if it's time to make periodic operations
  dynamic checkAndExecute();
}