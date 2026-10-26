import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/service/session/BackgroundSession.dart';

import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnection.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnectionForeground.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnectionBackground.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackupReader.dart';

/// Class to handle general file import
/// involving all connection and file class
/// all together to accomplish the task
class CloudFileImport{
  /* define attributes to import */
  final CurrentSession _session;
  late CloudConnection _connection;
  late CloudBackupReader? _reader;
  final Future<void> Function(dynamic error)? _showErrorFunction;

  /// Constructor to require attributes to make it possible
  /// to import files starting from the [_session].
  /// Add the possibility to add an [_showErrorFunction] to display errors.
  /// Use the flag foreground to select either foregroud or background connection. TRUE means foreground.
  CloudFileImport(this._session, {bool foreground = true, this._showErrorFunction}){
    _connection = foreground ? CloudConnectionForeground(_session) : CloudConnectionBackground(_session as BackgroundSession);
  }

  /* *** GETTER METHODS *** */
  bool get _isErrorFunctionProvided => _showErrorFunction != null;

  /// Function to initialize the resources to use 
  /// inside this procedure
  Future<void> init() async {
    await _connection.init();
  }

  /// Function to execute the process
  /// of importing files from the drive
  Future<void> execute() async {
    /* first understand if the user 
    has the google account connected, otherwise finish the function */
    if(!_session.user.isUserConnected) return;

    /* see the return of the connection, 
    then understands what to throw */
    CloudConnectionStatus connectionStatus; 
    var attempts = 0;
    const maxAttempts = 30;

    /* define a number of attemps to 
    make sure the wait for the background doesn't last for long  */
    do {
      connectionStatus = await _connection.connect();

      if (connectionStatus == CloudConnectionStatus.wait_till_update) {
        await Future<void>.delayed(const Duration(seconds: 1));
        attempts++;
      }
    } while (
      connectionStatus == CloudConnectionStatus.wait_till_update &&
      attempts < maxAttempts
    );

    /* if there is a connection time out return the 
    error page, otherwise return the connection status if it's different from
    the correct one */
    if(connectionStatus == CloudConnectionStatus.wait_till_update && _isErrorFunctionProvided){
      await _connection.dispose();
      await _showErrorFunction!("ERROR [Connection Timeout]! Cloud connection locked by background session");
      return;
    }else if(connectionStatus != CloudConnectionStatus.connection_established && _isErrorFunctionProvided){
      await _connection.dispose();
      await _showErrorFunction!(connectionStatus);
      return;
    }else if(connectionStatus != CloudConnectionStatus.connection_established && !_isErrorFunctionProvided){
      return;
    }

    /* then try to read the files from the cloud
    if the database is not empty, then catch possible errors */
    _reader = CloudBackupReader(_session.user);
    await _reader!.init();

    try{
      if(await _reader!.isDriveEmpty()){
        return;
      }

      await _reader!.execute();
    }catch (e){
      await _reader!.dispose();
      if(_isErrorFunctionProvided) await _showErrorFunction!(e.toString());
    }
  }

  /// Function used to dispose resources
  /// used by the class
  Future<void> dispose() async {
    await _connection.dispose();
    if(_reader != null) await _reader!.dispose();
  }
}