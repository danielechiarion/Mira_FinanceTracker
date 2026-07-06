import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';

/// Enumerator to express type of duration, 
/// used by financial instruments and domiciliation
/// and period payments of every bank account
enum DurationType{
  /* define enumerator values */
  monthly("Mensile", LongDuration(months: 1)),
  bimonthly("Bimestrale", LongDuration(months: 2)),
  quarterly("Trimestrale", LongDuration(months: 3)),
  fourmonthly("Quadrimestrale", LongDuration(months: 4)),
  sixmonthly("Semestrale", LongDuration(months: 6)),
  annual("Annuale", LongDuration(years: 1)),
  biennal("Biennale", LongDuration(years: 2)),
  threeyear("Triennale", LongDuration(years: 3)),
  quadriennal("Quadriennale", LongDuration(years: 4)),
  fiveyear("Quinquennale", LongDuration(years: 5)),
  atMaturity("A terminazione", null);

  /* define attributes for the enumerator */
  final String name;
  final LongDuration? duration;

  /* define constructor for the enumerator */
  const DurationType(this.name, this.duration);
}