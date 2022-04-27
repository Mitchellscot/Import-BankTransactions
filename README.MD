# Bank Transaction Importing Tool

## Overview
This script imports data from CSV files downloaded from My Bank and Credit Card company into a Databse for review. The script attempts to autocatogorize the merchant, income source, and category id for each transaction based on a set of rules stored in a database.

Import-Transactions.ps1 is the entry point of the application.

## How to use the script:

#### Basic order of script execution
1. Get all data from two CSV files exported from my bank or credit card website
2. Compare that data with what is in the database already, only return those that are not already in the DB
3. Attempt to assign Merchant, Income Source, and Categories to all transactions
4. Insert the transactions into a special table in the database to be reviewed in the CashTrack app

#### Extended Notes

1. You need to create a file named connection-string and copy the db connection string to that. It is not checked into source control.
2. Log onto Bank website and export the list of transactions. This goes to your downloads folder and is labeled "Exported Transactions.csv". If you switch banks, you will have to edit the script.
3. Log on to Credit card website and download a csv of the latest transactions. If you download the latest, the file name will be "Since Jan 14th" or whatever month it is. This is not good for importing, so there is a function to rename the file in File-Helpers called `Find-CreditCardFileName`. Update this if you switch credit card companies.
4. It's important to know that the way the script determines if a transaction is "new" is if there are entries in the database that have the exact same date and amount. This means if you have multiple purchase on the same date with the same price then it would consider these duplicates and only return ONE! In the 10 years I have been tracking expenses I have never seen this happen, aside from maybe at Costco Food Court where I might have several hotdogs costing $1.61 on the same date. Just try to avoid this as much as you can as this check is made all over the application.
5. There are addtional functions that contain bank and credit card specific logic that have to do with formatting the notes of the transaction. Two functions remove transactions I'm simply not interested in keeping track of, and two others work to format the expense notes. There is a lot of code to format the notes, and if you ever **change banks or credit cards** you have to update the logic in these functions, as well as probably a lot of the script (maybe the functions that get data from the csv file, the column names will most likely be differet i.e. "transaction Notes" instead of "Description"). There is not a lot of logic here so it would not be that dificult. Wherever you go, you will have a transaction date, amount, and notes so no matter what I think this script would work with any institution you use. However if you need to change these in the future, they are located here:  
- `Remove-UnnecessaryBankExpenses`  
- `Remove-UnnecessaryCreditIncome`  
- `Format-ExpenseNotes`  
- `Format-IncomeNotes`  
6. If you want to execute script from a shortcut, right click on the desktop and add new shortcut on the desktop and under "Type the location of the item" insert this line:  
``#powershell.exe -nologo -windowstyle hidden -ExecutionPolicy Bypass -File $HOME\Code\CashTrack\Import-BankTransactions\Import-Transactions.ps1``
7. The two insert statements that put data in the database are surounded by try-catch statements that outputs the error and the sql command to console AND to a errors.txt on the desktop. To debug, just take this statement and try to execute it on the database to see what is going on. I have had errors were an unapproved character tried to make it's way into the database. If you get a unique character the DB doesn't like, you have to add the character to function `Format-TextAsReadable` at the bottom of Csv-Helpers.psm1. This is because Database exceptions aren't shown in Powershell so you have to go to Azure Data studio or whatever, execute the query exactly as it's displayed in the error, and see what it has to say about it.
8. DateTimeOffSet MUST be set to the same timezone as the server that runs the main app and likely the timezone I am in. This is enforced in the Transaction-Class.psm1 in the constructor to be -6 (central time zone, Minnesota). If the offset is different in the DB. it will cause a lot of bugs in the application as equality is checked on the date sometimes. Pain in the ass.
9. When the script checks to see if the transaction is already in the database it first determines what the oldest transaction is, and then runs a query to get all transactions since that date. So if you have a csv of bank transactions going back 10 days, it will only check the transactions in the DB for the past ten days and then compare what is in the csv to that. This is a cool feature, I'm pretty proud of it.
10. Two commands to export transactions to csv, to use for debugging if you want:  
``$UpdatedExpenses | Sort-Object -Property Date -Descending| export-csv -Path "$HOME/Desktop/new-expenses.csv"``  
``$UpdatedIncome | Sort-Object -Property Notes | export-csv -Path "$HOME/Desktop/new-income.csv"``
