import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/classes/bank_account/Card.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';

void main() {
  test('non-credit cards have no credit time', () {
    final institute = FinancialInstitute('Test institute');
    final subscriptionDate = DateTime.now();

    for (final type in [CardType.debit, CardType.prepaid]) {
      final card = Card('Test card', institute, subscriptionDate, type);

      expect(card.creditTime, isNull);
    }
  });

  test('credit cards retain their credit day', () {
    final card = Card(
      'Test credit card',
      FinancialInstitute('Test institute'),
      DateTime.now(),
      CardType.credit,
      dayOfMonthCredit: 15,
    );

    expect(card.creditTime?.dayOfMonth, 15);
  });
}
