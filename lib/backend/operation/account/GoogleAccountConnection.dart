import 'package:googleapis/drive/v3.dart' as drive;

import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudFileService.dart';
import 'package:mira_finance_tracker/backend/service/KeyManager.dart';
import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackupReader.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Validates cloud key ownership and decryption before saving Google credentials.
class GoogleAccountConnection {
  final User _user;
  final GoogleAuthenticationManager _authentication;
  late final CloudBackupReader _cloudReader;
  final SystemDatabaseWrapper _systemDatabase;
  late final UserDatabaseWrapper _userDatabase;

  static const String _keyDirectory = 'crypto/';
  static const String _keyFileName = 'crypto_key.json';

  /// Creates a Google connection operation for the given local [user].
  GoogleAccountConnection(
    this._user,
    GoogleAuthenticationManager authentication, {
    UserDatabaseWrapper? systemDatabase,
  }) : _authentication = authentication, _systemDatabase = systemDatabase ?? SystemDatabaseWrapper() {
    _userDatabase = UserDatabaseWrapper(_user);
    _cloudReader = CloudBackupReader(_user, authentication: authentication);
  }

  /// Connects Google, validates the cloud key, then persists the account.
  Future<void> execute([String? decryptionKey]) async {
    await _authentication.init();
    await _cloudReader.init();

    DriveHttpHandler? handler;
    KeyManager? keyManager;
    try {
      /* initialize the two database
      resources in order to be operative */
      await _systemDatabase.init();
      await _userDatabase.init();
      // Keep the Google credentials in memory until every validation succeeds.
      await _authentication.signIn(persistAccount: false);
      final googleEmail = _authentication.email;
      if (googleEmail == null || googleEmail.isEmpty) {
        throw StateError('Google non ha restituito un indirizzo email.');
      }

      if (await _systemDatabase.isGoogleEmailAssignedToAnotherUser(
        googleEmail,
        _user.username,
      )) {
        throw StateError(
          'Questo account Google è già associato a un altro account Mira.',
        );
      }

      final driveHandler = DriveHttpHandler(
        auth: _authentication,
        email: googleEmail,
      );
      handler = driveHandler;
      final cloudFiles = CloudFileService(
        email: googleEmail,
        client: driveHandler,
      );
      final keyData = await _readCloudKeyData(cloudFiles);
      final hasRegisteredDevices = await _hasRegisteredDevices(cloudFiles);

      if (keyData != null || hasRegisteredDevices) {
        final password = decryptionKey?.trim();
        if (password == null || password.isEmpty) {
          throw ArgumentError(
            'Inserisci la chiave di decifratura perché esistono dati cloud '
            'o altri dispositivi collegati.',
          );
        }

        keyManager = KeyManager(user: _user);
        await keyManager.init();
        final dataToValidate = keyData ?? await keyManager.exportKeyData();
        final decryptedKey = await keyManager.validateKeyData(
          password,
          dataToValidate,
        );
        if (decryptedKey == null) {
          throw ArgumentError(
            'La chiave inserita non è corretta per i dati crittografati.',
          );
        }

        if(!(await _userDatabase.isEmpty()) && !(await _cloudReader.isDriveEmpty())){
          throw StateError('Impossibile connettersi al cloud con dati già salvati da ambo le parti');
        }
        if (keyData != null &&
            !await keyManager.importKeyData(password, dataToValidate)) {
          throw StateError('Impossibile ripristinare la chiave crittografica.');
        }
      }

      // Persist the Google token and account association in one database transaction.
      await _authentication.persistAuthenticatedAccount(user: _user);
      _user.email = googleEmail;
    } finally {
      keyManager?.clearSession();
      handler?.close();
      await _cloudReader.dispose();
      await _systemDatabase.closeDatabase();
      await _userDatabase.closeDatabase();
    }
  }

  Future<Map<String, dynamic>?> _readCloudKeyData(
    CloudFileService cloudFiles,
  ) async {
    final folder = await cloudFiles.findFolderByName(
      _keyDirectory,
      parentFolderId: CloudFileService.appDataFolderId,
      spaces: 'appDataFolder',
    );
    if (folder == null) return null;

    final drive.File? keyFile = await cloudFiles.findByName(
      _keyFileName,
      folderId: folder.id,
      spaces: 'appDataFolder',
    );
    if (keyFile == null) return null;

    final keyData = await cloudFiles.readJson(keyFile.id!);
    final owner = keyData['username'];
    if (owner is! String || owner.isEmpty) {
      throw const FormatException(
        'Il file della chiave cloud non contiene un account Mira valido.',
      );
    }
    if (owner != _user.username) {
      throw StateError(
        'Lo spazio Google è già riservato all\'account Mira "$owner".',
      );
    }

    return keyData;
  }

  Future<bool> _hasRegisteredDevices(CloudFileService cloudFiles) async {
    final deviceFile = await cloudFiles.findByName(
      'device_register.json',
      spaces: CloudFileService.appDataFolderId,
    );
    if (deviceFile == null) return false;

    final fileId = deviceFile.id;
    if (fileId == null) {
      throw StateError('Il registro dispositivi cloud non contiene un id.');
    }

    final deviceData = await cloudFiles.readJson(fileId);
    final devices = deviceData['devices'];
    if (devices is! List) {
      throw const FormatException(
        'Il registro dispositivi cloud non contiene una lista valida.',
      );
    }

    for (final device in devices) {
      if (device is! Map) {
        throw const FormatException(
          'Il registro dispositivi cloud contiene un elemento non valido.',
        );
      }
    }

    return devices.isNotEmpty;
  }
}
