# Requirement analysis

## Introduction of the problem
Controlling our financial situation is important, but it is not a given that our banking app does so. Maybe it can offer a list of movements and transactions, but not every one of them shows interactive charts about incomes and outgoings, to give the customer a better view of their net worth. 
Moreover, the customer could have different accounts belonging to different banks and financial institutes and, as a result, it is impossible to have a broader view of the total resources owned. 
**Mira Finance Tracker** offers customers a new way of managing bank accounts and transactions, with interactive charts all together.

The application will be developed to be available on every platform and synchronized between different devices. 

*This application is only meant to register and control bank transactions of different types and can't replace the original application used to make these transactions.*
*Besides, the application is not connected to the bank account and requires the user to register the transactions manually, sometimes with automatic calculation.*


## How bank account works
To develop this application, a knowledge base of how a bank account works is required, together with the functionalities it has that should be replicated in this project.
This section will cover all the different aspects of a bank account. 

### Bank account
A bank account is a financial arrangement between a customer and a bank that allows the customer to deposit, withdraw, and manage their money, track financial transactions, and access various banking services.
So, it should track:
- **Fees** from the bank; there could be more than one
- **CashBack** from the bank, because of different services
- **Interest** if available, for simply leaving the money in the bank account.
- **Amount of money** to save, spend or invest

A bank account should also be able to track transfers of money between different bank accounts. 
Within the bank account we can find different types:

#### Current Account
An account used mostly for direct transfers and various operations with money. 
A current account, in addition to the functions of a normal bank account, should consider:
- **Incomes** occasional payments to the bank account
- **Outgoings** occasional payments from the bank account
- **Domiciliation** periodic outgoing, for example a payment for a service. 
- **Periodic Income** for example the salary.

#### Savings account
An account used to save money and invest it in the ways suggested by the bank or the institutes, in addition to the operations available on a bank account. 

#### Payment card
In addition to the functions available on a bank account, it should focus more on payments, incomes and cashback from individual payments. 
**The application should allow the user to manage both debit/prepaid and credit cards**. 

### Financial instruments
The different bank accounts, especially those for savings, should consider the different financial instruments available to the user.
Here are some of the most common tools to integrate. 

#### Time deposits
Interest is calculated after a specified time on the invested amount of money. 
When part or the whole of the deposit is withdrawn before the expiration date, the interest gathered should be lost, reduced to a lower percentage, or calculated on the remaining sum. 
*Examples of time deposits are "Offerte Supersmart" of the PosteItaliane institute.*

#### Bonds 
They can be government bonds or bonds from the financial institute where the user has the account. 
A bond generates periodic earnings based on the specified sum. 
When the sum is withdrawn, the bond is sold at the current market value, plus the interest earned from the last coupon until the day of withdrawal. 
*Examples of bonds are the BTP of the Italian CDP institute.*

#### Stocks
A stock is the most common way of investing money. 
In this case a sum is invested, even for an unspecified time, and the sum earned is calculated when the capital, or part of it, has been sold. 
The possibility of registering dividends distributed by the company the user is investing in should also be considered. 
*Stocks belong to every business, such as Amazon.*

## Functionalities required
Looking at how different bank accounts work, here are some requirements to follow for the implementation of the application:

### Bank account
- Ensure all the different types of bank accounts illustrated
- Ensure the basic income / outgoing operations
- Manage periodic fees, even in the different transaction types
- Ensure dynamic money transfers between different bank accounts with the connected fees

### Other entities
- Manage different financial institutes
- Make the government bonds accessible to every bank account
- Also record the receiver and sender of transfers

### Financial instruments
- Ensure all the different types of instruments
- Dynamically calculate interest
- Consider the different fees
- Make instruments from a financial institute available only to the corresponding bank accounts

### Frontend requirements
- Show charts to display incomes, outgoings and investments
- Save the history of the bank accounts, including past years, allowing the user to read and compare it, even if the bank account is no longer active

### Security requirements
- Use an account to log in to the application
- Provide an additional means of access and unlocking for the application, using the authentication method of the device
- Keep data confidential
- Allow online backup to make the data available to the other devices and software of the same user