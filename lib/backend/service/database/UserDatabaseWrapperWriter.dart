part of 'UserDatabaseWrapper.dart';

extension UserDatabaseWrapperWriter on UserDatabaseWrapper{
  /// Function to save user preferences inside the database
  /// * [preferences] preferences to be saved
  /// * [close] flag to indicated if the database has to be closed at the end of the operations
  Future<void> saveUserPreferences(List<SinglePreference> preferences, {bool close = false}) async {
    /* because we don't know if some elements previously saved
    have been removed from the list, clear the table */
    await appDatabase.query(sql: 'DELETE FROM application_preferences');

    /* then add the single preferences 
    inside the database */
    for(SinglePreference preference in preferences){
      await appDatabase.query(sql: 'INSERT INTO application_preferences (name, value) VALUES (?,?)',
                              arguments: [preference.name, preference.toMapEntry().value]);
    }
  }
}