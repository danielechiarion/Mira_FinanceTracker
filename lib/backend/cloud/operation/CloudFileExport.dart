import 'package:mira_finance_tracker/backend/service/session/BackgroundSession.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';

import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnection.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnectionForeground.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnectionBackground.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackupWriter.dart';

/// Class to handle general file import
/// involving all connection and file class
/// all together to accomplish the task
class CloudFileExport{
  /* define attributes to import */
  final CurrentSession _session;
  late CloudConnection _connection;
  late CloudBackupWriter _writer;
  final Future<void> Function(dynamic error)? _showErrorFunction;
  final bool _enableDisconnection;

  /// Constructor to instantiate the resources
  /// of the export operation starting from the [_session]. 
  /// Optionally provide a [_showErrorFunction] to display errors in the dedicated pages.
  /// Use the flag [_enableDisconnection] to allow the disconnection from the drive in order
  /// to free the resources. 
  /// Use the flag [foreground] to select whether to use either foreground or background connection. TRUE means foreground.
  CloudFileExport(this._session, {bool foreground = true, this._showErrorFunction, this._enableDisconnection = true}){
    _connection = foreground ? CloudConnectionForeground(_session) : CloudConnectionBackground(_session as BackgroundSession);
    _writer = CloudBackupWriter(_session.user);
  }

  /* *** GETTER METHODS *** */
  bool get _isErrorFunctionProvided => _showErrorFunction != null;

  /// Function to initialize the resources to use 
  /// inside this procedure
  Future<void> init() async {
    await _connection.init();
    await _writer.init();
  }

  /// Function to execute the exporting procedure
  /// to the Google Drive space selected
  /// Returns false if writing the backup fails.
  Future<bool> execute() async {
    /* understand if the user is connected to the google account,
    otherwise return it */
    if(!_session.user.isUserConnected) return true;

    /* start at first with writing the data 
    inside the drive */
    try{
      await _writer.execute();
    }catch(e){
      /* if an error is catched
      show it inside a page, if it is possible */
      if(_isErrorFunctionProvided) {
        await _showErrorFunction!(e.toString());
      }
      if(_enableDisconnection) await _connection.disconnect();
      if(!_isErrorFunctionProvided) rethrow;
      return false;
    }

    /* then understand if it's possible to disconnect
    the user and possibly disconnect it from drive,
    in order to remove the lock for other applications listening */
    if(_enableDisconnection) await _connection.disconnect();
    return true;
  }

  /// Function to dispose resources inside the class
  /// that have been used before
  Future<void> dispose() async {
    await _connection.dispose();
    await _writer.dispose();
  }
}
