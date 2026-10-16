
import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;

import 'package:mira_finance_tracker/classes/account/User.dart';

import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackup.dart';

class CloudBackupWriter extends CloudBackup {
  /// Constructor of the cloud backup writer 
  /// passing data to the superclass constructor
  CloudBackupWriter(User user, {GoogleAuthenticationManager? authentication, DriveHttpHandler? handler}) :
    super(user, authentication: authentication, handler: handler);

  /// Function to execute the process of writing
  /// the data inside the drive
  @override
  Future<void> execute() async {
    /* first control is to find the file
    of the key manager, otherwise save it */
    drive.File? keyFile = await super.fileService.findByName(super.KEYDIRECTORY+super.CRYPTOFILENAME);
    if(keyFile == null) await _saveCryptographyKey();

    /* then save the user preferences
    and database data */
  }

  /* function to save cryptography file
  inside the dedicated drive space */
  Future<void> _saveCryptographyKey() async {
    drive.File? directoryPath = await super.fileService.findFolderByName(super.KEYDIRECTORY); // fist find folder by name
    /* if folder has not been found, 
    create it and return the result */
    directoryPath = directoryPath ?? await super.fileService.createFolder(folderName: super.KEYDIRECTORY);

    /* save the exported data of the key
    inside the drive space */
    await super.fileService.createJson(fileName: super.CRYPTOFILENAME, content: await super.keyManager.exportKeyData(), parentFolderId: directoryPath.id);
  }

  /* function to save user preferences 
  inside the dedicated drive space */
  Future<void> _saveUserPrefecences() async {
    /* first use cypher data 
    and then save in into drive */
    List<int> cryptoData = await super.keyManager.encryptData(base64Decode(jsonEncode(super.userPreferences.exportPreferences())));
    await _saveEncryptedData(cryptoData, super.PREFERENCEDIRECTORY, super.PREFERENCEFILENAME);
  }

  /* general function to save encrypted data inside a file */
  Future<void> _saveEncryptedData(List<int> content, String directory, String fileName) async {
    drive.File? directoryPath = await super.fileService.findFolderByName(directory); // fist find folder by name
    /* if folder has not been found, 
    create it and return the result */
    directoryPath = directoryPath ?? await super.fileService.createFolder(folderName: directory);

    /* then saved the encrypted file
    inside the dedicated space.
    But first, ensure it has been created */
    drive.File? file = await super.fileService.findByName(fileName, folderId: directoryPath.id);
    if(file == null) {await super.fileService.createBytes(fileName: fileName, bytes: content);}
    else {await super.fileService.updateBytes(fileId: file.id!, bytes: content);}
  }
}