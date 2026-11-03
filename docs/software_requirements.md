# Software requirements
The software requirements involves especially the cloud implementation, because there has to be some Google API to be enabled in order to make the application work.
For that reason it will be explained how to configure it and how give the information to the application. 
This information are useful only if you want to replicate the project and develop it. A basic user just need to follow the user guide.

## Configure the Google Cloud Console
Access to the [Google Cloud Console page](https://console.cloud.google.com/home) with your Google Account. Create a project (a free account will support a maximum of 10 projects) and configure the Google Drive API with a private google drive folder as scope.
Then it will be necessary to configure different cloud API based on the platform:
- **Android Client API**
- **Linux Client API**
- **Desktop Client API** working for both Windows and Linux application instances
- **Web Client API** (it could be used even inside a mobile environment).

This settings will not save the application data of all the users inside the Google Account owning the Cloud Console. This platform has to be consider as a "gateway" to enable google authentication and to have the right permissions to access to the private drive of the user once installing the application. 

## File to be implemented
The main file to use for the cloud backup implementation has to be located with path `assets/data/credentials.json`, starting from the root of the Flutter project. 
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
Copying in the values the corresponding fields found in the Google Cloud Console.
***Consider that not all the platforms needs both client id and secret. As an example, Android needs only the client ID, while a web or desktop client could need both. For more information follow the guidelines provided inside the Google Cloud Console***.


*Once finished this configuration, it will be possible to test the Flutter project and generate new executable files for the platforms needed*.