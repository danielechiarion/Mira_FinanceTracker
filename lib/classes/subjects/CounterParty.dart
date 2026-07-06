/// Class to define the counterparty object
/// during banking transactions
class CounterParty{
  /* attribute definition */
  int _id;
  String _name;
  String _IBAN;

  /// Constructor method of the counterparty class
  /// * [name] the name of the counterparty
  /// * [IBAN] the IBAN of the counterparty
  /// * [id] the ID of the counterparty (firstly it will be -1, then it will be set by the database)
  CounterParty(this._name, {this._id = -1, this._IBAN = ''});

  /* *** GETTER METHODS *** */
  String get name => _name;
  String get IBAN => _IBAN;

  /* *** SETTER METHODS *** */
  set IBAN (String IBAN) => _IBAN = IBAN;
  set id (int id) => _id = id;
  set name (String name) => _name = name;

  /// Operator to compare two counterparties
  @override
  bool operator ==(Object other){
    /* in this case the ID must be different 
    from -1 to make a real comparison */
    return other is CounterParty && _id != -1 && other._id == _id;
  }

  /// Method to generate the hashcode of the instance
  @override
  int get hashCode => _id.hashCode;

  /// Method to convert the counterparty object to 
  /// a map used by the database to store the data
  Map<String, dynamic> toMap() {
    return {
      if(_id != -1) 'id': _id,
      'name': _name,
      'IBAN': _IBAN
    };
  }

  /// Factory method to create a counterparty object
  /// from a map, to be used when retrieving data from the database
  /// * [map] the map to convert to a counterparty object
  factory CounterParty.fromMap(Map<String, dynamic> map) {
    return CounterParty(
      map['name'],
      id: map['id'],
      IBAN: map['IBAN'] ?? '',
    );
  }
}