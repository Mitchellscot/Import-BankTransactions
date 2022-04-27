using namespace System.Collections.Generic
using module ".\Transaction-Class.psm1"
import-module .\Csv-Helpers.psm1
$BASE_FILE_PATH = "$HOME\Downloads\"
$checkingFile= $BASE_FILE_PATH + "ExportedTransactions.csv"
$creditCardFile= $BASE_FILE_PATH + "credit.csv"
function Get-ExpensesFromCsv{
	param(
		[CsvFilesExist]$ExistingFiles
	)
	$Expenses = New-Object List[ExpenseTransaction]
	if($ExistingFiles -eq [CsvFilesExist]::BankFileOnly){
		$Expenses = Get-Expenses -BankFilePath $checkingFile -BankOnly
	}
	elseif($ExistingFiles -eq [CsvFilesExist]::CreditCardFileOnly){
		$Expenses = Get-Expenses -CCFilePath $creditCardFile -CCOnly
	}
	elseif($ExistingFiles -eq [CsvFilesExist]::BothFiles){
		$Expenses = Get-Expenses -BankFilePath $checkingFile -CCFilePath $creditCardFile
	}
	else{
		write-host "Can't find any files to import."
        start-sleep 2
        write-host "Visit the bank and Credit Card websites to download the files."
        start-sleep 2
        write-host "Exiting"
        start-sleep 1
        exit
	}
	return $Expenses
}
function Get-IncomeFromCsv{
	param(
		[CsvFilesExist]$ExistingFiles
	)
	$Income = New-Object List[IncomeTransaction]
	if($ExistingFiles -eq [CsvFilesExist]::BankFileOnly){
		$Income = Get-Income -BankFilePath $checkingFile -BankOnly
	}
	elseif($ExistingFiles -eq [CsvFilesExist]::CreditCardFileOnly){
		$Income = Get-Income -CCFilePath $creditCardFile -CCOnly
	}
	elseif($ExistingFiles -eq [CsvFilesExist]::BothFiles){
		$Income = Get-Income -BankFilePath $checkingFile -CCFilePath $creditCardFile
	}
	else{
		write-host "Can't find any files to import."
        start-sleep 2
        write-host "Visit the bank and Credit Card websites to download the files."
        start-sleep 2
        write-host "Exiting"
        start-sleep 1
        exit
	}
	return $Income
}
function Find-BankAndCreditCsvFiles{
    $checkingFileExists = Test-Path -Path $checkingFile
    $CCFileExists = Test-Path -Path $creditCardFile
    if($checkingFileExists -and !$CCFileExists){
        $CCFileExistsAsAnotherName = Find-CreditCardFileName $BASE_FILE_PATH
        if($CCFileExistsAsAnotherName){
            return [CsvFilesExist]::BothFiles
        }
        else{
            write-host "Running transaction import from bank file only."
            return [CsvFilesExist]::BankFileOnly
        }
    }
    elseif($CCFileExists -and !$checkingFileExists){
        write-host "Running transaction import from credit card file only."
        return [CsvFilesExist]::CreditCardFileOnly
    }
    elseif(!$checkingFileExists -and !$CCFileExists){
        write-host "Can't find any files to import."
        start-sleep 2
        write-host "Visit the bank and Credit Card websites to download the files."
        start-sleep 2
        write-host "Exiting"
        start-sleep 1
        exit
    }
    else{
        return [CsvFilesExist]::BothFiles
    }
}
function Find-CreditCardFileName{
    param(
        [string]$filePath
    )
    $Since = test-path -Path "$HOME\Downloads\Since*"
    $From = test-path -Path "$HOME\Downloads\From*"
    $StatementClosed = test-path -Path "$HOME\Statement closed*"
    $YearToDate = test-path -Path "$HOME\Year to date.csv"
    if($Since){
        $file = Get-ChildItem -path "$HOME\Downloads\" -Name Since* | select-object -index 0
        $fullFilePath = $BASE_FILE_PATH + $file
        copy-item -Path $fullFilePath -Destination $HOME\credit.csv
        write-host "Converting credit card file to credit.csv"
        start-sleep -s 3
        return $true
    }
    elseif($From){
        $file = Get-ChildItem -path "$HOME\Downloads\" -Name Since* | select-object -index 0
        $fullFilePath = $BASE_FILE_PATH + $file
        copy-item -Path $fullFilePath -Destination $HOME\Downloads\credit.csv
        write-host "Converting credit card file to credit.csv"
        start-sleep -s 3
        return $true
    }
    elseif($StatementClosed){
        $file = Get-ChildItem -path "$HOME\Downloads\" -Name "Statement Closed*" | select-object -index 0
        $fullFilePath = $BASE_FILE_PATH + $file
        copy-item -Path $fullFilePath -Destination $HOME\Downloads\credit.csv
        write-host "Converting credit card file to credit.csv"
        start-sleep -s 3
        return $true
    }    
    elseif($YearToDate){
        $file = Get-ChildItem -path "$HOME\Downloads\" -Name "Year*" | select-object -index 0
        $fullFilePath = $BASE_FILE_PATH + $file
        copy-item -Path $fullFilePath -Destination $HOME\Downloads\credit.csv
        write-host "Converting credit card file to credit.csv"
        start-sleep -s 3
        return $true
    }
    else {
        return $false
    }
}
function Remove-Files{
    get-childitem $creditCardFile | remove-item
    get-childitem $checkingFile | remove-item
    write-host "CSV files deleted."
}
