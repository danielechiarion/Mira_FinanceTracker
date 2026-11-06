# Software requirements
The software requirements mainly involve the cloud implementation, because some Google APIs have to be enabled in order to make the application work.
For that reason, it will be explained how to configure them and how to give the information to the application. 
This information is useful only if you want to replicate the project and develop it. A basic user just needs to follow the user guide.

## Configure the Google Cloud Console
Access the [Google Cloud Console page](https://console.cloud.google.com/home) with your Google Account. Create a project (a free account will support a maximum of 10 projects) and configure the Google Drive API with a private Google Drive folder as scope.
Then it will be necessary to configure different cloud APIs based on the platform:
- **Android Client API**
- **Linux Client API**
- **Desktop Client API** working for both Windows and Linux application instances
- **Web Client API** (it could also be used inside a mobile environment).

These settings will not save the application data of all the users inside the Google Account owning the Cloud Console. This platform has to be considered a "gateway" to enable Google authentication and to have the right permissions to access the user's private drive once the application is installed.

## File to be implemented
The main file to use for the cloud backup implementation has to be located at the path `assets/data/credentials.json`, starting from the root of the Flutter project. 
The file has to follow this structure:
```json
{
    "desktop_client_id": "",
    "desktop_client_secret": "",
    "android_client_id": "",
    "android_client_secret": "",
    "ios_client_id": "",
    "ios_client_secret": "",
    "web_client_id": "",
    "web_client_secret": ""
}
```
Copy the values of the corresponding fields found in the Google Cloud Console.
***Consider that not all the platforms need both client ID and secret. As an example, Android needs only the client ID, while a web or desktop client could need both. For more information, follow the guidelines provided inside the Google Cloud Console***.


*Once this configuration is finished, it will be possible to test the Flutter project and generate new executable files for the needed platforms*.