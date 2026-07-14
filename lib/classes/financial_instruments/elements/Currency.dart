/// Represents different global currencies with their respective symbols and full English names.
enum Currency {
  /// United States Dollar
  usd(symbol: r'$', englishName: 'United States Dollar'),

  /// Euro
  eur(symbol: '€', englishName: 'Euro'),

  /// Great British Pound
  gbp(symbol: '£', englishName: 'British Pound Sterling'),

  /// Japanese Yen
  jpy(symbol: '¥', englishName: 'Japanese Yen'),

  /// Australian Dollar
  aud(symbol: r'A$', englishName: 'Australian Dollar'),

  /// Canadian Dollar
  cad(symbol: r'C$', englishName: 'Canadian Dollar'),

  /// Swiss Franc
  chf(symbol: 'CHF', englishName: 'Swiss Franc'),

  /// Chinese Yuan
  cny(symbol: '元', englishName: 'Chinese Yuan');

  /// The visual symbol representing the currency (e.g., '$', '€').
  final String symbol;

  /// The full name of the currency in English (e.g., 'United States Dollar').
  final String englishName;

  /// Constant constructor to initialize the currency properties.
  const Currency({
    required this.symbol,
    required this.englishName,
  });

  /// A utility method to format an amount with the currency symbol.
  /// Example: Currency.usd.format(100) -> "$100.00"
  String format(double amount) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}