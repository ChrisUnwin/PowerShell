Connect-AzAccount 
Set-AzContext -SubscriptionId 'a36be632-e20c-48fd-8af0-ba5b2c623951'
$ResourceGroupName = 'DMDb'
$SourceHopServer = 'dmproduction'
$TargetServer = 'dmnonproduction'
$DBName = 'DMDatabase_Production'
$TempDBName = 'DM_Prep'
$TargetDBName = 'DMDatabase_Dev_Kendra'

Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SourceHopServer

#New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $SourceHopServer -DatabaseName $DBName `
#    -CopyResourceGroupName $ResourceGroupName -CopyServerName $SourceHopServer -CopyDatabaseName $TempDBName

