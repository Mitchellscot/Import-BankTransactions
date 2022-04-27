using module ".\Transaction-Class.psm1"
using namespace System.Collections.Generic
using namespace System.Linq
$setup = Test-Path -Path ".\connection-string"
if(!$setup) {
    write-host "Please create a file named 'connection-string' with the connection string in it."
    exit
}
import-module .\Csv-Helpers.psm1
import-module .\Database-Helpers.psm1
import-module .\File-Helpers.psm1
import-module .\Transaction-Class.psm1

[CsvFilesExist]$dataFiles = Find-BankAndCreditCsvFiles
[List[ExpenseTransaction]]$ExpenseList = Get-ExpensesFromCsv -ExistingFiles $dataFiles
[List[IncomeTransaction]]$IncomeList = Get-IncomeFromCsv -ExistingFiles $dataFiles

[List[ExpenseTransaction]]$NewExpenses = Get-ExpensesNotInDatabase -ExpenseList $ExpenseList
[List[IncomeTransaction]]$NewIncome = Get-IncomeNotInDatabase -IncomeList $IncomeList

[List[ExpenseTransaction]]$UpdatedExpenses = Set-MerchantsAndCategories -ExpenseList $NewExpenses
[List[IncomeTransaction]]$UpdatedIncome = Set-SourcesAndCategories -IncomeList $NewIncome

Add-ExpensesIntoDatabase -Expenses $UpdatedExpenses
Add-IncomeIntoDatabase -Income $UpdatedIncome

#Remove-Files