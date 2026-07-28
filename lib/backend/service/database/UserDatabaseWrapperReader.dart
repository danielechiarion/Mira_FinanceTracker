part of 'UserDatabaseWrapper.dart';

extension UserDatabaseWrapperReader on UserDatabaseWrapper{
  /// Function to read user preferences and return
  /// them with the objects provided by the application
  /// 
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<SinglePreference>> readUserPreferences({bool close = false}) async{
    List<Map<String, dynamic>> result = await appDatabase.query(sql: 'SELECT name,value FROM application_preferences');

    /* create the list and cycle all the results to
    get the list of preferences */
    List<SinglePreference> userPreferences = [];
    for(Map<String, dynamic> map in result){
      userPreferences.add(SinglePreference.fromSharedPreference(map['name'], map['value']));
    }

    if(close){
      await appDatabase.close();
    }

    return userPreferences;
  }
}