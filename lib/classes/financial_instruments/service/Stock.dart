import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/Currency.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';

/// Class used to define and manage stocks
/// as a financial instrument
class Stock extends FinancialInstrument{
  /* attributes definition */
  String _ticker; // symbol used in the stock exchange
  double _totalShares; // some trading softwares may allow buying a portion of stock
  double _averagePurchasePrice; 
  Currency _currency;
  double _totalDividends;
  DateTime _startingDate;
  DateTime? _endingDate;

  /// Constructor to define a bond with all the necessary parameters
  /// * [name] name of the financial instrument, which has to be unique
  /// * [providerType] type of provider of the service (main difference is between public and private institution)
  /// * [initialValue] initial value of the financial instrument
  /// * [taxRate] tax rate applied to the interests earned
  /// * [id] ID of the financial instrument mainly used by the database (if not set it's -1)
  /// * [provider] information about the provider of the service (mandatory if it's a private institution)
  /// * [currentValue] current value of the financial instrument with all the interest calculated so far
  /// * [status] status of the financial instrument (ended, ongoing, stopped etc.)
  /// * [_ticker] symbol of the stock used in the exchange market
  /// * [_totalShares] number of shares purchased of the same stock
  /// * [_averagePurchasePrice] average price of each share to understand the total value of the stock, adapting it to the change of the single price per share
  /// * [_currency] currency used when purchasing shares
  /// * [_totalDividends] counter of possible dividends distributed by the company
  /// * [_startingDate] date of the start of the shares purchasing
  /// * [_endingDate] date of the end of the stock use, when everything has been sold
  Stock(String name, double initialValue, double taxRate, FinancialInstitute provider,
    this._ticker, this._currency, this._startingDate, 
    {int id = -1, double? currentValue, FinancialInstrumentStatus? status,
    this._totalShares = 0, this._averagePurchasePrice = 0, this._totalDividends = 0, this._endingDate}) :
    super(name, FinancialInstrumentProvider.financialInstitution, initialValue, taxRate, 
    id: id, provider: provider, instrumentUsed: null, currentValue: currentValue, financialInstrumentStatus: status){
      /* check the validity of the attributes */
      if(_totalShares < 0){
        throw Exception("In a stock the total shares acquired can't be less than 0");
      }
      if(_totalDividends < 0){
        throw Exception("In a stock the total dividends can't be less than 0");
      }
      if(_endingDate != null && _endingDate!.isBefore(_startingDate)){
        throw Exception("In a stock the ending date can't come before the starting date");
      }
  }

  /* *** GETTER METHODS *** */
  String get ticker => _ticker;
  double get totalShares => _totalShares;
  double get averagePurchasePrice => _averagePurchasePrice;
  Currency get currency => _currency;
  double get totalDividends => _totalDividends;
  DateTime get startingDate => _startingDate;
  DateTime? get endingDate => _endingDate;
  double get totalInvestedCapital {
    return totalShares * averagePurchasePrice;
  }

  /* *** SETTER METHODS *** */
  set currency(Currency currency) => _currency = currency;

  /// Method to update the status of a stock buy shares
  /// * [sharesBought] number of shares bought
  /// * [pricePerShare] price per share at the moment of purchase
  List<BankTransaction> buyShares(double sharesBought, double pricePerShare){
    /* check the validity of the parameters */
    if(sharesBought <= 0){
      throw Exception("The amount of shares bought must be more than 0");
    }

    double oldTotalCost = _totalShares * _averagePurchasePrice; // calculate the total shares get so far
    _totalShares += sharesBought; // update the number of shares bought
    _averagePurchasePrice = (oldTotalCost + sharesBought * pricePerShare) / _totalShares; // get new average price

    /* return the transaction to register */
    List<BankTransaction> transactions = [];
    transactions.add(
      Outcome(OutcomeCategory.financial_investment, "Acquisto di $sharesBought azioni $_ticker al prezzo di $pricePerShare${currency.symbol} ciascuna", sharesBought*pricePerShare, DateTime.now())
    );

    return transactions;
  }

