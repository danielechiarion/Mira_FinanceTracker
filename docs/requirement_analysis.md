# Requirement analysis

## Introduction of the problem
Controlling our financial situation is important, but it's not taken for granted that our banking app does so. Maybe it can offer a list of movements and transaction, but not everyone of them shows interactive charts about incomes and outcomes, to give the customer a better view of his net worth. 
Moreover, the customer could have different accounts belonging to different banks and financial institues and, as result, it's impossible to have a wider prospect of the total resources owned. 
**Mira Finance Tracker** offers the customers a new way of managing banking accounts and transactions, with interactive charts all together.

The application will be developed in order to be available on every platform and syncronized between different devices. 

*This application is just to register and control bank transactions of different types and can't replace the original application to make these transaction.*
*Besides, the application is not connected to the bank account and requires the effort of the user to register the transactions manually, sometimes with automatic calculation.*


## How bank account works
To develop this application it is required a knowledge base of how a bank account works with the functionalities it has that should be replicated in this project.
This section will cover all the different aspects of a bank account. 

### Bank account
A bank account is a financial arrangement between a customer and a bank that allows the customer to deposit, withdraw, and manage their money, track financial transactions, and access various banking services.
So, it should track:
- **Fees** from the bank, could be more than one
- **CashBack** from the bank, because of different services
- **Interests** if available, for just letting the money on the bank account.
- **Amount of money** to save, spend or invest

A bank account should also been able to track transfers of money between different bank accounts. 
Inside the bank account we could find different types:

#### Current Account
Account used mostly for direct transfers and various operations with money. 
A current account, in addition to the functions of a normal bank account, should consider:
- **Incomes** occasional payments to the bank account
- **Outcomes** occasional payments from the bank account
- **Domiciliation** periodic outcome, for example a payment of a service. 
- **Periodic Income** for example the salary.

#### Savings account
Used to save money and invest them in the ways suggested by the bank or the institutes, in additions to the operations available on a bank account. 

#### Payment card
In addition to the functions available on a bank account, it should focus more on payments, incomes and cashback from the single payments.
**The application should allow the user to manage both debit/prepaid and credit card**. 

### Financial instruments
The different bank accounts, especially the one for savings, should consider the different financial instruments available for the user.
Here are reported some of the most common tools to integrate. 

#### Time deposits
The interests are calculated after a specified time on the invested amount of money. 
When a part or the whole deposited is retired after the expiration date, the interested gathered should be loss or a lower percentage, or the interests calculated on the remaining sum. 
*Examples of time deposits are "Offerte Supersmart" of PosteItaliane institute.*

#### Bonds 
Could be government ones or from the financial institute the user has the account. 
A bond generates a periodic earning based on the specified sum. 
When the sum is retired, it's sold using the current value of the market, plus an interest earned from the last coupon till the day of the retirement. 
*Examples of bonds are BTP of CDP Italian institute.*

#### Stocks
A stock is the most commong way of investing money. 
In this case a sum is invested even for an unspecified time, and the sum earned is calculated when the capital or part of it has been sold.
It should be considered also the possibility to register shared dividend by the company whose the user is investing in. 
*Stocks belongs to every business, such as the one of Amazon's.*

## Functionalities required
Looking at how different bank account works, here are some requisites to follow for the execution of the application:

### Bank account
- Ensure all the different types of bank account illustrated
- Ensure the basic income / outcome operation
- Manage periodic fees even in the different transaction type
- Ensure dynamic money transfer between different bank accounts with the connected fees

### Other entities
- Manage different finantial institutes
- Make the governement bonds accessible for every bank account
- Record also receiver and sender of transfers

### Financial instruments
- Ensure all the different types of instruments
- Calculated dinamically interersts
- Consider the different fees
- Make instruments from a financial institute avaible only for the corresponding bank accounts

### Frontend requirements
- Show charts to display incomes, outcomes and investments
- Save the story of the bank accounts even of the past years making the user able to read it and compare it, even if the back account is not active anymore

### Security requirements
- Use an account to login into the application
- Provide an additional access and unlock of the application with the authentication method of the device
- Keep data confidential
- Allow backup online to make the data avilable for the other devices and softwares of the same user