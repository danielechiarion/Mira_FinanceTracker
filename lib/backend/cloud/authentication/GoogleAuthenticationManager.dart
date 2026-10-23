import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAccount.dart';

/// Class to handle authentication management
/// with google account in order to access into drive resource
class GoogleAuthenticationManager {
  /* define attributes */
  late final String _clientID;
  String? _clientSecret;
  final List<String> _scopes;
  final SystemDatabaseWrapper _database;

  /* define attributes also for 
  following operations */
  late final GoogleSignIn _googleSignIn;
  String? _currentEmail;

  /* define constants for the use of the application */
  static const String _apiDataFile = "assets/data/credentials.json";

  /// Constructor to initialize the authenticator manager for google account,
  /// defining the [_scopes] to access into drive resources
  // Existing accounts may need to sign in again to grant the appData scope.
  GoogleAuthenticationManager({
    this._scopes = const [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
      'openid',
      'email',
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

  String get _credentialPrefix {
    if (kIsWeb) return 'web';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => 'desktop',
      _ => throw UnsupportedError(
          'Google sign-in is not configured for this platform.',
        ),
    };
  }

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Closes the system database connection used by this manager.
  Future<void> close() async {
    await _database.closeDatabase();
  }

  /* function to read client id
  from the configured asset */
  Future<String> _getClientID() async {
    final contents = await rootBundle.loadString(_apiDataFile);
    final jsonData = jsonDecode(contents) as Map<String, dynamic>;
    final prefix = _credentialPrefix;
    final legacyWindowsConfig =
        prefix == 'desktop' && _isWindows && !jsonData.containsKey('desktop_client_id');
    final clientIdKey = legacyWindowsConfig
        ? 'windows_client_id'
        : '${prefix}_client_id';
    final clientSecretKey = legacyWindowsConfig
        ? 'windows_client_secret'
        : '${prefix}_client_secret';
    final clientId = jsonData[clientIdKey];
    if (clientId is! String || clientId.isEmpty) {
      throw const FormatException(
        'Google OAuth client ID is missing from credentials. Add the '
        'platform-specific client ID, for example "desktop_client_id", '
        '"android_client_id", or "ios_client_id".',
      );
    }

    final clientSecret = jsonData[clientSecretKey];
    if (clientSecret != null &&
        (clientSecret is! String || clientSecret.isEmpty)) {
      throw FormatException(
        'The OAuth client secret "$clientSecretKey" must be a non-empty string.',
      );
    }
    _clientSecret = clientSecret as String?;

    return clientId;
  }

  /* *** GETTER METHODS *** */
  String? get email => _currentEmail;

  /// Function to sign in the user with google account
  Future<void> signIn() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _signInWithWindowsBrowser();
      return;
    }

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
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
        await _googleSignIn.disconnect();
      }
      _currentEmail = null;
    }
    await _database.removeGoogleAccount(target);
  }

  /// Authenticates a Windows user through the system browser and a loopback callback.
  Future<void> _signInWithWindowsBrowser() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}';
    final codeVerifier = _generateSecureValue();
    final state = _generateSecureValue();
    final challenge = await Sha256().hash(utf8.encode(codeVerifier));
    final codeChallenge = base64Url.encode(challenge.bytes).replaceAll('=', '');

    final authorizationUri =
        Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': _clientID,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': _scopes.join(' '),
          'access_type': 'offline',
          'prompt': 'consent',
          'state': state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        });

    try {
      final callback = _waitForOAuthCallback(
        server,
      ).timeout(const Duration(minutes: 5));
      if (!await launchUrl(
        authorizationUri,
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError(
          'Unable to open the system browser for Google sign-in.',
        );
      }

      final callbackUri = await callback;
      if (callbackUri.queryParameters['state'] != state) {
        throw StateError('Google sign-in returned an invalid state.');
      }

      final authorizationError = callbackUri.queryParameters['error'];
      if (authorizationError != null) {
        throw StateError(
          'Google sign-in was not completed: $authorizationError',
        );
      }

      final code = callbackUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw StateError('Google did not return an authorization code.');
      }

      final tokenData = await _exchangeCodeForTokens(
        code,
        redirectUri: redirectUri,
        codeVerifier: codeVerifier,
      );
      if (tokenData == null) {
        throw StateError('Google authorization code exchange failed.');
      }

      final accessToken = tokenData['access_token'];
      final refreshToken = tokenData['refresh_token'];
      if (accessToken is! String || accessToken.isEmpty) {
        throw StateError('Google did not return an access token.');
      }
      if (refreshToken is! String || refreshToken.isEmpty) {
        throw StateError(
          'Google did not return a refresh token. Revoke the app access '
          'from your Google account and try again.',
        );
      }

      final profile = await _getGoogleProfile(accessToken);
      final email = profile['email'];
      if (email is! String || email.isEmpty) {
        throw StateError('Google did not return an account email address.');
      }

      final account = GoogleAccount(
        email: email,
        displayName: profile['name'] as String? ?? email,
        accessToken: accessToken,
        refreshToken: refreshToken,
        serverAuthCode: code,
        updatedAt: DateTime.now().toUtc(),
      );

      await _database.addGoogleAccount(account);
      _currentEmail = email;
    } finally {
      await server.close(force: true);
    }
  }

  /// Waits for the one-time authorization response from the system browser.
  Future<Uri> _waitForOAuthCallback(HttpServer server) async {
    await for (final request in server) {
      final response = request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><html><body>'
          '<p>Google sign-in finished. You can close this window.</p>'
          '</body></html>',
        );
      await response.close();
      return request.uri;
    }

    throw StateError(
      'The Google sign-in callback server stopped unexpectedly.',
    );
  }

  /// Generates a high-entropy URL-safe value for OAuth state and PKCE.
  String _generateSecureValue() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Retrieves the authenticated Google profile required for database storage.
  Future<Map<String, dynamic>> _getGoogleProfile(String accessToken) async {
    final response = await http.get(
      Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Google profile request failed with status ${response.statusCode}.',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /* function to exchange the authorization code
  for access and refresh tokens for the account */
  Future<Map<String, dynamic>?> _exchangeCodeForTokens(
    String code, {
    String redirectUri = '',
    String? codeVerifier,
  }) async {
    final body = <String, String>{
      'code': code,
      'client_id': _clientID,
      'redirect_uri': redirectUri,
      'grant_type': 'authorization_code',
      'code_verifier': ?codeVerifier,
      'client_secret': ?_clientSecret,
    };
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (response.statusCode == 200) {
      final tokenData = jsonDecode(response.body);
      if (tokenData is Map<String, dynamic>) {
        return tokenData;
      }

      throw StateError('Google returned an invalid token response.');
    }

    String? oauthError;
    String? errorDescription;
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map<String, dynamic>) {
        oauthError = errorData['error'] as String?;
        errorDescription = errorData['error_description'] as String?;
      }
    } on FormatException {
      // The HTTP status remains useful when Google returns a non-JSON response.
    }

    final details = [?oauthError, ?errorDescription].join(': ');
    final hint = switch (oauthError) {
      'invalid_client' || 'unauthorized_client' =>
        'Verify that credentials.json contains the OAuth client ID for a '
            'Desktop app.',
      'invalid_request'
          when errorDescription?.contains('client_secret') ?? false =>
        'Add the matching platform-specific client secret to credentials.json, '
            'or replace the Windows client with a Desktop app OAuth client.',
      'invalid_grant' =>
        'The authorization code may have expired, or the redirect URI or '
            'PKCE verifier did not match. Retry the Google sign-in.',
      _ => null,
    };

    throw StateError(
      'Google token exchange failed (HTTP ${response.statusCode})'
      '${details.isEmpty ? '' : ': $details'}'
      '${hint == null ? '' : ' $hint'}',
    );
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
        'client_secret': ?_clientSecret,
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
