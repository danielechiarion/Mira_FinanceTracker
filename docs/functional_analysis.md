# Functional analysis
This relation talks about how the application should work and what are the functionalities ensured according to the requirement analysis agreed before.

## Structure of the application pages
The application will contains several pages due to the various functionalities the application covers.  
The main pages of the program will be:
- **REVIEW** page with a summary of incomes, outcomes and charts. 
- **CUSTOM CHECK** controls the situation of the bank accounts selected on a specified amount of time. 
- **ACTION PAGES** allow the person to add different things on the application, such as payments, incomes, outcomes etc.
- **SETTINGS** regarding the account and personal customizations.

### Access page
The application should consider the possibility to access with more than one account. 
The starting page, if the user is not logged in, offers the following possibilities:
- **CREATE A NEW ACCOUNT** if the user is new on the local application
- **LOGIN** for already existing users on the local application
- **MANAGE ACCOUNTS** to delete previous accounts not used. This display will be accessible only using the passocode of the device used. 

*After the login, the application should propose the possibility to syncronize information with Google in order to use data with different devices.*

### Specific subpages
In the application there will be also specific subpages in order to display better details.
The main classification of subpages in the application will be:
- **REVIEW SUBPAGES** to display better the situation of each bank account, with all charts and movements connected to it. 
- **ADDING SUBPAGES** will be used to add new things to the bank account, such as incomes, outcomes etc.


## Adding actions allowed
In the software the user will be free to add different entities useful for his finance tracker. 
The entities he is allowed to add are:
- **Bank accounts** of all the types
- **Financial institutes** to distiguish the variety of bank accounts and products offered. 
- **Operations** such as payments, incomes and subscriptions to investment offers. 
- **Financial instruments** offered by each financial institues typed.

***The possibility of viewing all data previously added is ensured in this page.***

*The possibility to change what has been added will be done when accessing to the subpages of the review page.*

## Settings configured by the user
The page of the settings will contain all the preferences editable by the user.
The categories of things to be changed will be the following ones:

### Account settings
The data the user can change its:
- **username** if it's unique inside the local application
- **password** by knowing the old one or entering in administrator mode (using the unlocking mode of the device)

*This data will be saved just locally and encripted with a private key of the application.*

### Application settings
The settings user can configure in this sessions are:
- **Background activity** the user can decide whether activating it or not in order to check things periodically (monthly incomes, outcomes, reviews etc.). ***If the user disables this functionality the automatic calculation of periodic incomes and domiciliation will be disabled as well and the user will have to add this information manually.***
- **Notification** the background activity could produce some notifications to inform the user about the monthly review of the bank accounts or some other period payments to do. Disabling these functionalities won't impact on the perfomance and the automatic calculation on the application background. 
- **Changing period** this setting will let the application know on how much period the application can allow the user to make changes backwards and in which time window the application will use incremental backups. This functionality is important if, on new application, you want to keep an archive or just control the latest movements.

### Cloud settings
The application is planned to support cloud-based backup and syncronization between multiple devices. 
The user will have the chance to access to the account google or remove it whenever it's necessary.
**When removing the account everythings saved on cloud should be removed, when it's not used by other users.**

The cloud application should display errors of connection and data reading, and still let the user interact with local data saved. 

**Be careful when implementing the cloud backup between users, because they should crypted in the same way and merge the changes between different application instances.**

In the settings page the application should show:
- **Google Account connection** if the user has implemented the account connection
- **User passkey** show the user passkey chose by the user in order to recover data in other devices.