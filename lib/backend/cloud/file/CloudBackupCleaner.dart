import 'package:googleapis/drive/v3.dart' as drive;

import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackup.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';

/// Permanently removes all files and folders in the app's private Drive space.
///
/// Call [init], then [execute], and finally [dispose]. Ask the user for
/// confirmation before calling [execute], since the deletion cannot be undone.
/// Backups created by older versions in the regular Drive space are not included.
class CloudBackupCleaner extends CloudBackup {
  static const String _DEVICEREGISTERFILEPATH = "device_register.json"; // static attribute to indicate the path of the device register
  
  /* define attributes */
  User _user;

  /// Constructor to pass the folder
  /// to the superclass [CloudBackupCleaner]
  CloudBackupCleaner(
    User user, {
    GoogleAuthenticationManager? authentication,
    DriveHttpHandler? handler,
  }): _user = user,
    super(user, authentication: authentication, handler: handler);

  /// Function to init the cleaner
  /// using authentication
  @override
  Future<void> init() {
    return super.initAuthentication();
  }

  /// Function to execute the cleaning of 
  /// the directory leaving only the entry point,
  /// which cannot be deleted.
  @override
  Future<void> execute() async {
    if(!(await _checkIfCleaningIsAvailable())) return; // first control if it's possible to clean the drive
    return super.fileService.deleteAppDataFolderContents();
  }

  /* function to control if cleaning is available
  by checking if no other device is using 
  the cloud */
  Future<bool> _checkIfCleaningIsAvailable() async {
    drive.File? file = await super.fileService.findByName(
      _DEVICEREGISTERFILEPATH,
    ); // try to find the file

    /* if the file is not found it's possible to delete,
    otherwise control if there are other devices 
    connected to the cloud */
    if(file == null) return true;

    Map<String, dynamic> fileContent = await super.fileService.readJson(file.id!);
    List<CurrentSession> registeredDevices = (fileContent['devices'] as List<Map<String, dynamic>>).map((device) {
      return CurrentSession.fromMap(Map<String, dynamic>.from(device));
    }).toList();

    /* if there is more than one registered
    device it's not possible to delete,
    otherwise proceed */
    if(registeredDevices.length <= 1) return true;

    /* get current session from the 
    shared preferences */
    CurrentSession session = CurrentSession(_user);
    await session.init();
    registeredDevices.remove(session);

    Map<String, dynamic> updatedContent = {
      "Object": "Device register",
      "devices": registeredDevices.map((element) => element.toMap())
    };
    await super.fileService.updateText(fileId: file.id!, content: updatedContent.toString());
    return false;
  }

  /// Function to override superclass [CloudBackup]
  /// and dispose resources
  @override
  Future<void> dispose() {
    super.disposeHandler();
    return Future<void>.value();
  }
}
