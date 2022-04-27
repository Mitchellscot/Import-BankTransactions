using namespace System.Collections.Generic
using module ".\Transaction-Class.psm1"
[string]$connect = Get-Content .\connection-string

#region Income
function Get-IncomeNotInDatabase {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [List[IncomeTransaction]]$IncomeList
    )

    $oldestDate = Get-OldestDateInList $IncomeList
    $currentIncome = Get-IncomeInDatabase $oldestDate
    if ($null -eq $currentIncome) {
        return $IncomeList
    }

    $incomeNotFoundInTheDatabase = new-object List[IncomeTransaction]
    foreach ($item in $IncomeList) {
        $delegate = [Func[IncomeTransaction, bool]] { [decimal]$args[0].Amount -eq $item.Amount -and [datetimeoffset]$args[0].Date -eq $item.Date }
        if (![Enumerable]::Any([List[IncomeTransaction]]$currentIncome, $delegate)) {
            $incomeNotFoundInTheDatabase.Add($item)
        }
    }
    return $incomeNotFoundInTheDatabase
}
function Get-IncomeInDatabase {
    param(
        [string]$dateToLookBack
    )
    $query = "select Date, Amount, Notes from Income where Date >= '$dateToLookBack' order by Date desc;"
    try {
        $incomeNotFoundInTheDatabase = new-object List[IncomeTransaction]
        $data = Invoke-Sqlcmd -ConnectionString $connect -Query $query
        foreach ($item in $data) {
            $income = [IncomeTransaction]::new($item[0], $item[1], $item[2])
            $incomeNotFoundInTheDatabase.Add($income)
        }
        return $incomeNotFoundInTheDatabase
    }
    catch {
        out-file -FilePath "$HOME\Desktop\errors.txt" -Append -InputObject $cmd
        Write-Error -Message "ERROR: $query"
    }
}
#endregion
#region Expenses
function Get-ExpensesNotInDatabase {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [List[ExpenseTransaction]]$ExpenseList
    )

    $oldestDate = Get-OldestDateInList -List $ExpenseList

    [List[ExpenseTransaction]]$currentExpenses = Get-ExpensesInDatabase($oldestDate)
    if ($null -eq $currentExpenses) {
        return $ExpenseList
    }

    $expensesNotFoundInTheDatabase = new-object List[ExpenseTransaction]
    foreach ($item in $ExpenseList) {
        $delegate = [Func[ExpenseTransaction, bool]] { 
            [decimal]$args[0].Amount -eq $item.Amount -and 
            [datetimeoffset]$args[0].Date -eq $item.Date 
        }
        if (![Enumerable]::Any([List[ExpenseTransaction]]$currentExpenses, $delegate)) {
            $expensesNotFoundInTheDatabase.Add($item)
        }
    }
    return $expensesNotFoundInTheDatabase
}
function Get-ExpensesInDatabase {
    param(
        [string]$dateToLookBack
    )    
    $query = "select Date, Amount, Notes from Expenses where Date >= '$dateToLookBack' order by Date desc;"
    $expensesInDatabase = new-object List[ExpenseTransaction]
    try {
        $data = Invoke-Sqlcmd -ConnectionString $connect -Query $query -As DataRows
        foreach ($item in $data) {
            $expense = [ExpenseTransaction]::new($item[0], $item[1], $item[2])
            $expensesInDatabase.Add($expense)
        }
    }
    catch {
        out-file -FilePath "$HOME\Desktop\errors.txt" -Append -InputObject $cmd
        Write-Error -Message "ERROR: $query"
    }
    return $expensesInDatabase
}
#endregion
#region Merchants And Categories
function Set-MerchantsAndCategories {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [List[ExpenseTransaction]]$ExpenseList)
        [List[ImportRule]]$expenseRules = Get-ExpenseImportRules
    foreach ($item in $ExpenseList) {
        if ([string]::IsNullOrEmpty($item.Notes)) {
            break
        }
        $delegate = [Func[ImportRule, bool]] { $item.Notes.ToLower().Contains($args[0].Rule) }
        if ([Enumerable]::Any([List[ImportRule]]$expenseRules, $delegate)) {
            $item.MerchantId = ($expenseRules.GetEnumerator() | 
            where-object { $item.Notes.ToLower().Contains($_.Rule) } | 
            Select-Object -Index 0).MerchantSourceId
            $item.CategoryId = ($expenseRules.GetEnumerator() | 
            where-object { $item.Notes.ToLower().Contains($_.Rule) } | 
            Select-Object -Index 0).CategoryId
        }
    }
    return [List[ExpenseTransaction]]$ExpenseList
}
function Get-ExpenseImportRules {
    $query = "select [Rule], MerchantSourceId, CategoryId from ImportRules where ""Transaction""='Expense';"
    $expenseRules = new-object List[ImportRule]
    $data = Invoke-Sqlcmd -ConnectionString $connect -Query $query
    foreach ($item in $data) {
        $merchantId = If($item[1] -isnot [DBNULL]) { $item[1] } Else { $null }
        $categoryId = If($item[2] -isnot [DBNULL]) { $item[2] } Else { $null }
        $expenseRule = [ImportRule]::new($item[0], $merchantId, $categoryId)
        $expenseRules.Add($expenseRule)
    }
    return [List[ImportRule]]$expenseRules
}
#endregion
#region Sources And Categories
function Set-SourcesAndCategories {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [List[IncomeTransaction]]$IncomeList)
        [List[ImportRule]]$IncomeRules = Get-IncomeImportRules
    foreach ($item in $IncomeList) {
        if ([string]::IsNullOrEmpty($item.Notes)) {
            break
        }
        $delegate = [Func[ImportRule, bool]] { $item.Notes.ToLower().Contains($args[0].Rule) }
        if ([Enumerable]::Any([List[ImportRule]]$IncomeRules, $delegate)) {
            $item.IncomeSourceId = ($IncomeRules.GetEnumerator() | 
            where-object { $item.Notes.ToLower().Contains($_.Rule) } | 
            Select-Object -Index 0).MerchantSourceId
            $item.CategoryId = ($IncomeRules.GetEnumerator() | 
            where-object { $item.Notes.ToLower().Contains($_.Rule) } | 
            Select-Object -Index 0).CategoryId
        }
    }
    return [List[IncomeTransaction]]$IncomeList
}function Get-IncomeImportRules {
    $query = "select [Rule], MerchantSourceId, CategoryId from ImportRules where ""Transaction""='Income';"
    $incomeRules = new-object List[ImportRule]
    $data = Invoke-Sqlcmd -ConnectionString $connect -Query $query
    foreach ($item in $data) {
        $sourceId = If($item[1] -isnot [DBNULL]) { $item[1] } Else { $null }
        $categoryId = If($item[2] -isnot [DBNULL]) { $item[2] } Else { $null }
        $incomeRule = [ImportRule]::new($item[0], $sourceId, $categoryId)
        $incomeRules.Add($incomeRule)
    }
    return [List[ImportRule]]$incomeRules
}
#endregion
#region Insert Data
function Add-ExpensesIntoDatabase {
    param(
        [List[ExpenseTransaction]]$Expenses
    )
    [List[ExpenseTransaction]]$Collection
    $filteredExpenses = Remove-EntriesAlreadyInExpenseReviewTable -expenseList $Expenses
    $emptyDatabase = Get-FirstRunStatusForReviewTable -Expense
    if ($null -eq $filteredExpenses -and !$emptyDatabase) {
        write-host "No new expenses"
        return
    }
    if ($emptyDatabase) {
        $Collection = $Expenses
    }
    else {
        $Collection = $filteredExpenses
    }
    foreach ($item in $Collection) {
        $cmd = ""
        if ($item.MerchantId -eq 0 -and $item.CategoryId -eq 0) {
            $date = $item.Date
            $amount = $item.Amount
            $notes = $item.Notes
            $source = $item.MerchantId
            $category = $item.CategoryId
            $cmd = "insert into ExpenseReview(Date, Amount, Notes, IsReviewed)
            values('$date', $amount ,'$notes', 0);"
        }
        elseif ($item.MerchantId -eq 0 -and $item.CategoryId -ne 0) {
            $date = $item.Date
            $amount = $item.Amount
            $notes = $item.Notes
            $source = $item.MerchantId
            $category = $item.CategoryId
            $cmd = "insert into ExpenseReview(Date, Amount, Notes, SuggestedCategoryId, IsReviewed)
            values('$date', $amount ,'$notes', $category, 0);"
        }
        elseif ($item.MerchantId -ne 0 -and $item.CategoryId -eq 0) {
            $date = $item.Date
            $amount = $item.Amount
            $notes = $item.Notes
            $source = $item.MerchantId
            $category = $item.CategoryId
            $cmd = "insert into ExpenseReview(Date, Amount, Notes, SuggestedMerchantId, IsReviewed)
            values('$date', $amount ,'$notes' ,$source, 0);"
        }
        else {
            $date = $item.Date
            $amount = $item.Amount
            $notes = $item.Notes
            $source = $item.MerchantId
            $category = $item.CategoryId
            $cmd = "insert into ExpenseReview(Date, Amount, Notes, SuggestedMerchantId, SuggestedCategoryId, IsReviewed)
            values('$date', $amount ,'$notes' ,$source ,$category, 0);"
        }
        $command = $cmd
        try {
            Invoke-Sqlcmd -ConnectionString $connect -Query $command
            $rows ++
        }
        catch {
            out-file -FilePath "$HOME\Desktop\errors.txt" -Append -InputObject $cmd
            Write-Error -Message "error writing $cmd"
        }
    }
    write-host "Expenses Added: $rows"
}
function Add-IncomeIntoDatabase {
    param(
        [List[IncomeTransaction]]$Income
    )
    [List[IncomeTransaction]]$Collection
    $filteredIncome = Remove-EntriesAlreadyInIncomeReviewTable -IncomeList $Income
    $emptyDatabase = Get-FirstRunStatusForReviewTable -Income
    if ($null -eq $filteredIncome -and !$emptyDatabase) {
        write-host "No new income"
        return
    }
    if ($emptyDatabase) {
        $Collection = $Income
    }
    else {
        $Collection = $filteredIncome
    }
    [int]$rows = 0;
    foreach ($item in $Collection) {
        $cmd = ""
        if ($item.IncomeSourceId -eq 0 -and $item.CategoryId -eq 0) {
            $date = $item.Date
            $amount = $item.Amount
            $notes = $item.Notes
            $source = $item.IncomeSourceId
            $category = $item.CategoryId
            $cmd = "insert into IncomeReview(Date, Amount, Notes, IsReviewed)
            values('$date', $amount ,'$notes', 0);"
        }
        elseif ($item.IncomeSourceId -eq 0 -and $item.CategoryId -ne 0) {
            $date = $item.Date
            $amount = $item.Amount
            $notes = $item.Notes
            $source = $item.IncomeSourceId
            $category = $item.CategoryId
            $cmd = "insert into IncomeReview(Date, Amount, Notes, SuggestedCategoryId, IsReviewed)
            values('$date', $amount ,'$notes', $category, 0);"
        }
        elseif ($item.IncomeSourceId -ne 0 -and $item.CategoryId -eq 0) {
            $date = $item.Date
            $amount = $item.Amount
            $notes = $item.Notes
            $source = $item.IncomeSourceId
            $category = $item.CategoryId
            $cmd = "insert into IncomeReview(Date, Amount, Notes, SuggestedSourceId, IsReviewed)
            values('$date', $amount ,'$notes' ,$source, 0);"
        }
        else {
            $date = $item.Date
            $amount = $item.Amount
            $notes = $item.Notes
            $source = $item.IncomeSourceId
            $category = $item.CategoryId
            $cmd = "insert into IncomeReview(Date, Amount, Notes, SuggestedSourceId, SuggestedCategoryId, IsReviewed)
            values('$date', $amount ,'$notes' ,$source ,$category, 0);"
        }
        try {
            Invoke-Sqlcmd -ConnectionString $connect -Query $cmd
            $rows ++;
        }
        catch {
            out-file -FilePath "$HOME\Desktop\errors.txt" -Append -InputObject $cmd
            Write-Error -Message "error writing $cmd"
        }
    }
    write-host "Income Added:" $rows
}
#prevents duplicate entries in review tables
function Remove-EntriesAlreadyInExpenseReviewTable {
    param(
        [List[ExpenseTransaction]]$expenseList
    )
    $oldestDate = Get-OldestDateInList -List $expenseList
    $currentExpensesToReview = Get-ExpensesToReviewFromDB $oldestDate
    if (!$currentExpensesToReview) {
        return $null
    }
    $expensesNotFoundInTheDatabase = new-object List[ExpenseTransaction]

    foreach ($item in $ExpenseList) {
        $delegate = [Func[ExpenseTransaction, bool]] { [decimal]$args[0].Amount -eq $item.Amount -and [datetimeoffset]$args[0].Date -eq $item.Date }
        if (![Enumerable]::Any([List[ExpenseTransaction]]$currentExpensesToReview, $delegate)) {
            $expensesNotFoundInTheDatabase.Add($item)
        }
    }
    return $expensesNotFoundInTheDatabase
}
function Remove-EntriesAlreadyInIncomeReviewTable {
    param(
        [List[IncomeTransaction]]$IncomeList
    )
    $oldestIncomeDate = Get-OldestDateInList -List $IncomeList
    $currentIncomeToReview = Get-IncomeToReviewFromDB -dateToLookBack $oldestIncomeDate
    if (!$currentIncomeToReview) {
        return $null
    }
    $incomeNotFoundInTheDatabase = new-object List[IncomeTransaction]

    foreach ($item in $IncomeList) {
        $delegate = [Func[IncomeTransaction, bool]] { [decimal]$args[0].Amount -eq $item.Amount -and [datetimeoffset]$args[0].Date -eq $item.Date }
        if (![Enumerable]::Any([List[IncomeTransaction]]$currentIncomeToReview, $delegate)) {
            $incomeNotFoundInTheDatabase.Add($item)
        }
    }
    return $incomeNotFoundInTheDatabase
}
function Get-ExpensesToReviewFromDB {
    param(
        [string]$dateToLookBack
    )
    $query = "select Date, Amount, Notes from ExpenseReview where Date >= '$dateToLookBack';"
    $expenseData = new-object List[ExpenseTransaction]
    try {
        $data = Invoke-Sqlcmd -ConnectionString $connect -Query $query
        foreach ($item in $data) {
            $expense = [ExpenseTransaction]::new($item[0], $item[1], $item[2])
            $expenseData.Add($expense)
        }
    }
    catch {
        out-file -FilePath "$HOME\Desktop\errors.txt" -Append -InputObject $cmd
        Write-Error -Message "error writing $query"
    }
    return $expenseData
}
function Get-IncomeToReviewFromDB {
    param(
        [string]$dateToLookBack
    )
    $query = "select Date, Amount, Notes from IncomeReview where Date >= '$dateToLookBack';"
    $incomeData = new-object List[IncomeTransaction]
    try {
        $data = Invoke-Sqlcmd -ConnectionString $connect -Query $query
        foreach ($item in $data) {
            $row = [IncomeTransaction]::new($item[0], $item[1], $item[2])
            $incomeData.Add($row)
        }
    }
    catch {
        out-file -FilePath "$HOME\Desktop\errors.txt" -Append -InputObject $query
        Write-Error -Message "ERROR: $query"
    }
    return $incomeData
}
#endregion
#region Database Helpers
function Get-FirstRunStatusForReviewTable {
    param(
        [List[ExpenseTransaction]]$expenseList,
        [switch]$Income,
        [switch]$Expense
    ) 
    if ($Income) {
        $query = "select count(*) from IncomeReview;"
    }
    if ($Expense) {
        $query = "select count(*) from ExpenseReview;"
    }
    [int]$count = 0
    try {
        $data = Invoke-Sqlcmd -ConnectionString $connect -Query $query 
        $count = $data[0]
    }
    catch {
        out-file -FilePath "$HOME\Desktop\errors.txt" -Append -InputObject $query
        Write-Error -Message "ERROR: $query"
    }
    if ($count -gt 0) {
        return $false
    }
    else {
        return $true
    }
}
function Get-OldestDateInList {
    param(
        $List
    )
    $oldestTransactionDate = $List | sort-object -Property Date | select-object -Property Date | select-object -Index 0
    $date = $oldestTransactionDate.Date.UtcDateTime.Date
    return $date
}
#endregion