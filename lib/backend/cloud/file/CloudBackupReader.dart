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
  final bool _strictImport;

  /// Constructor of the cloud backup reader
  /// passing data to the superclass constructor
  CloudBackupReader(
    User user, {
    this._keyPassword,
    GoogleAuthenticationManager? authentication,
    DriveHttpHandler? handler,
    this._requireKey = true,
    bool financialControl = false,
    bool strictImport = false,
    String? email,
  }) : _strictImport = strictImport,
       super(
         user,
         authentication: authentication,
         handler: handler,
         email: email,
         financialControl: financialControl,
       );

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
      if (directory == null) {
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
    } else if (!_requireKey) {
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
    drive.File? directory = await super.fileService.findFolderByName(
      super.DATABASEDIRECTORY,
      parentFolderId: CloudFileService.appDataFolderId,
      spaces: 'appDataFolder',
    );
    if (directory == null) {
      print(
        '[CloudBackupReader] Cartella "${super.DATABASEDIRECTORY}" non '
        'trovata in appDataFolder: nessun file database da importare.',
      );
      return true;
    }

    List<drive.File> files = await super.fileService.listFiles(
      folderId: directory.id,
      spaces: 'appDataFolder',
    );
    final fileNames = files
        .map((file) => file.name ?? '(senza nome)')
        .join(', ');
    print(
      '[CloudBackupReader] File trovati in "${super.DATABASEDIRECTORY}" '
      '(${files.length}): ${files.isEmpty ? "(nessuno)" : fileNames}.',
    );
    return files.isEmpty;
  }

  /// Function to perform reading from the drive selected,
  /// in order to update data inside the application.
  /// Override function of the one provided in [CloudBackup]
  @override
  Future<void> execute() async {
    /* read user preferences */
    if (!super.financialControl) {
      try {
        await _readUserPreferences();
      } on Exception {
        if (_strictImport) rethrow;
      }
    }

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
    if (directory == null)
      throw _BackupFileNotFoundException(
        "During user preferences reading directory not found",
      );
    drive.File? file = await super.fileService.findByName(
      super.PREFERENCEFILENAME,
      folderId: directory.id,
      spaces: 'appDataFolder',
    );
    if (file == null)
      throw _BackupFileNotFoundException(
        "During user preferences reading file has not been found",
      );

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
      throw _BackupFileNotFoundException(
        "During reading procedure directory not found",
      );
    drive.File? file = await super.fileService.findByName(
      fileName,
      folderId: directory.id,
      spaces: 'appDataFolder',
    );
    if (file == null)
      throw _BackupFileNotFoundException(
        "During reading procedure file has not been found",
      );

    /* decrypt the stored bytes and parse the original JSON */
    final encryptedContent = await super.fileService.readBytes(file.id!);
    final content = await super.keyManager.decryptData(encryptedContent);
    return jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
  }

  /* function to read data from the files 
  in the selected drive and
  import them into the database */
  Future<void> _readDatabaseData() async {
    if (!super.financialControl) {
      await _importBackupSection(
        super.COUNTERPARTIESFILENAME,
        super.database.importCounterparties,
      );
      await _importBackupSection(
        super.FINANCIALINSTITUTESFILENAME,
        super.database.importFinancialInstitutes,
      );
    }
    await _importBackupSection(
      super.BANKACCOUNTSFILENAME,
      super.database.importBankAccounts,
    );
    await _importBackupSection(
      super.TRANSACTIONSFILENAME,
      super.database.importTransactions,
    );
    await _importBackupSection(
      super.BILLINGSFILENAME,
      super.database.importPeriodicAccountBillings,
    );
    await _importBackupSection(
      super.PERIODICTRANSACTIONSFILENAME,
      super.database.importPeriodicTransactions,
    );
    if (!super.financialControl) {
      await _importBackupSection(
        super.FINANCIALMODELSFILENAME,
        super.database.importFinancialInstrumentModels,
      );
    }
    await _importBackupSection(
      super.FINANCIALINSTRUMENTSFILENAME,
      super.database.importFinancialInstruments,
    );
    await _importBackupSection(
      super.STEPINTERESTSFILENAME,
      (content) => super.database.importStepInterests(
        content,
        notModels: super.financialControl,
      ),
    );
  }

  Future<void> _importBackupSection(
    String fileName,
    Future<void> Function(Map<String, dynamic>) import,
  ) async {
    try {
      final content = await _readEncryptedData(
        super.DATABASEDIRECTORY,
        fileName,
      );
      await import(content);
    } on _BackupFileNotFoundException {
      if (_strictImport) rethrow;
    }
  }
}

class _BackupFileNotFoundException implements Exception {
  const _BackupFileNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}
