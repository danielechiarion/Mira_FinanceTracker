import 'package:meta/meta.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/KeyManager.dart';
import 'package:mira_finance_tracker/backend/service/preference/UserPreferences.dart';

import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAuthenticationManager.dart';
import 'package:mira_finance_tracker/backend/cloud/connection/DriveHttpHandler.dart';
import 'package:mira_finance_tracker/backend/cloud/file/CloudFileService.dart';

abstract class CloudBackup {
  /* define attributes for the writer */
  late DriveHttpHandler _handler;
  GoogleAuthenticationManager _authenticationManager;
  late CloudFileService _fileService;
  UserDatabaseWrapper _database;
  UserPreferences _userPreferences;
  KeyManager _keyManager;
  String _email;

  /* boolean to understand if resources 
  have been given in input or created inside the instance */
  late bool _givenAuthentication;
  late bool _givenHandler;

  /* define constants for folders 
  inside the drive space reserved */
  static final String _DATABASEDIRECTORY = "database/";
  static final String _PREFERENCEDIRECTORY = "preference/";
  static final String _KEYDIRECTORY = "crypto/";

  /* define constants for files to be
  named inside the drive space reserved */
  static final String _CRYPTOFILENAME = "crypto_key.json";
  static final String _PREFERENCEFILENAME = "preferences.json";
  static final String _COUNTERPARTIESFILENAME = "counter_parties.json";
  static final String _FINANCIALINSTITUTESFILENAME = "financial_institutes.json";
  static final String _BANKACCOUNTSFILENAME = "bank_accounts.json";
  static final String _TRANSACTIONSFILENAME = "transactions.json";
  static final String _BILLINGSFILENAME = "billings.json";
  static final String _PERIODICTRANSACTIONSFILENAME = "periodic_transactions.json";
  static final String _FINANCIALMODELSFILENAME = "financial_models.json";
  static final String _FINANCIALINSTRUMENTSFILENAME = "financial_instruments.json";
  static final String _STEPINTERESTSFILENAME = "step_interests.json";

  /// Function to initialize general cloud backup handler
  /// with all the essential attributes
  /// * [user] user to make the backup for
  /// * [authentication] (optional) authentication manager for Google
  /// * [handler] (optional) handler for HTTP requests to Drive
  /// Then all the other attributes are instanced, then initialize them. 
  CloudBackup(User user, {GoogleAuthenticationManager? authentication, DriveHttpHandler? handler}):
    _authenticationManager = authentication ?? GoogleAuthenticationManager(),
    _email = user.email,
    _database = UserDatabaseWrapper(user),
    _userPreferences = UserPreferences(user),
    _keyManager = KeyManager(user: user) {
      /* first initialize handler and 
      cloud file service */
      _handler = handler ?? DriveHttpHandler(auth: _authenticationManager, email: user.email);
      _fileService = CloudFileService(email: user.email, client: _handler);

      /* understand if the authentication and handler
      is given or not */
      _givenAuthentication = authentication != null;
      _givenHandler = handler != null;
  }

  /// Function to initialize resources of the cloud backup
  /// in order to make it operative
  Future<void> init() async {
    /* restore authentication if it's given */
    if(!_givenAuthentication){
      await _authenticationManager.init();
      await _authenticationManager.restoreAccount(_email);
    }
    
    /* initialize database, preference
    and all the other resources */
    await _database.init();
    await _userPreferences.init();
    await _keyManager.init();
  }

  /// Abstract function to execute the interaction with cloud, 
  /// whether it's saving or reading from it
  Future<void> execute();

  /// Function to dipose the resources used inside
  /// the cloud backup instance
  Future<void> dispose() async {
    if(!_givenHandler) _handler.close();
    await _database.closeDatabase();
  }

  /* *** GETTER METHODS ***
  for file paths and directories */
  @protected
  String get DATABASEDIRECTORY => _DATABASEDIRECTORY;
  @protected
  String get PREFERENCEDIRECTORY => _PREFERENCEDIRECTORY;
  @protected
  String get KEYDIRECTORY => _KEYDIRECTORY;
  @protected
  String get COUNTERPARTIESFILENAME => _COUNTERPARTIESFILENAME;
  @protected
  String get FINANCIALINSTITUTESFILENAME => _FINANCIALINSTITUTESFILENAME;
  @protected
  String get BANKACCOUNTSFILENAME => _BANKACCOUNTSFILENAME;
  @protected
  String get TRANSACTIONSFILENAME => _TRANSACTIONSFILENAME;
  @protected
  String get BILLINGSFILENAME => _BILLINGSFILENAME;
  @protected
  String get PERIODICTRANSACTIONSFILENAME => _PERIODICTRANSACTIONSFILENAME;
  @protected
  String get FINANCIALMODELSFILENAME => _FINANCIALMODELSFILENAME;
  @protected
  String get FINANCIALINSTRUMENTSFILENAME => _FINANCIALINSTRUMENTSFILENAME;
  @protected
  String get STEPINTERESTSFILENAME => _STEPINTERESTSFILENAME;
  @protected
  String get CRYPTOFILENAME => _CRYPTOFILENAME;
  @protected
  String get PREFERENCEFILENAME => _PREFERENCEFILENAME;

  /* *** GETTER METHODS ***
  of resources to pass to subclasses */
  @protected
  UserDatabaseWrapper get database => _database;
  @protected
  CloudFileService get fileService => _fileService;
  @protected
  KeyManager get keyManager => _keyManager;
  @protected 
  UserPreferences get userPreferences => _userPreferences;
  @protected
  GoogleAuthenticationManager get authenticationManager => _authenticationManager;
  @protected
  bool get givenAuthentication => _givenAuthentication;
  @protected
  bool get givenHandler => _givenHandler;
  @protected
  String get email => _email;
}