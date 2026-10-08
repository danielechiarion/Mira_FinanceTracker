/// Class to order and manage google account data, in order to save it into the database
class GoogleAccount {
  final int? id;
  final String email;
  final String displayName;
  final String accessToken;
  final String refreshToken;
  final String serverAuthCode; // useful if you have to make the change
  final DateTime updatedAt;

  /// Constructor for the GoogleAccount class with all the necessary 
  /// attributes
  GoogleAccount({
    this.id,
    required this.email,
    required this.displayName,
    required this.accessToken,
    required this.refreshToken,
    required this.serverAuthCode,
    required this.updatedAt,
  });

  /// Function to convert the google account object into a map
  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'server_auth_code': serverAuthCode,
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Function to create a GoogleAccount instance from a map
  factory GoogleAccount.fromMap(Map<String, dynamic> map) => GoogleAccount(
        id: map['id'] as int?,
        email: map['email'] as String,
        displayName: map['display_name'] as String,
        accessToken: map['access_token'] as String,
        refreshToken: map['refresh_token'] as String,
        serverAuthCode: map['server_auth_code'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  /// Function to create a copy of the account instance 
  /// with updated values
  GoogleAccount copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? updatedAt,
  }) =>
      GoogleAccount(
        id: id,
        email: email,
        displayName: displayName,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        serverAuthCode: serverAuthCode,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}