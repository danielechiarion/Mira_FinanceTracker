import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:meta/meta.dart';

import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudFileService.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';

/// Define constructor to return the status of the connection,
/// in order to act or show something to the user
enum CloudConnectionStatus {
  connection_established, // it means that connection has been established
  network_error, // it means that it was not possible to reach the cloud
  line_busy, // it means another device is using the application with the same cloud
  authentication_failed, // it means that the authentication has not been restored from database
  wait_till_update,
}

/// Class to handle general cloud connection
/// and define methods to be implemented both in foreground and background
abstract class CloudConnection {
  /* define global variables for the path of the 
  session files */
  static const String _BACKGROUNDSESSIONFILEPATH = "background_session.json";
  static const String _FOREGROUNDSESSIONFILEPATH = "foreground_session.json";
  static const String _DEVICEREGISTERFILEPATH = "device_register.json";

  /* attributes definition */
  CurrentSession _session;
  late DriveHttpHandler _handler;
  GoogleAuthenticationManager _authenticationManager;
  late CloudFileService _fileService;

  late bool
  _authenticationRestored; // bool to indicate if authentication has been restored
  late bool
  _givenAuthentication; // bool to indicate if authentication has been given as a parameter
  late bool
  _givenHandler; // bool to indicate if handler has been given as a parameter

  /// Constructor to manage cloud connection
  /// in order to make it start
  /// * [_session] instance where all the information about user and running device have been saved
  /// * [_authenticationManager] class used for the authentication of the user
  CloudConnection(
    this._session, {
    GoogleAuthenticationManager? authentication,
    DriveHttpHandler? handler,
  }) : _authenticationManager =
           authentication ?? GoogleAuthenticationManager() {
    _handler =
        handler ??
        DriveHttpHandler(
          auth: _authenticationManager,
          email: _session.user.email,
        ); // instance the handler
    _fileService = CloudFileService(
      email: _session.user.email,
      client: _handler,
    ); // initialize the file service

    /* update the flag to indicate if authentication 
    manager and handler have been given as a parameter */
    _givenAuthentication = authentication != null;
    _givenHandler = handler != null;
  }

  /* getter for constants for file paths */
  @protected
  String get BACKGROUNDSESSIONFILEPATH => _BACKGROUNDSESSIONFILEPATH;
  @protected
  String get FOREGROUNDSESSIONFILEPATH => _FOREGROUNDSESSIONFILEPATH;
  @protected
  String get DEVICEREGISTERFILEPATH => _DEVICEREGISTERFILEPATH;

  /// Function to initialize resources
  /// for the cloud connection, such as the authentication manager,
  /// which is used then by the http handler
  Future<void> init() async {
    if (_givenAuthentication)
      return; // return if the authentication has been given, which means it has initialized already

    await _authenticationManager
        .init(); // initialize the google authentication manager

    /* when the operation has finished,
    try to restore the account from the email. 
    If this doesn't succeed, set a flag to consider later */
    _authenticationRestored = await _authenticationManager.restoreAccount(
      _session.user.email,
    );
  }

  /// Function that tries connection and returns
  /// the result of the connection using also the file saved
  /// in [sessionPath] to control if the are active sessions
  Future<CloudConnectionStatus> tryConnection(String sessionPath) async {
    /* first let's see if the authentication has been restored
    for the selected user, otherwise return the status */
    if (!_authenticationRestored) {
      return CloudConnectionStatus.authentication_failed;
    }

    /* then try to send a test request
    to google drive in order to see if the connection works */
    try {
      final request = http.Request(
        'GET',
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files'
          '?pageSize=1&fields=files(id)',
        ),
      );
      await _handler.send(request);
    } on Exception {
      return CloudConnectionStatus.network_error;
    }

    /* if the control has passed try to find 
    if there is another application session using cloud */
    drive.File? file = await findSessionFile(sessionPath);
    if (file == null) return CloudConnectionStatus.connection_established; // if no file has found return that connection has been established

    /* otherwise get the session from the 
    json file and compare it to current session */
    Map<String, dynamic> map = await _fileService.readJson(file.id!);
    return _session.isBusy(map)
        ? CloudConnectionStatus.line_busy
        : CloudConnectionStatus.connection_established;
  }

  @protected
  Future<drive.File?> findSessionFile(String fileName) {
    return _fileService.findByName(fileName, spaces: 'appDataFolder');
  }

  @protected
  Future<drive.File> createSessionFile(
    String fileName,
    Map<String, dynamic> content,
  ) {
    return _fileService.createJson(
      fileName: fileName,
      content: content,
      parentFolderId: CloudFileService.appDataFolderId,
    );
  }

  /// Function to dispose resources created inside the instance
  Future<void> dispose() async {
    if (_givenHandler) _handler.close();
  }

  /* === ABSTRACT METHODS ===
  to be implemented by the subclasses */

  /// Function that tries connection to drive
  /// and returns the status of the connection
  Future<CloudConnectionStatus> connect();

  /// Function used to disconnect from cloud
  /// so as to live the channel free from occupation
  /// and let other application instances use it.
  Future<bool> disconnect();

  /* === GETTER METHODS ===
  created especially for subclasses */
  @protected
  CurrentSession get session => _session;
  @protected
  CloudFileService get fileService => _fileService;
}
