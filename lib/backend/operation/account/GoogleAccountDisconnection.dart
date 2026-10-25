import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudBackupCleaner.dart';
import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Disconnects a user's Google backup account and reports any cloud cleanup
/// or Google sign-out failures that do not prevent local disconnection.
class GoogleAccountDisconnection {
  final User _user;

  /// Creates the operation for the specified local user.
  GoogleAccountDisconnection(this._user);

  /// Removes the Google association locally and cleans cloud data when possible.
  Future<GoogleAccountDisconnectionResult> execute() async {
    final email = _user.email;
    if (email.isEmpty) {
      throw StateError('Nessun account Google è associato a questo utente.');
    }

    final authentication = GoogleAuthenticationManager();
    CloudBackupCleaner? cleaner;
    var authenticationInitialized = false;
    var cloudDataDeleted = false;
    var cloudDataRetained = false;
    String? cloudCleanupError;
    String? signOutError;

    try {
      await authentication.init();
      authenticationInitialized = true;

      if (!await authentication.restoreAccount(email)) {
        throw StateError('La sessione Google non è presente nel database.');
      }

      cleaner = CloudBackupCleaner(_user, authentication: authentication);
      await cleaner.init();
      cloudDataDeleted = await cleaner.clean();
      cloudDataRetained = !cloudDataDeleted;
    } catch (error) {
      cloudCleanupError = error.toString();
    } finally {
      if (cleaner != null) {
        try {
          await cleaner.dispose();
        } catch (error) {
          cloudCleanupError ??= error.toString();
        }
      }

      if (authenticationInitialized) {
        try {
          await authentication.signOut(email: email);
        } catch (error) {
          signOutError = error.toString();
        }
      }

      try {
        await authentication.close();
      } catch (error) {
        signOutError ??= error.toString();
      }
    }

    final database = SystemDatabaseWrapper();
    await database.init();
    try {
      await database.removeUserEmail(_user);

      final session = await CurrentSession.getFromMemory();
      if (session == null || session.user.username != _user.username) {
        throw StateError('La sessione dell’utente non è disponibile.');
      }

      session.user.eraseEmail();
      await session.saveUser();
      _user.eraseEmail();
    } finally {
      await database.closeDatabase();
    }

    return GoogleAccountDisconnectionResult(
      cloudDataDeleted: cloudDataDeleted,
      cloudDataRetained: cloudDataRetained,
      cloudCleanupError: cloudCleanupError,
      signOutError: signOutError,
    );
  }
}

/// Describes the result of disconnecting Google and any incomplete cleanup.
class GoogleAccountDisconnectionResult {
  /// Whether the cloud backup data was deleted.
  final bool cloudDataDeleted;

  /// Whether cloud data was kept because other devices are registered.
  final bool cloudDataRetained;

  /// Error encountered while trying to clean up cloud data.
  final String? cloudCleanupError;

  /// Error encountered while signing out or closing Google authentication.
  final String? signOutError;

  /// Creates a result for a Google account disconnection.
  const GoogleAccountDisconnectionResult({
    required this.cloudDataDeleted,
    required this.cloudDataRetained,
    required this.cloudCleanupError,
    required this.signOutError,
  });

  /// Message to show after the local Google association has been removed.
  String get message {
    final details = <String>['Account Google disconnesso.'];
    if (cloudDataDeleted) {
      details.add('I dati cloud sono stati eliminati.');
    } else if (cloudDataRetained) {
      details.add(
        'I dati cloud sono stati mantenuti perché risultano registrati '
        'altri dispositivi.',
      );
    } else if (cloudCleanupError != null) {
      details.add(
        'Non è stato possibile pulire i dati cloud: $cloudCleanupError',
      );
    }

    if (signOutError != null) {
      details.add(
        'Non è stato possibile completare la disconnessione Google: '
        '$signOutError',
      );
    }
    return details.join('\n\n');
  }
}
