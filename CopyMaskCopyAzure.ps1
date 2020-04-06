Connect-AzAccount 
Set-AzContext -SubscriptionId 'a36be632-e20c-48fd-8af0-ba5b2c623951'
$ResourceGroupName = 'DMDb'
$SourceHopServer = 'dmproduction'
$TargetServer = 'dmnonproduction'
$DBName = 'DMDatabase_Production'
$TempDBName = 'DM_Prep'
$TargetDBName = 'DMDatabase_Dev_Kendra'

New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $SourceHopServer -DatabaseName $DBName `
    -CopyResourceGroupName $ResourceGroupName -CopyServerName $SourceHopServer -CopyDatabaseName $TempDBName

Start-Sleep -Seconds 300

& "C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe" PARFILE="C:\Users\chris.unwin\Documents\Data Masker(SqlServer)\Masking Sets\AzureFun.DMSMaskSet"

Start-Sleep -Seconds 300

New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $SourceHopServer -DatabaseName $TempDBName `
    -CopyResourceGroupName $ResourceGroupName -CopyServerName $TargetServer -CopyDatabaseName $TargetDBName

Start-Sleep -Seconds 300

Remove-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SourceHopServer -DatabaseName $TempDBName