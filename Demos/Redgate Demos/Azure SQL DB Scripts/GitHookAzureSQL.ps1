#############################################################################
# Script for easily branch switching between different Azure SQL Databases ##
#############################################################################

## Update the below values 

$ResourceGroupName = 'YourResourceGroup' #Azure Resource Group Name
$ServerName = 'YourServer' #Your non prod Azure Server name
$DBName = 'YourDatabase' #Active Development DB
$SubscriptionID = 'INSERT SUB ID' #Your subscription ID

#############################################################################

## If you want a different method of authentication then change the below

Connect-AzAccount #Connect to Azure Account and set subscription context
Set-AzContext -SubscriptionId $SubscriptionID

#############################################################################

## GitHook Script

#Check if Git is installed locally first

if ($null -eq (Get-Command "git" -ErrorAction SilentlyContinue)) {
    throw "This script requires git to be installed and available on PATH"
}

#Fetch the To and From Branch for naming purposes

$reflogResult = git reflog
$lastReflog = $reflogResult[0]
$lastReflogTokens = $lastReflog.Split(" ")
$fromBranchName = $lastReflogTokens[5]
$toBranchName = $lastReflogTokens[7]
$fromBranch = "$($fromBranchName | ForEach-Object {$_ -replace "\W"})"
$toBranch = "$($toBranchName | ForEach-Object {$_ -replace "\W"})"

if ($fromBranch -eq $toBranch) {
    return
}

Write-Host "Provisioning database ${DBName} for branch ${toBranch}..."
Write-Host "Switched from branch ${fromBranch} to branch ${toBranch}"

#Check if a golden copy exists and create one if it doesn't

$GoldenDBName = $DBName+"_Golden"
$ToBranchDB = $DBName+"_"+$toBranch
$FromBranchDB = $DBName+"_"+$fromBranch
$ExistingDBs = Get-AzSqlDatabase -ServerName $ServerName -ResourceGroup $ResourceGroupName

if ($ExistingDBs.DatabaseName -NotContains $GoldenDBName) {

    Write-Host "No golden copy found for $DBname, creating $GoldenDBName..."

    New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $DBName `
    -CopyResourceGroupName $ResourceGroupName -CopyServerName $ServerName -CopyDatabaseName $GoldenDBName

}

#If you're switching to a DB that already exists, straight up rename, else create a new copy to work from

if ($ExistingDBs.DatabaseName -NotContains $ToBranchDB) {

    Write-Host "$ToBranchDB not found, renaming and provisioning new database copy..."

    Set-AzSqlDatabase -DatabaseName $DBName -NewName $FromBranchDB -ServerName $ServerName -ResourceGroupName $ResourceGroupName 

    Write-Host "$FromBranchDB created, creating new live dev copy for branch $toBranch..."

    New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $GoldenDBName `
    -CopyResourceGroupName $ResourceGroupName -CopyServerName $ServerName -CopyDatabaseName $DBName

} else {

    Write-Host "Existing database $ToBranchDB found, switching to live copy..."

    Set-AzSqlDatabase -DatabaseName $DBName -NewName $FromBranchDB -ServerName $ServerName -ResourceGroupName $ResourceGroupName

    Set-AzSqlDatabase -DatabaseName $ToBranchDB -NewName $DBName -ServerName $ServerName -ResourceGroupName $ResourceGroupName

}

Write-Information "Database ${DBName} successfully provisioned."