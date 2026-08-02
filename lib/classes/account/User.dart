import 'package:bcrypt/bcrypt.dart';

/// Class to define the user object
/// who gets the access to the system
class User{
  /* attribute definition */
  int _id;
  String _username;
  String _name;
  String _surname;
  String _password;
  String _email;

  /// Constructor method of the user class
  /// * [_username] the username of the user
  /// * [_password] the password of the user which has to be already hashed, for the security of the account
  /// * [_name] the name of the user
  /// * [_surname] the surname of the user (optional)
  /// * [_id] the ID of the user (firstly it will be -1, then it will be set by the database)
  /// * [_email] parameter to use only by the system to put the email of the google account
  User(this._username, this._password, this._name, {this._id = -1, this._surname = '', String? email}): _email = '' {
    if(email != null && email.isNotEmpty){
      email = _email;
    }
  }

  /* *** GETTER METHODS *** */
  String get username => _username;
  String get name => _name;
  String get surname => _surname;
  String get email => _email;
  String get password => _password; // for privacy reasons call it only when hashed

  /* *** SETTER METHODS *** */
  set name (String name) => _name = name;
  set surname (String surname) => _surname = surname;
  set id (int id) => _id = id;
  set email(String email){
    if(isValidEmail(email)){
      _email = email;
    }else{
      throw FormatException("Email has not a valid format");
    }
  }
  set password(String password) {
    _password = hashPassword(password);
  }

  /// Method to set the new password of the user,
  /// controlling the old one to avoid mistakes and 
  /// esnuring the security of the account
  /// * [oldPassword] the old password, NOT HASHED
  /// * [newPassword] the new password, NOT HASHED
  void setPassword(String oldPassword, String newPassword){
    /* first check if the new password is different
    from the old one */
    if(oldPassword == newPassword){
      throw Exception("The new password can't be the same as the old one");
    }

    /* then check if the old password matches
    with the one registered */
    if(!BCrypt.checkpw(oldPassword, _password)){
      throw Exception("The old password is not correct");
    }

    /* if everything is correct, set the new password */
    _password = hashPassword(newPassword);
  }

  /// Method to hash current password of the 
  /// user to keep it private
  void hashCurrentPassword(){
    _password = hashPassword(_password);
  }

  /// Method to compare two user objects by the username, 
  /// that is unique for each instance.
  /// The ID has not been used because it's not set when it's created and it's just made to
  /// create relations inside the database
  /// * [other] the other user object to compare with
  @override
  bool operator ==(Object other){
    return other is User && other._username == _username;
  }

  /// Method to generate the hashcode of the instance
  @override
  int get hashCode => _username.hashCode;

  /// Method to covert the user object to a map,
  /// to be used for the database
  Map<String, dynamic> toMap(){
    return {
      if(_id != -1) 'id': _id,
      'username': _username,
      'password': _password,
      'name': _name, 
      'surname': _surname,
      'email': _email
    };
  }

  /// Method to convert a map to a user object
  /// coming from the database
  /// * [map] map object to convert
  factory User.fromMap(Map<String, dynamic> map){
    return User(
      map['username'],
      map['password'],
      map['name'],
      surname: map['surname'] ?? '',
      id: map['id'],
      email: map['email']
    );
  }

  /// Static method to hash a password using the bcrypt algorithm,
  /// using a random component to make it more secure
  /// from linear algorithms such as SHA256 or MD5
  /// * [password] the password to hash
  static String hashPassword(String password){
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Method to get a deep clone of the instance
  User clone(){
    return User(_username, _password, _name, id: _id, surname: _surname);
  }

  //// Control to understand if the mail is valid
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }
}