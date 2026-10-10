import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';

/// Function to handle autonomously the http requests to
/// Google Drive API, managing the token refresh automatically 
/// and giving a response back
class DriveHttpHandler extends http.BaseClient {
  final GoogleAuthenticationManager _auth;
  final String _email;
  final http.Client _inner;

  /// Constructor for the http handler class, requiring a:
  /// * [_auth] instance to manage authentication
  /// * [_email] of the user to manage the token refresh
  /// * [inner] optional http client to use for requests, defaults to a new instance
  DriveHttpHandler({
    required this._auth,
    required this._email,
    http.Client? inner,
  })  : _inner = inner ?? http.Client();

  /// Override function to send a custom [request] and returning a valid response
  /// to the caller
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    /* Get a valid token */
    final token = await _auth.getAccessToken(email: _email);
    request.headers['Authorization'] = 'Bearer $token';

    var response = await _inner.send(request); // execute the request

    /* if token has expired, try it one more time */
    if (response.statusCode == 401) {
      final refreshed = await _auth.refreshAccessToken(_email);
      if (refreshed == null) {
        throw Exception('Impossibile rinnovare il token per $_email');
      }
      
      /* build again the request 
      (body has been consumed before) */
      final retryRequest = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers['Authorization'] = 'Bearer $refreshed';
      if (request is http.Request) {
        retryRequest.bodyBytes = request.bodyBytes;
      }
      response = await _inner.send(retryRequest);
    }

    return response;
  }

  /// Override function to close the inner client
  /// and free the resources
  @override
  void close() {
    _inner.close();
    super.close();
  }
}