  /// Method to sell shares immediately with
  /// the current market value
  /// * [sharesSold] number of shares sold from the stock
  /// * [pricePerShare] current price for each share
  List<BankTransaction> sellShares(double sharesSold, double pricePerShare){
    /* check the validity of the attributes */
    if (sharesSold > _totalShares) {
      throw Exception("Non puoi vendere più azioni di quante ne possiedi");
    }

    double realizedProfitOrLoss = sharesSold * (pricePerShare - _averagePurchasePrice); // calculate potential profit or loss
    _totalShares -= sharesSold;

    /* create the list of transactions to return */
    List<BankTransaction> transactions = [];
    transactions.add(
      Income(IncomeCategory.stock_return, "Vendita di $sharesSold azioni di $_ticker", _averagePurchasePrice * sharesSold, DateTime.now())
    );
    /* based on the potential profit or loss, 
    create an income or outcome transactions, 
    with connected taxes */
    if(realizedProfitOrLoss > 0){
      transactions.add(
        Income(IncomeCategory.financial_interest, "Guadagno vendita di $sharesSold di $_ticker", realizedProfitOrLoss, DateTime.now())
      );

      /* when realizing profits is useful
      to take into account taxations */
      double taxes = realizedProfitOrLoss * super.taxRate;
      transactions.add(
        Outcome(OutcomeCategory.financial_tax, "Tassazione vendita di $sharesSold di $_ticker", taxes, DateTime.now())
      );
    }else if(realizedProfitOrLoss < 0){
      transactions.add(
        Outcome(OutcomeCategory.stock_loss, "Perdita capitale vendita di $sharesSold di $_ticker", realizedProfitOrLoss.abs(), DateTime.now())
      );
    }

    return transactions;
  }

  /// Function to add a dividend for the stock selected
  /// * [netAmount] amount of money given in the corresponding currency
  List<BankTransaction> addDividend(double netAmount) {
    /* control validity of the parameters */
    if(netAmount <= 0){
      throw Exception("Dividend distributes must be more than 0€");
    }

    _totalDividends += netAmount;

    /* generate the transactions to add */
    List<BankTransaction> transactions = [];
    transactions.add(
      Income(IncomeCategory.financial_dividend, "Distribuzioni dividendi per $_ticker", netAmount, DateTime.now())
    );
    return transactions;
  }

  /* deprecated methods of the financial instrument, 
  that for the stock are not optimized */
  @Deprecated('stop method is not used for this specific type of financial instrument')
  @override
  void stop({DateTime? datetimeStop}){}

  @Deprecated('stop method is not used for this specific type of financial instrument')
  @override
  void reduce(double amount, {DateTime? datetimeWithdraw}){}

  /// Method to end a stock selling all the stocks,
  /// override of the method provided by the class [FinancialInstrument]
  @override
  List<BankTransaction> end({double? pricePerShare}){
    double price = pricePerShare ?? _averagePurchasePrice; // establish the price
    List<BankTransaction> list = sellShares(_totalShares, price); // call the method of selling shares

    super.end(); // call the super method to manage end status
    _endingDate = DateTime.now(); // put the ending date

    return list; // return the list of transactions
  }

  /// Function to create a new instance of the object
  /// making a deep clone of it
  @override
  Stock clone(){
    return Stock(
      super.name,
      super.initialValue,
      super.taxRate,
      super.provider!.clone(),
      _ticker,
      _currency,
      _startingDate,
      id: super.id,
      currentValue: super.currentValue,
      totalShares: _totalShares,
      averagePurchasePrice: _averagePurchasePrice,
      totalDividends: _totalDividends,
      endingDate: _endingDate
    );
  }

  /// Change the operator == because two same stocks 
  /// could exists, unless they are contemporary
  @override
  bool operator ==(Object other){
    return other is Stock && super.name == other.name && super.status == other.status;
  }

  /// Change the hashcode after the changes at the operator ==
  @override
  int get hashCode => Object.hash(super.name, super.status);

  /// Method to convert an object into a map for
  /// database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      ...super.toMap(),
      'ticker': _ticker,
      'currency': _currency.index,
      'startingDate': _startingDate.toIso8601String(),
      'totalShares': _totalShares,
      'averagePurchasePrice': _averagePurchasePrice,
      'totalDividends': _totalDividends,
      'endingDate': _endingDate?.toIso8601String()
    };
  }

  /// Factory method to transform a map object into an 
  /// instance of a stock
  /// * [map] map object from the database
  /// * [provider] optional provider of the bond service
  factory Stock.fromMap(Map<String, dynamic> map, FinancialInstitute provider){
    return Stock(
      map['name'],
      map['initialValue'],
      map['taxRate'],
      provider,
      map['ticker'],
      Currency.values[map['currency']],
      DateTime.parse(map['startingDate']),
      id: map.remove('id'),
      currentValue: map.remove('currentValue'),
      status: FinancialInstrumentStatus.values[map.remove('status')],
      totalShares: map['totalShares'],
      totalDividends: map['totalDividends'],
      averagePurchasePrice: map['averagePurchasePrice'],
      endingDate: map['endingDate']
    );
  }
}