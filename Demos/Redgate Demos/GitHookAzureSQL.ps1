$ResourceGroupName = 'DMDb' #Azure Resource Group Name
$ServerName = 'dmnonproduction'
$DBName = 'DMDatabase_Dev' #Active Development DB
$SubscriptionID = 'a36be632-e20c-48fd-8af0-ba5b2c623951'

#############################################################################

Connect-AzAccount #Connect to Azure Account and set subscription context
Set-AzContext -SubscriptionId $SubscriptionID

#############################################################################

if ($null -eq (Get-Command "git" -ErrorAction SilentlyContinue)) {
    throw "This script requires git to be installed and available on PATH"
}

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

Write-Information "Provisioning database ${DBName} for branch ${toBranch}..."
Write-Verbose "Switched from branch ${fromBranch} to branch ${toBranch}"

$GoldenDBName = $DBName+"_Golden"
$ToBranchDB = $DBName+"_"+$toBranch
$ToBranchDBtemp = $DBName+"_"+$toBranch+"_temp"
$FromBranchDB = $DBName+"_"+$fromBranch
$ExistingDBs = Get-AzSqlDatabase -ServerName $ServerName -ResourceGroup $ResourceGroupName

if ($ExistingDBs.DatabaseName -NotContains $GoldenDBName) {

    Write-Information "No golden copy found for $DBname, creating $GoldenDBName..."

    New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $DBName `
    -CopyResourceGroupName $ResourceGroupName -CopyServerName $ServerName -CopyDatabaseName $GoldenDBName

}

if ($ExistingDBs.DatabaseName -NotContains $ToBranchDB) {

    Write-Information "Existing database $ToBranchDB, provisioning new database copy..."

    Set-AzSqlDatabase -DatabaseName $DBName -NewName $FromBranchDB -ServerName $ServerName -ResourceGroupName $ResourceGroupName 

    Start-Sleep -Seconds 15

    Write-Information "$FromBranchDB created, creating new master copy for branch $toBranch..."

    New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $GoldenDBName `
    -CopyResourceGroupName $ResourceGroupName -CopyServerName $ServerName -CopyDatabaseName $DBName

} else {

    Write-Information "Existing database $ToBranchDB found, switching to live copy..."

    Set-AzSqlDatabase -DatabaseName $DBName -NewName $ToBranchDBtemp -ServerName $ServerName -ResourceGroupName $ResourceGroupName

    Start-Sleep -Seconds 15

    Set-AzSqlDatabase -DatabaseName $ToBranchDB -NewName $DBName -ServerName $ServerName -ResourceGroupName $ResourceGroupName

    Start-Sleep -Seconds 15

    Set-AzSqlDatabase -DatabaseName $ToBranchDBtemp -NewName $ToBranchDB -ServerName $ServerName -ResourceGroupName $ResourceGroupName

}

Write-Information "Database ${DBName} successfully provisioned."