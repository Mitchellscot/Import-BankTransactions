using namespace System

class ExpenseTransaction {
    [DateTimeOffset] $Date
    [decimal] $Amount
    [string] $Notes
    [int] $MerchantId
    [int] $CategoryId

    ExpenseTransaction([string] $Date, [string] $Amount, [string] $Notes) {
        $this.Date = Convert-DateTimeOffSetToMinnesotaTime($Date)
        $this.Amount = [math]::Round([decimal]$Amount.Trim("-"), 2)
        $this.Notes = $Notes
    }
}

class IncomeTransaction {
    [DateTimeOffset] $Date
    [decimal] $Amount
    [string] $Notes
    [int] $IncomeSourceId
    [int] $CategoryId

    IncomeTransaction([string] $Date, [string] $Amount, [string] $Notes) {
        $this.Date = Convert-DateTimeOffSetToMinnesotaTime($Date)
        $this.Amount = [math]::Round([math]::abs($Amount), 2)
        $this.Notes = $Notes
    }
}
class ImportRule {
    [string] $Rule
    [Nullable[int]] $MerchantSourceId
    [Nullable[int]] $CategoryId

    ImportRule([string] $Rule, [int] $MerchantSourceId, [int] $CategoryId) {
        $this.Rule = $Rule
        $this.MerchantSourceId = If($MerchantSourceId) { $MerchantSourceId } Else { $null }
        $this.CategoryId = If($CategoryId) { $CategoryId } Else { $null }
    }
}
function Convert-DateTimeOffSetToMinnesotaTime{
    param(
        [string]$date
    )
    $dt = [datetime]$date
    $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById("Central Standard Time")
    $Offset = $timeZone.GetUtcOffset($dt)
    $d = [dateTimeOffSet]::new($dt, $Offset)
    return $d
}
enum CsvFilesExist{
    BothFiles
    BankFileOnly
    CreditCardFileOnly
}