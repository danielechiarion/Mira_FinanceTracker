import 'package:mira_finance_tracker/classes/financial_instruments/elements/StepInterest.dart';

/// Abstract class used as interface to indicate proper methods
/// to use when managing a list of step interests
abstract class InterestList{
  /* define all the methods to override */
  /// Method to add a new interest in the list
  /// * [interest] new interest to add
  /// * [checkDuration] flag to check if it's necessary to check the duration validity after the operation
  void addInterest(StepInterest interest, {bool checkDuration = false});
  /// Method to remove an interest by its position
  /// * [position] position of the interest to remove
  /// * [checkDuration] flag to check if it's necessary to check the duration validity after the operation
  void removeInterest(int position, {bool checkDuration = false});
  /// Method to replace an interets with a new one
  /// * [interest] interest to replace
  /// * [position] optional position to replace the interest, if specified
  /// * [checkDuration] flag to check if it's necessary to check the duration validity after the operation
  void replaceInterest(StepInterest interest, {int? position, bool checkDuration = false});
  /// Method that checks the total duration validity of the 
  /// list of step interests. The method will return three possible results:
  /// - 0 if the duration matches perfectly with the sum of step interests
  /// - <0 if the step interests list covers less time than the specified duration
  /// - >0 if the step interests list covers more time than the specified duration
  /// This control can be used also during addition and replacing of the step interest
  int checkDurationValidity();
}