# Functional analysis
This report describes how the application should work and which functionalities are ensured, according to the requirement analysis agreed on previously.

## Structure of the application pages
The application will contain several pages because of the various functionalities it covers.  
The main pages of the program will be:
- **REVIEW** page with a summary of incomes, outgoings and charts. 
- **CUSTOM CHECK** controls the situation of the selected bank accounts over a specified amount of time. 
- **ACTION PAGES** allow the person to add different things to the application, such as payments, incomes, outgoings etc.
- **SETTINGS** regarding the account and personal customizations.

### Access page
The application should consider the possibility of accessing with more than one account. 
The starting page, if the user is not logged in, offers the following possibilities:
- **CREATE A NEW ACCOUNT** if the user is new to the local application
- **LOGIN** for users who already exist on the local application
- **MANAGE ACCOUNTS** to delete previous accounts that are no longer used. This display will be accessible only by using the passcode of the device used. 

*After the login, the application should propose the possibility to synchronize information with Google in order to use data on different devices.*

### Specific subpages
In the application there will also be specific subpages in order to display details better.
The main classification of subpages in the application will be:
- **REVIEW SUBPAGES** to better display the situation of each bank account, with all the charts and movements connected to it. 
- **ADDING SUBPAGES** will be used to add new things to the bank account, such as incomes, outgoings etc.


## Adding actions allowed
In the software the user will be free to add different entities useful for their finance tracker. 
The entities they are allowed to add are:
- **Bank accounts** of all types
- **Financial institutes** to distinguish the variety of bank accounts and products offered. 
- **Operations** such as payments, incomes and subscriptions to investment offers. 
- **Financial instruments** offered by each financial institute.

***The possibility of viewing all the data previously added is ensured on this page.***

*Changing what has been added will be possible by accessing the subpages of the review page.*

## Settings configured by the user
The settings page will contain all the preferences editable by the user.
The categories of settings that can be changed are the following:

### Account settings
The data the user can change are:
- **username** if it is unique inside the local application
- **password** by knowing the old one or by entering administrator mode (using the unlocking mode of the device)

*This data will be saved only locally and encrypted with a private key of the application.*

### Application settings
The settings the user can configure in this section are:
- **Background activity** the user can decide whether to activate it or not in order to check things periodically (monthly incomes, outgoings, reviews etc.). ***If the user disables this functionality, the automatic calculation of periodic incomes and domiciliations will be disabled as well and the user will have to add this information manually.***
- **Notification** the background activity can produce some notifications to inform the user about the monthly review of the bank accounts or about other periodic payments to be made. Disabling these functionalities won't impact the performance and the automatic calculations in the application background. 
- **Changing period** this setting will let the application know how far back the user is allowed to make changes and in which time window the application will use incremental backups. This functionality is important if, on a new application, you want to keep an archive or just check the latest movements.

### Cloud settings
The application is planned to support cloud-based backup and synchronization between multiple devices. 
The user will have the chance to access the Google account or remove it whenever necessary.
**When the account is removed, everything saved on the cloud should be removed, if it is not used by other users.**

The cloud application should display errors in connection and data reading, and still let the user interact with the locally saved data. 

**Be careful when implementing the cloud backup between users, because data should be encrypted in the same way and the changes should be merged between different application instances.**

On the settings page the application should show:
- **Google Account connection** if the user has set up the account connection
- **User passkey** shows the passkey chosen by the user in order to recover data on other devices.