import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';

import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackup.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudFileService.dart';

/// Class to handle reading actions
/// from [CloudBackup] class
class CloudBackupReader extends CloudBackup {
  /* attributes definition */
  String? _keyPassword;
  bool _requireKey;

  /// Constructor of the cloud backup reader
  /// passing data to the superclass constructor
  CloudBackupReader(
    User user, {
    this._keyPassword,
    GoogleAuthenticationManager? authentication,
    DriveHttpHandler? handler,
    this._requireKey = true
  }) : super(user, authentication: authentication, handler: handler);

  /// Override function of [CloudBackup] class to initialize resources.
  /// Change, in particular, the set of instructions to recover key
  /// if they are present in the drive and has not been generated before.
  /// Throws a [StateError] if it's not possible to generate or recover the key.
  @override
  Future<void> init() async {
    /* restore authentication if it's given */
    if (!super.givenAuthentication) {
      await super.authenticationManager.init();
      await super.authenticationManager.restoreAccount(super.email);
    }

    /* initialize database, preference
    and all the other resources */
    await super.database.init();
    await super.userPreferences.init();

    /* avoid the init and try 
    to see if it's possible to recover the key */
    bool recoverResult = await super.keyManager.recoverKey();
    /* if no key has found, try to find it from the
    drive and import it, otherwise generate the key randomly */
    if (!recoverResult && _keyPassword != null) {
      /* first try to find file and folder */
      drive.File? directory = await super.fileService.findFolderByName(
        super.KEYDIRECTORY,
        parentFolderId: CloudFileService.appDataFolderId,
        spaces: 'appDataFolder',
      );
      if (directory == null){
        throw StateError(
          "[CloudBackupReader] cannot recover key because dedicated folder in cloud has not been created.",
        );
      }
      drive.File? file = await super.fileService.findByName(
        super.CRYPTOFILENAME,
        folderId: directory.id,
        spaces: 'appDataFolder',
      );
      if (file == null) {
        throw StateError(
          "[CloudBackupReader] cannot recover key because file has not been found",
        );
      }
      /* then make get the file content
      and give it to the import function of the key manager */
      bool keyResult = await super.keyManager.importKeyData(
        _keyPassword!,
        await super.fileService.readJson(file.id!),
      );
      if (!keyResult)
        throw ArgumentError(
          "[CloudBackupError] key reading operation didn't end successfully",
        );
    } else if(!_requireKey){
      throw StateError(
        "[CloudBackupReader] cannot recover key not saved and with no password given",
      );
    }
  }

  /// Function to undestand if the 
  /// drive is empty, so no values has been saved inside
  Future<bool> isDriveEmpty() async {
    /* control if the directory is empty,
    otherwise check the list inside */
    drive.File? directory = await super.fileService.findFolderByName(super.DATABASEDIRECTORY);
    if(directory == null) return true;

    List<drive.File?> files = await super.fileService.listFiles(folderId: directory.id);
    return files.isEmpty;
  }

  /// Function to perform reading from the drive selected,
  /// in order to update data inside the application.
  /// Override function of the one provided in [CloudBackup]
  @override
  Future<void> execute() async {
    /* read user preferences */
    try {
      await _readUserPreferences();
    } on Exception {}

    /* function import data from the database */
    await _readDatabaseData();
  }

  /* function to read preferences
  from file update it */
  Future<void> _readUserPreferences() async {
    /* get directory and file */
    drive.File? directory = await super.fileService.findFolderByName(
      super.PREFERENCEDIRECTORY,
      parentFolderId: CloudFileService.appDataFolderId,
      spaces: 'appDataFolder',
    );
    if (directory == null) throw Exception("During user preferences reading directory not found");
    drive.File? file = await super.fileService.findByName(
      super.PREFERENCEFILENAME,
      folderId: directory.id,
      spaces: 'appDataFolder',
    );
    if (file == null) throw Exception("During user preferences reading file has not been found",);

    await super.userPreferences.importPreferences(
      await _readEncryptedData(
        super.PREFERENCEDIRECTORY,
        super.PREFERENCEFILENAME,
      ),
    );
  }

  /// Function to read encrypted data from the file given
  /// and decrypt it to return a valid format to be processed
  /// inside the application
  Future<Map<String, dynamic>> _readEncryptedData(
    String directoryName,
    String fileName,
  ) async {
    /* find files and folder and throw exception
    if one of these has not been found */
    drive.File? directory = await super.fileService.findFolderByName(
      directoryName,
      parentFolderId: CloudFileService.appDataFolderId,
      spaces: 'appDataFolder',
    );
    if (directory == null)
      throw Exception("During reading procedure directory not found");
    drive.File? file = await super.fileService.findByName(
      fileName,
      folderId: directory.id,
      spaces: 'appDataFolder',
    );
    if (file == null)
      throw Exception("During reading procedure file has not been found");

    /* then try to read bytes from content 
    and then decrypt it*/
    List<int> content = await super.fileService.readBytes(file.id!);
    return jsonDecode(base64Encode(content));
  }

  /* function to read data from the files 
  in the selected drive and
  import them into the database */
  Future<void> _readDatabaseData() async {
    Map<String, dynamic> content; // object to contain decrypted content

    /* for each section decrypt data and then 
    import inside the database.
    Use try catch to avoid exceptions during conversion
    or when the file is not found. */
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.COUNTERPARTIESFILENAME,
      );
      await super.database.importCounterparties(content);
    } on Exception {}
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.FINANCIALINSTITUTESFILENAME,
      );
      await super.database.importFinancialInstitutes(content);
    } on Exception {}
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.BANKACCOUNTSFILENAME,
      );
      await super.database.importBankAccounts(content);
    } on Exception {}
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.TRANSACTIONSFILENAME,
      );
      await super.database.importTransactions(content);
    } on Exception {}
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.BILLINGSFILENAME,
      );
      await super.database.importPeriodicAccountBillings(content);
    } on Exception {}
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.PERIODICTRANSACTIONSFILENAME,
      );
      await super.database.importPeriodicTransactions(content);
    } on Exception {}
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.FINANCIALMODELSFILENAME,
      );
      await super.database.importFinancialInstrumentModels(content);
    } on Exception {}
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.FINANCIALINSTRUMENTSFILENAME,
      );
      await super.database.importFinancialInstruments(content);
    } on Exception {}
    try {
      content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        super.STEPINTERESTSFILENAME,
      );
      await super.database.importStepInterests(content);
    } on Exception {}
  }
}
