import 'dart:convert';
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
  CloudBackupReader? _cloudReader;
  final SystemDatabaseWrapper _systemDatabase;
  late final UserDatabaseWrapper _userDatabase;

  static const String _keyDirectory = 'crypto/';
  static const String _keyFileName = 'crypto_key.json';

  /// Creates a Google connection operation for the given local [user].
  GoogleAccountConnection(
    this._user,
    GoogleAuthenticationManager authentication, {
    UserDatabaseWrapper? systemDatabase,
  }) : _authentication = authentication,
       _systemDatabase = systemDatabase ?? SystemDatabaseWrapper() {
    _userDatabase = UserDatabaseWrapper(_user);
  }

  /// Connects Google, validates the cloud key, then persists the account.
  Future<void> execute([String? decryptionKey]) async {
    await _authentication.init();

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

      _cloudReader = CloudBackupReader(
        _user,
        authentication: _authentication,
        email: googleEmail,
      );
      await _cloudReader!.init();

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
      print(
        'Controllo passkey: crypto_key.json '
        '${keyData == null ? "assente" : "presente"}, '
        'dispositivi registrati '
        '${hasRegisteredDevices ? "presenti" : "assenti"}.',
      );

      if (keyData != null || hasRegisteredDevices) {
        final cloudDatabaseIsEmpty = await _cloudReader!.isDriveEmpty();
        print(
          'Controllo database cloud: '
          '${cloudDatabaseIsEmpty ? "vuoto" : "contiene file"}.',
        );
        print(
          keyData != null
              ? 'Richiesta passkey: trovato crypto_key.json su Drive.'
              : 'Richiesta passkey: crypto_key.json assente, ma il registro '
                    'indica dispositivi collegati; uso la chiave locale.',
        );
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
        if (keyData == null) {
          print(
            'File chiave cloud non trovato; verifico i dati della chiave locale.',
          );
        }
        final decryptedKey = await keyManager.validateKeyData(
          password,
          dataToValidate,
        );
        if (decryptedKey == null) {
          print(
            'Dati della chiave trovati, ma la verifica della decifratura è fallita.',
          );
          throw ArgumentError(
            'La chiave inserita non è corretta per i dati crittografati.',
          );
        }
        print('Dati della chiave crittografica verificati correttamente.');

        if (!(await _userDatabase.isEmpty()) && !cloudDatabaseIsEmpty) {
          throw StateError(
            'Impossibile connettersi al cloud con dati già salvati da ambo le parti',
          );
        }
        if (keyData != null) {
          final localKey = await keyManager.stringKey;
          if (localKey == null) {
            throw StateError(
              'La chiave crittografica locale non è disponibile.',
            );
          }

          final importedKey = base64Encode(decryptedKey);
          final requiresRekey = localKey != importedKey;
          if (requiresRekey) {
            await _userDatabase.rekeyEncryptionKey(importedKey);
          }

          try {
            if (!await keyManager.importKeyData(password, dataToValidate)) {
              throw StateError(
                'Impossibile ripristinare la chiave crittografica.',
              );
            }
          } catch (error) {
            if (requiresRekey) {
              try {
                await _userDatabase.rekeyEncryptionKey(localKey);
              } catch (rollbackError) {
                throw StateError(
                  'Il salvataggio della chiave cloud è fallito ($error) e '
                  'il ripristino della chiave precedente è fallito '
                  '($rollbackError). Il database è ancora aperto: non '
                  'chiudere l’app e contattare l’assistenza.',
                );
              }
            }
            rethrow;
          }
        }
      }

      // Persist the Google token and account association in one database transaction.
      await _authentication.persistAuthenticatedAccount(user: _user);
      _user.email = googleEmail;
    } finally {
      keyManager?.clearSession();
      handler?.close();
      await _cloudReader?.dispose();
      await _systemDatabase.closeDatabase();
      await _userDatabase.closeDatabase();
    }
  }

  Future<Map<String, dynamic>?> _readCloudKeyData(
    CloudFileService cloudFiles,
  ) async {
    print('Ricerca della cartella "$_keyDirectory" in Drive appDataFolder.');
    final folder = await cloudFiles.findFolderByName(
      _keyDirectory,
      parentFolderId: CloudFileService.appDataFolderId,
      spaces: 'appDataFolder',
    );
    if (folder == null) {
      print('Cartella Drive "$_keyDirectory" non trovata in appDataFolder.');
      return null;
    }
    print(
      'Cartella Drive "$_keyDirectory" trovata; ricerca del file '
      '"$_keyFileName".',
    );

    final drive.File? keyFile = await cloudFiles.findByName(
      _keyFileName,
      folderId: folder.id,
      spaces: 'appDataFolder',
    );
    if (keyFile == null) {
      print('File Drive "$_keyFileName" non trovato in "$_keyDirectory".');
      return null;
    }

    print('File Drive "$_keyFileName" trovato; lettura del contenuto JSON.');
    final keyData = await cloudFiles.readJson(keyFile.id!);
    print('File Drive "$_keyFileName" letto correttamente.');
    final owner = keyData['username'];
    if (owner is! String || owner.isEmpty) {
      throw const FormatException(
        'Il file della chiave cloud non contiene un account Mira valido.',
      );
    }
    if (owner != _user.username) {
      throw CloudAccountOwnershipException(owner);
    }

    return keyData;
  }

  Future<bool> _hasRegisteredDevices(CloudFileService cloudFiles) async {
    final deviceFile = await cloudFiles.findByName(
      'device_register.json',
      spaces: CloudFileService.appDataFolderId,
    );
    if (deviceFile == null) {
      print('Registro dispositivi device_register.json non trovato.');
      return false;
    }

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

    print(
      'Registro dispositivi trovato: ${devices.length} dispositivo/i '
      'registrato/i.',
    );
    return devices.isNotEmpty;
  }
}

/// Indicates that the selected Google Drive contains data owned by another
/// Mira account.
class CloudAccountOwnershipException implements Exception {
  final String ownerUsername;

  const CloudAccountOwnershipException(this.ownerUsername);

  @override
  String toString() =>
      'Lo spazio Google è già riservato all\'account Mira "$ownerUsername".';
}
