import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';

class TimeDepositModel extends FinancialInstrumentModel{
  /* attributes definitiion */
  double _interestRate; // annual interest given
  bool _isCashable; // if the time deposit can be stop before maturity date
  double _earlyWithdrawalInterestRate; // eventual early withdrawal interest rate whether is cashable

  /// Constructor for a time deposit model with all the necessary 
  /// data to build it the right way
  /// * [name] name of the financial instrument model
  /// * [providerType] type of provider of the service (mainly private or public)
  /// * [duration] duration of the financial instrument
  /// * [payoutFrequency] frequency of paying out the interests
  /// * [id] ID of the database for the model saved (it will be -1 at the beginning)
  /// * [description] optional description for the financial instrument
  /// * [provider] optional provider of the service (mandatory if it's a private one)
  /// * [taxRate] tax rate applied to the interests earned from the financial instrument
  /// * [_interestRate] annual interest given
  /// * [_isCashable] it means if the time deposit can be stop or reduced before date of maturity
  /// * [_earlyWithdrawalInterestRate] eventual early interest whether the time deposit has been cashed before maturity date
  TimeDepositModel(String name, FinancialInstrumentProvider providerType, LongDuration duration, DurationType payoutFrequency, this._interestRate, 
    {int id = -1, String? description, FinancialInstitute? provider, double taxRate = 0.0, this._isCashable = true, this._earlyWithdrawalInterestRate = 0.0}): 
    super(name, providerType, duration, payoutFrequency, id: id, description: description, provider: provider, taxRate: taxRate){
      if(_interestRate <= 0){
        throw Exception("In a time deposit the interest rate has to be more than 0%");
      }
      if(_earlyWithdrawalInterestRate < 0){
        throw Exception("In a time deposit the early withdrawal interest rate can't be less than 0%");
      }
  }

  /* *** GETTER METHOD *** */
  double get interestRate => _interestRate;
  bool get isCashable => _isCashable;
  double get earlyWithdrawalInterestRate => _earlyWithdrawalInterestRate;

  /* *** SETTER METHOD *** */
  set isCashable(bool isCashable) => _isCashable = isCashable;
  set interestRate(double interestRate){
    if(interestRate <= 0){
      throw Exception("In a time deposit the interest rate has to be more than 0%");
    }
    _interestRate = interestRate;
  }
  set earlyWithdrawalInterestRate(double earlyWithdrawalInterestRate){
    if(_earlyWithdrawalInterestRate < 0){
      throw Exception("In a time deposit the early withdrawal interest rate can't be less than 0%");
    }
    _earlyWithdrawalInterestRate = earlyWithdrawalInterestRate;
  }

  /// Method to convert a time deposit model 
  /// in a map for database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      ...super.toMap(),
      'isCashable': _isCashable ? 1 : 0,
      'interestRate': _interestRate,
      'earlyWithdrawalInterestRate': _earlyWithdrawalInterestRate
    };
  }

  /// Function to get a time deposit model starting from 
  /// a map of the database
  /// * [map] map object of the database
  /// * [provider] optional provider of the time deposit
  factory TimeDepositModel.fromMap(Map<String, dynamic> map, FinancialInstitute? provider){
    return TimeDepositModel(
      map['name'],
      FinancialInstrumentProvider.values[map['providerType']],
      LongDuration.fromString(map['duration']),
      DurationType.values[map['payoutFrequency']],
      map['interestRate'],
      id: map['id'],
      description: map['description'],
      provider: provider,
      taxRate: map['taxRate'],
      isCashable: map['isCashable'] == 1,
      earlyWithdrawalInterestRate: map['earlyWithdrawalInterestRate']
    );
  }

  /// Method to get a deep clone of the instance
  @override
  TimeDepositModel clone(){
    return TimeDepositModel(super.name, super.providerType, super.duration.clone(), super.payoutFrequency, _interestRate,
            id: super.id, description: super.description, provider: super.provider?.clone(), taxRate: super.taxRate, isCashable: _isCashable, earlyWithdrawalInterestRate: _earlyWithdrawalInterestRate);
  }
}