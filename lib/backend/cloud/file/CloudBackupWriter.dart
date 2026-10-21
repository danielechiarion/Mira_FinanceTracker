import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';

import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackup.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudFileService.dart';

/// Class to handle actions of writing
/// extending [CloudBackup] class
class CloudBackupWriter extends CloudBackup {
  /// Constructor of the cloud backup writer
  /// passing data to the superclass constructor
  CloudBackupWriter(
    User user, {
    GoogleAuthenticationManager? authentication,
    DriveHttpHandler? handler,
  }) : super(user, authentication: authentication, handler: handler);

  /// Function to execute the process of writing
  /// the data inside the drive
  @override
  Future<void> execute() async {
    final keyDirectory = await super.fileService.findFolderByName(
      super.KEYDIRECTORY,
      parentFolderId: CloudFileService.appDataFolderId,
      spaces: 'appDataFolder',
    );
    final keyFile = keyDirectory == null
        ? null
        : await super.fileService.findByName(
            super.CRYPTOFILENAME,
            folderId: keyDirectory.id,
            spaces: 'appDataFolder',
          );
    if (keyFile == null) await _saveCryptographyKey();

    /* then save the user preferences
    and database data */
    await _saveUserPrefecences();
    await _saveDatabaseData();
  }

  /* function to save cryptography file
  inside the dedicated drive space */
  Future<void> _saveCryptographyKey() async {
    drive.File? directoryPath = await super.fileService.findFolderByName(
      super.KEYDIRECTORY,
      parentFolderId: CloudFileService.appDataFolderId,
      spaces: 'appDataFolder',
    );
    /* if folder has not been found, 
    create it and return the result */
    directoryPath =
        directoryPath ??
        await super.fileService.createFolder(
          folderName: super.KEYDIRECTORY,
          parentFolderId: CloudFileService.appDataFolderId,
        );

    /* save the exported data of the key
    inside the drive space */
    await super.fileService.createJson(
      fileName: super.CRYPTOFILENAME,
      content: await super.keyManager.exportKeyData(),
      parentFolderId: directoryPath.id,
    );
  }

  /* function to save user preferences 
  inside the dedicated drive space */
  Future<void> _saveUserPrefecences() async {
    /* first use cypher data 
    and then save in into drive */
    List<int> cryptoData = await super.keyManager.encryptData(
      base64Decode(jsonEncode(super.userPreferences.exportPreferences())),
    );
    await _saveEncryptedData(
      cryptoData,
      super.PREFERENCEDIRECTORY,
      super.PREFERENCEFILENAME,
    );
  }

  /* general function to save encrypted data inside a file */
  Future<void> _saveEncryptedData(
    List<int> content,
    String directory,
    String fileName,
  ) async {
    drive.File? directoryPath = await super.fileService.findFolderByName(
      directory,
      parentFolderId: CloudFileService.appDataFolderId,
      spaces: 'appDataFolder',
    );
    /* if folder has not been found, 
    create it and return the result */
    directoryPath =
        directoryPath ??
        await super.fileService.createFolder(
          folderName: directory,
          parentFolderId: CloudFileService.appDataFolderId,
        );

    /* then saved the encrypted file
    inside the dedicated space.
    But first, ensure it has been created */
    drive.File? file = await super.fileService.findByName(
      fileName,
      folderId: directoryPath.id,
      spaces: 'appDataFolder',
    );
    if (file == null) {
      await super.fileService.createBytes(
        fileName: fileName,
        bytes: content,
        parentFolderId: directoryPath.id,
      );
    } else {
      await super.fileService.updateBytes(fileId: file.id!, bytes: content);
    }
  }

  /* Function to save data from database on 
  the selected drive folder */
  Future<void> _saveDatabaseData() async {
    List<int> byteContent; // declare list to convert json into bytes
    int yearLimit = super.userPreferences
        .getPreference('backupTime')
        .currentValue; // extract interest user preference

    /* save files for all the categories */
    byteContent = await super.keyManager.encryptData(
      base64Decode(jsonEncode(await super.database.exportCounterparties())),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.COUNTERPARTIESFILENAME,
    );
    byteContent = await super.keyManager.encryptData(
      base64Decode(
        jsonEncode(await super.database.exportFinancialInstitutes()),
      ),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.FINANCIALINSTITUTESFILENAME,
    );
    byteContent = await super.keyManager.encryptData(
      base64Decode(
        jsonEncode(await super.database.exportBankAccounts(yearLimit)),
      ),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.BANKACCOUNTSFILENAME,
    );
    byteContent = await super.keyManager.encryptData(
      base64Decode(
        jsonEncode(await super.database.exportTransactions(yearLimit)),
      ),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.TRANSACTIONSFILENAME,
    );
    byteContent = await super.keyManager.encryptData(
      base64Decode(
        jsonEncode(await super.database.exportPeriodicAccountBillings()),
      ),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.BILLINGSFILENAME,
    );
    byteContent = await super.keyManager.encryptData(
      base64Decode(
        jsonEncode(await super.database.exportPeriodicTransactions()),
      ),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.PERIODICTRANSACTIONSFILENAME,
    );
    byteContent = await super.keyManager.encryptData(
      base64Decode(
        jsonEncode(await super.database.exportFinancialInstrumentModels()),
      ),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.FINANCIALMODELSFILENAME,
    );
    byteContent = await super.keyManager.encryptData(
      base64Decode(
        jsonEncode(await super.database.exportFinancialInstruments(yearLimit)),
      ),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.FINANCIALINSTRUMENTSFILENAME,
    );
    byteContent = await super.keyManager.encryptData(
      base64Decode(
        jsonEncode(await super.database.exportStepInterests(yearLimit)),
      ),
    );
    await _saveEncryptedData(
      byteContent,
      super.DATABASEDIRECTORY,
      super.STEPINTERESTSFILENAME,
    );
  }
}
