/// Class used to verify duration more than
/// the class Duration provided by Dart.
/// This class is used for financial products
class LongDuration implements Comparable<LongDuration>{
  /* define attributes */
  final int years;
  final int months;
  final int days;

  /// Constructor for the long duration class,
  /// setting default values of time by zero
  /// * [years] years of time in the duration
  /// * [months] months of time left in the duration
  /// * [days] days of time left in the duration
  const LongDuration({int years = 0, int months = 0, int days = 0})
      : years = years + ((months + (days ~/ 31)) ~/ 12),
        months = (months + (days ~/ 31)) % 12,
        days = days % 31;

  /// Function to calculate if it's the exact time difference 
  /// between two dates given expressed by the instance selected
  /// * [startDate] starting date
  /// * [endDate] ending date
  bool exactTimeDifference(DateTime startDate, DateTime endDate){
    /* first control if start date and end date given 
    are correct */
    if(startDate.isAfter(endDate)){
      throw Exception("Start date can't be after the end date");
    }

    return _calculateExpandedDifference(startDate, endDate) == this;
  }

  /// Method to control if two dates have the right time difference,
  /// which means the final date has a distance from the first one
  /// equal or more than the long duration indicated
  /// * [startDate] starting date
  /// * [endDate] ending date
  bool rightTimeDifference(DateTime startDate, DateTime endDate){
    /* first control if start date and end date given 
    are correct */
    if(startDate.isAfter(endDate)){
      throw Exception("Start date can't be after the end date");
    }

    return _calculateExpandedDifference(startDate, endDate).compareTo(this) >= 0;
  }

  /// Function to calculate the difference between two dates
  /// using days, months and years
  /// * [start] starting date
  /// * [end] ending date
  static LongDuration _calculateExpandedDifference(DateTime start, DateTime end) {
    // If the dates are reversed, swap them to always ensure a positive result
    if (start.isAfter(end)) {
      final temp = start;
      start = end;
      end = temp;
    }

    int years = end.year - start.year;
    int months = end.month - start.month;
    int days = end.day - start.day;

    // 1. Handle negative days (e.g., from July 25th to August 10th)
    if (days < 0) {
      // Borrow a month from the months count
      months--;
      
      // Find the last day of the month prior to the "end" month
      // In Dart, setting the day to 0 in the DateTime constructor returns the last day of the previous month.
      DateTime previousMonth = DateTime(end.year, end.month, 0);
      
      // Add the days of the previous month to the calculation
      days += previousMonth.day;
    }

    // 2. Handle negative months (e.g., from October to March of the following year)
    if (months < 0) {
      years--;
      months += 12;
    }

    return LongDuration(years: years, months: months, days: days);
  }

  /// Operator equals for the long duration instance
  /// * [other] object to compare
  @override
  bool operator ==(Object other){
    return other is LongDuration && years == other.years && months == other.months && days == other.days;
  }

  /// Getter of the hashcode
  @override
  int get hashCode => Object.hash(years, months, days);

  /// Method to compare each other different 
  /// long duration instances
  /// * [other] long duration instance to compare
  @override
  int compareTo(LongDuration other){
    /* calculate the difference between 
    months, days and years */
    int yearComparison = years.compareTo(other.years);
    int monthComparison = months.compareTo(other.months);
    int dayComparison = days.compareTo(other.days);

    if(yearComparison == 0 && monthComparison == 0) {
      return dayComparison;
    }
    if(yearComparison == 0){
      return monthComparison;
    }

    return yearComparison;
  }
}