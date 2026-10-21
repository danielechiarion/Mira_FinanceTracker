import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAccount.dart';

/// Class to handle authentication management
/// with google account in order to access into drive resource
class GoogleAuthenticationManager {
  /* define attributes */
  late final String _clientID;
  final List<String> _scopes;
  final SystemDatabaseWrapper _database;

  /* define attributes also for 
  following operations */
  late final GoogleSignIn _googleSignIn;
  String? _currentEmail;

  /* define constants for the use of the application */
  static const String _apiDataFile = "assets/credentials.json";

  /// Constructor to initialize the authenticator manager for google account,
  /// defining the [_scopes] to access into drive resources
  // Existing accounts may need to sign in again to grant the appData scope.
  GoogleAuthenticationManager({
    this._scopes = const [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  }) : _database = SystemDatabaseWrapper();

  /// Function to initialize the resources of the class,
  /// such as the client id and the database
  Future<void> init() async {
    /* first initialize the database */
    await _database.init();

    /* then get the client id 
    and start the google sign in instance */
    _clientID = await _getClientID();
    _googleSignIn = GoogleSignIn(
      clientId: _clientID,
      scopes: _scopes,
      forceCodeForRefreshToken: true, // to get the refresh token
    );
  }

  /* function to read client id 
  from the file given */
  Future<String> _getClientID() async {
    /* get the directory and combine it with the file path
    in order to extract the file from memory */
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    final file = File('$path/$_apiDataFile');

    /* try to read the file, 
    otherwise throw an exception */
    try {
      String contents = await file.readAsString();
      Map<String, dynamic> jsonData = jsonDecode(
        contents,
      ); // decode contents into json
      return jsonData['client_id']; // return the client id
    } catch (e) {
      throw FileSystemException("Error reading client ID from file: $e");
    }
  }

  /* *** GETTER METHODS *** */
  String? get email => _currentEmail;

  /// Function to sign in the user with google account
  Future<void> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Login annullato dall\'utente');
    }

    final serverAuthCode = account.serverAuthCode;
    if (serverAuthCode == null) {
      throw Exception(
        'serverAuthCode mancante. Verifica serverClientId e '
        'forceCodeForRefreshToken.',
      );
    }

    /* exchange server auth code for tokens */
    final tokenData = await _exchangeCodeForTokens(serverAuthCode);
    if (tokenData == null) {
      throw Exception('Scambio del codice di autorizzazione fallito');
    }

    final newAccount = GoogleAccount(
      email: account.email,
      displayName: account.displayName ?? account.email,
      accessToken: tokenData['access_token'] as String,
      refreshToken: tokenData['refresh_token'] as String,
      serverAuthCode: serverAuthCode,
      updatedAt: DateTime.now().toUtc(),
    );

    await _database.addGoogleAccount(newAccount);
    _currentEmail = account.email;
  }

  /// Function to get the account from the database
  /// without repeating the sign in process again
  Future<void> switchAccount(String email) async {
    final account = await _database.getGoogleAccountByEmail(email);
    if (account == null) {
      throw Exception('Account $email non trovato nel database');
    }
    _currentEmail = email;
  }

  /// Returns the access token for the current account
  /// If the procedure doesn't match any record, it throws an exception
  Future<String> getAccessToken({String? email}) async {
    final target = email ?? _currentEmail;
    if (target == null) {
      throw Exception(
        'Nessun account attivo. Effettua il login o switchAccount.',
      );
    }
    final account = await _database.getGoogleAccountByEmail(target);
    if (account == null) {
      throw Exception('Account $target non trovato');
    }
    return account.accessToken;
  }

  /// Function to make an authenticated [request] to the google api,
  /// using the access token and refreshing it if necessary.
  Future<http.Response> authenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) request, {
    String? email,
  }) async {
    final target = email ?? _currentEmail;
    if (target == null) {
      throw Exception('Nessun account attivo.');
    }

    var account = await _database.getGoogleAccountByEmail(target);
    if (account == null) {
      throw Exception('Account $target non trovato');
    }

    /* first call with current access token */
    var response = await request({
      'Authorization': 'Bearer ${account.accessToken}',
    });

    if (response.statusCode == 401) {
      /* token expired: refresh and retry */
      final refreshed = await _refreshAccessToken(account);
      if (refreshed == null) {
        throw Exception(
          'Refresh token non valido per $target. Effettua di nuovo il login.',
        );
      }

      await _database.addGoogleAccount(refreshed);
      account = refreshed;

      response = await request({
        'Authorization': 'Bearer ${account.accessToken}',
      });
    }

    return response;
  }

  /// Sign out officially the user from the google account
  /// connected to the application, and delele the record inside the database
  Future<void> signOut({String? email}) async {
    final target = email ?? _currentEmail;
    if (target == null) return;

    if (target == _currentEmail) {
      await _googleSignIn.disconnect();
      _currentEmail = null;
    }
    await _database.removeGoogleAccount(target);
  }

  /* function to exchange the authorization code
  for access and refresh tokens for the account */
  Future<Map<String, dynamic>?> _exchangeCodeForTokens(String code) async {
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'client_id': _clientID,
        'redirect_uri': '',
        'grant_type': 'authorization_code',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  /* function to refresh the access token for the account
  when it expires*/
  Future<GoogleAccount?> _refreshAccessToken(GoogleAccount account) async {
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'refresh_token': account.refreshToken,
        'client_id': _clientID,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return account.copyWith(
      accessToken: data['access_token'] as String,
      /* google may return a new access token sometimes */
      refreshToken: (data['refresh_token'] as String?) ?? account.refreshToken,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Public function to refresh the access token for the account
  /// with the given [email], letting the class extracting the
  /// corresponing record from the database and updating it
  Future<String?> refreshAccessToken(String email) async {
    final account = await _database.getGoogleAccountByEmail(email);
    if (account == null) return null;

    final refreshed = await _refreshAccessToken(account);
    if (refreshed == null) return null;

    await _database.addGoogleAccount(refreshed);
    return refreshed.accessToken;
  }

  /// Function to restore the account by the specified email,
  /// in order to make it clear
  Future<bool> restoreAccount(String email) async {
    final account = await _database.getGoogleAccountByEmail(email);
    if (account == null) return false;

    _currentEmail = email;
    return true;
  }
}
