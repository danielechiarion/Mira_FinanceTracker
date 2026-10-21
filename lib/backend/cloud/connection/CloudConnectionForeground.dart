import 'package:googleapis/drive/v3.dart' as drive;

import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/service/session/BackgroundSession.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/CloudConnection.dart';
import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';

/// Class extending [CloudConnection] to manage connection
/// when the application is used in foreground
class CloudConnectionForeground extends CloudConnection {
  /// Constructor of the instance providing attributes for the superclass
  CloudConnectionForeground(
    CurrentSession session, {
    GoogleAuthenticationManager? authentication,
    DriveHttpHandler? handler,
  }) : super(session, authentication: authentication, handler: handler);

  /// Function to handle connection on foreground and, eventually,
  /// adding information about current session on cloud.
  /// Override of the method provided in [CloudConnection] class
  @override
  Future<CloudConnectionStatus> connect() async {
    CloudConnectionStatus status = await super.tryConnection(
      super.FOREGROUNDSESSIONFILEPATH,
    ); // get first results from the connection test

    /* if the status is positive 
    create or upload the file with the session */
    if (status != CloudConnectionStatus.connection_established) {
      return status;
    }

    /* in the connection foreground first you have to look for
    the background session. If it's running, just run a status to wait
    till session is completed, because of the update of the database. */
    drive.File? backgroundFile = await super.findSessionFile(
      super.BACKGROUNDSESSIONFILEPATH,
    );
    if (backgroundFile != null) {
      BackgroundSession backgroundSession = BackgroundSession.fromMap(
        await super.fileService.readJson(backgroundFile.id!),
      );
      if (!backgroundSession.channelAvailable())
        return CloudConnectionStatus
            .wait_till_update; // return the status to wait till background is finished
    }

    drive.File? file = await super.findSessionFile(
      super.FOREGROUNDSESSIONFILEPATH,
    ); // try to find the file
    if (file == null) {
      await super.createSessionFile(
        super.FOREGROUNDSESSIONFILEPATH,
        super.session.toMap(),
      );
    } // if it's null create it from scratch
    else {
      await super.fileService.updateText(
        fileId: file.id!,
        content: super.session.toMap().toString(),
      );
    } // otherwise update the existing file

    return status; // finally return the status
  }

  /// Function to disconnect the application
  /// and removing the lock applied in order to make
  /// the cloud accessible to other application instances
  @override
  Future<bool> disconnect() async {
    drive.File? file = await super.findSessionFile(
      super.FOREGROUNDSESSIONFILEPATH,
    ); // try to find the file
    if (file == null)
      return true; // if file has not found it means that the session has already been deleted

    /* otherwise try to delete the file.
    Possible errors must be signaled with the boolean flag */
    await super.fileService.delete(file.id!);
    return true;
  }
}
