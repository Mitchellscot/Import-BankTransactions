using namespace System.Collections.Generic
using namespace System.Linq
using namespace System.Globalization
using module ".\Transaction-Class.psm1"

function Get-Income{
	param(
		[string]$BankFilePath,
		[string]$CCFilePath,
		[switch]$BankOnly,
		[switch]$CCOnly
		)
		$Income = New-Object List[IncomeTransaction]
		if($BankOnly -and !$CCOnly){
			[List[IncomeTransaction]]$bankTransactions = Get-BankIncome($BankFilePath)
			$Income.AddRange($bankTransactions)
		}
		elseif($CCOnly -and !$BankOnly){
			[List[IncomeTransaction]]$creditTransactions = Get-CreditCardIncome($CCFilePath)
			$Income.AddRange($creditTransactions)
		}
		else{
			[List[IncomeTransaction]]$bankTransactions = Get-BankIncome($BankFilePath)
			$Income.AddRange($bankTransactions)
			[List[IncomeTransaction]]$creditTransactions = Get-CreditCardIncome($CCFilePath)
			$Income.AddRange($creditTransactions)
		}
		return $Income
}
function Get-Expenses{
	param(
		[string]$BankFilePath,
		[string]$CCFilePath,
		[switch]$BankOnly,
		[switch]$CCOnly
		)
	$Expenses = New-Object List[ExpenseTransaction]
	if($BankOnly -and !$CCOnly){
		[List[ExpenseTransaction]]$bankTransactions = Get-BankExpenses($BankFilePath)
		$Expenses.AddRange($bankTransactions)
	}
	elseif($CCOnly -and !$BankOnly){
		[List[ExpenseTransaction]]$creditTransactions = Get-CreditCardExpenses($CCFilePath)
		$Expenses.AddRange($creditTransactions)
	}
	else{
		[List[ExpenseTransaction]]$bankTransactions = Get-BankExpenses($BankFilePath)
		$Expenses.AddRange($bankTransactions)
		[List[ExpenseTransaction]]$creditTransactions = Get-CreditCardExpenses($CCFilePath)
		$Expenses.AddRange($creditTransactions)
	}

	return $Expenses
}
function Get-BankIncome{
	param(
		[string]$FilePath
	)
	$IncomeList = New-Object List[IncomeTransaction]
	$bankData = import-csv $FilePath | where-object { $_."Transaction Type" -match "Credit" }
	foreach ($transaction in $bankData) {
		[string]$formattedNotes = Format-IncomeNotes -transaction $transaction.Description
		[string]$readableNotes = Format-TextAsReadable -Text $formattedNotes
		$income = [IncomeTransaction]::new($transaction."Posting Date", $transaction.Amount, $readableNotes)
		$IncomeList.Add($income)
	}
	return $IncomeList
}
function Get-CreditCardIncome{
	param(
		[string]$FilePath
	)
	$IncomeList = New-Object List[IncomeTransaction]
	$creditCardData = import-csv $FilePath | where-object {  !([string]::IsNullOrEmpty($_.Credit)) }
	foreach ($transaction in $creditCardData) {
		[string]$formattedNotes = Format-IncomeNotes -transaction $transaction.Description
		[string]$readableNotes = Format-TextAsReadable -Text $formattedNotes
		$income = [IncomeTransaction]::new($transaction.Date, $transaction.Credit, $readableNotes)
		$IncomeList.Add($income)
	}
	$filteredIncome = Remove-UnnecessaryCreditIncome -Income $IncomeList
	return $filteredIncome
}
function Get-BankExpenses{
	param(
		[string]$FilePath
	)
	$ExpenseList = New-Object List[ExpenseTransaction]
	$bankData = import-csv $FilePath | where-object { $_."Transaction Type" -match "Debit" }

	foreach($transaction in $bankData){
		[string]$formattedExpenseNote = Format-ExpenseNotes -transaction $transaction.Description
		[string]$readableNotes = Format-TextAsReadable -Text $formattedExpenseNote
		$expense = [ExpenseTransaction]::new($transaction."Posting Date", $transaction.Amount, $readableNotes)
		$ExpenseList.Add($expense)
	}

	$filteredExpenseList = Remove-UnnecessaryBankExpenses($ExpenseList)
	return $filteredExpenseList
}
function Get-CreditCardExpenses{
	param(
		[string]$FilePath
	)
	$ExpenseList = New-Object List[ExpenseTransaction]
	$creditCardData = import-csv $FilePath | where-object {  !([string]::IsNullOrEmpty($_.Debit)) }
	foreach ($transaction in $creditCardData) {
		[string]$formattedExpenseNote = Format-ExpenseNotes -transaction $transaction.Description
		[string]$readableNotes = Format-TextAsReadable -Text $formattedExpenseNote
		$expense = [ExpenseTransaction]::new($transaction.Date, $transaction.Debit, $readableNotes)
		$ExpenseList.Add($expense)
	}
	return $ExpenseList
}
function Remove-UnnecessaryBankExpenses{
	param(
		[List[ExpenseTransaction]]$expenses
	)
	$filteredExpenseList = new-object List[ExpenseTransaction]
	foreach ($item in $expenses) {
		switch ($item.Notes) 
		{
			{ $_.ToLower().Contains("withdrawal transfer to") }{ Break }
			{ $_.ToLower().Contains("vanguard buy individual buy") }{ Break }
			{ $_.ToLower().Contains("citi card online") }{ Break }
			{ $_.ToLower().Contains("transfer to saver") }{ Break }
			Default { $filteredExpenseList.Add($item) }
		}
	}
	return $filteredExpenseList
}
function Remove-UnnecessaryCreditIncome{
	param(
		[List[IncomeTransaction]]$Income
	)
	$filteredIncomeList = new-object List[IncomeTransaction]
	foreach ($item in $Income) {
		switch ($item.Notes) 
		{
			{ $_.ToLower().Contains("thank you") }{ Break }
			Default { $filteredIncomeList.Add($item) }
		}
	}
	return $filteredIncomeList
}
function Format-ExpenseNotes {
	param (
		[string]$transaction
	)
	if($transaction.Contains("POS Withdrawal  SQ *")){
		return $transaction.Replace("POS Withdrawal  SQ *", "").TrimStart()
	}
	if ($transaction.Contains("Withdrawal MORTGAGE PAYMENT")){
		return "Mortgage Payment"
	}
	if($transaction.Contains("Descriptive Withdrawal")){
		return $transaction.Replace("Descriptive Withdrawal", "").TrimStart()
	}
	if($transaction.Contains("External Withdrawal")){
		return $transaction.Replace("External Withdrawal ", "").TrimStart()
	}
	if($transaction.Contains("POS Withdrawal")){
		#might want to add some code here to keep track
		#of how many times in a month you get this (need 12 to get big bank interest)
		return $transaction.Replace("POS Withdrawal", "").TrimStart()
	}
	return $transaction
}
function Format-IncomeNotes {
	param (
		[string]$transaction
	)
	if ($transaction.Contains("MOBILE DEP")){
		return "Mobile Deposit"
	}
	if ($transaction.Contains("External Deposit")){
		return $transaction.Replace("External Deposit", "")
	}
	if($transaction.Contains("Descriptive Deposit")){
		return $transaction.Replace("Descriptive Deposit", "")
	}
	if($transaction.Contains("Credit Dividends")){
		return "Bank Interest"
	}
	return $transaction
}
function Format-TextAsReadable{
	param (
		[string]$Text
	)
		if ($null -ne $Text){
			$textInfo = (New-object -TypeName CultureInfo -ArgumentList "en-US",$false).TextInfo
			$formatString = $Text.Replace("'","").Replace(",","").TrimStart().ToLower()
			[string]$formattedText = $textInfo.ToTitleCase($formatString)
			return $formattedText
		}
		else{
			return $Text
		}
}