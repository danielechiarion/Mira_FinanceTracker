/// Class to define the financial institue object
/// who offers bank accounts and services
class FinancialInstitute{
  /* attribute definition */
  int _id;
  String _name;
  String _email;
  String _phoneNumber;
  String _site;

  /// Constructor method of the financial institute class
  /// * [_name] the name of the financial institute
  /// * [_email] the address of the financial institute
  /// * [_phoneNumber] the phone number of the financial institute
  /// * [_site] the website of the financial institute
  /// * [_id] the ID of the financial institute (firstly it will be -1, then it will be set by the database)
  FinancialInstitute(this._name, {this._id = -1, this._email = '', this._phoneNumber = '', this._site = ''});

  /* *** GETTER METHODS *** */
  String get name => _name;
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  int get id => _id;
  String get site => _site;

  /* *** SETTER METHODS *** */
  set site (String site) => _site = site;
  set email(String email) => _email = email;
  set phoneNumber (String phoneNumber) => _phoneNumber = phoneNumber;
  set id (int id) => _id = id;

  /// Operator to compare two financial institute
  /// by the name, that is unique for each instance 
  @override
  bool operator ==(Object other){
    return other is FinancialInstitute && other._name == _name;
  }

  /// Method to generate the hashcode of the instance
  @override
  int get hashCode => _name.hashCode;

  /// Method to convert the financial institute object to
  /// a map to be converted to JSON and sent to the database
  Map<String, dynamic> toMap() {
    return {
      if(_id != -1) 'id': _id,
      'name': _name,
      'email': _email,
      'phoneNumber': _phoneNumber,
      'site': _site
    };
  }

  /// Factory method to create a financial institute object
  /// from a map, to be used when retrieving data from the database
  /// * [map] the map to convert to a financial institute object
  factory FinancialInstitute.fromMap(Map<String, dynamic> map) {
    return FinancialInstitute(
      map['name'],
      id: map['id'],
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      site: map['site'] ?? '',
    );
  }

  /// Method to get a deep clone of the instance
  FinancialInstitute clone(){
    return FinancialInstitute(_name, id: _id, email: _email, phoneNumber: _phoneNumber, site: _site);
  }
}