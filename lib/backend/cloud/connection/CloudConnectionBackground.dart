import 'package:googleapis/drive/v3.dart' as drive;

import 'package:mira_finance_tracker/backend/service/session/BackgroundSession.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnection.dart';
import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';

/// Class extending [CloudConnection] to manage connection
/// when the application is used in foreground
class CloudConnectionBackground extends CloudConnection{
  /* define constants for the execution of the class */
  static const String _SESSIONFILEPATH = "background_session.json";

  /// Constructor of the instance providing attributes for the superclass
  CloudConnectionBackground(BackgroundSession session, {GoogleAuthenticationManager? authentication, DriveHttpHandler? handler}) :
    super(session, authentication: authentication, handler: handler);

  /// Function to handle connection on foreground and, eventually,
  /// adding information about current session on cloud. 
  /// Override of the method provided in [CloudConnection] class
  @override
  Future<CloudConnectionStatus> connect() async {
    CloudConnectionStatus status = await super.tryConnection(_SESSIONFILEPATH); // get first results from the connection test

    /* if the status is positive 
    create or upload the file with the session */
    if(status != CloudConnectionStatus.connection_established){
      return status;
    }

    drive.File? file = await super.fileService.findByName(_SESSIONFILEPATH); // try to find the file
    if(file == null) {await super.fileService.createJson(fileName: _SESSIONFILEPATH, content: super.session.toMap());} // if it's null create it from scratch
    else {await super.fileService.updateText(fileId: file.id!, content: super.session.toMap().toString());} // otherwise update the existing file

    return status; // finally return the status
  }

  /// Function to disconnect the application
  /// and removing the lock applied in order to make
  /// the cloud accessible to other application instances
  @override
  Future<bool> disconnect() async {
    drive.File? file = await super.fileService.findByName(_SESSIONFILEPATH); // try to find the file

    /* instead of deleting the file, 
    the file on google drive will be updated with the last details of the session */
    (super.session as BackgroundSession).endSession(); // first end session
    if(file == null) {await super.fileService.createJson(fileName: _SESSIONFILEPATH, content: super.session.toMap());} // if it's null create it from scratch
    else {await super.fileService.updateText(fileId: file.id!, content: super.session.toMap().toString());} // otherwise update the existing file
    return true;
  }
}