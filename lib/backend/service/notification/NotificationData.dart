/// Simple class to handle notification data
class NotificationData {
  /* define attributes */
  String title;
  String text;
  String? payload;

  /// Define the constructor for the notification data
  NotificationData(this.title, this.text, {this.payload});

  /// Function to increase the title of the notification
  /// * [title] new string to add
  /// * [position] if it's TRUE the new string comes before, otherwise it is added after
  void increaseTitle(String title, bool position){
    if(position){
      this.title = title + this.title;
    } else {
      this.title = this.title + title;
    }
  }

  /// Function to increase the text of the notification
  /// * [text] new string to add
  /// * [position] if it's TRUE the new string comes before, otherwise it is added after
  void increaseText(String text, bool position){
    if(position){
      this.text = text + this.text;
    } else {
      this.text = this.text + text;
    }
  }
}