import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackup.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Permanently removes all files and folders in the app's private Drive space.
///
/// Call [init], then [execute], and finally [dispose]. Ask the user for
/// confirmation before calling [execute], since the deletion cannot be undone.
/// Backups created by older versions in the regular Drive space are not included.
class CloudBackupCleaner extends CloudBackup {
  /// Constructor to pass the folder
  /// to the superclass [CloudBackupCleaner]
  CloudBackupCleaner(
    User user, {
    GoogleAuthenticationManager? authentication,
    DriveHttpHandler? handler,
  }) : super(user, authentication: authentication, handler: handler);

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
  Future<void> execute() {
    return super.fileService.deleteAppDataFolderContents();
  }

  /// Function to override superclass [CloudBackup]
  /// and dispose resources
  @override
  Future<void> dispose() {
    super.disposeHandler();
    return Future<void>.value();
  }
}
