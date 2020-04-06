#Variables to be used in the script
$ResourceGroupName = 'DMDb' #Azure Resource Group Name
$SourceHopServer = 'dmproduction' #The Production 'server' which will be used as the source and the hop
$TargetServer = 'dmnonproduction' #The ultimate final destination
$DBName = 'DMDatabase_Production' #Source DB to be copied
$TempDBName = 'DM_Prep' #Temp DB Name where masking will happen
$TargetDBName = 'DMDatabase_Dev_Kendra' #Final copy of the DB

#Connect to Azure Account and set subscription context
Connect-AzAccount 
Set-AzContext -SubscriptionId 'Sub-ID'

#Create the temporary copy
New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $SourceHopServer -DatabaseName $DBName `
    -CopyResourceGroupName $ResourceGroupName -CopyServerName $SourceHopServer -CopyDatabaseName $TempDBName

#Wait for copy to complete
Start-Sleep -Seconds 300

#Invoke Data Masker on local machine to mask the temp copy
& "C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe" PARFILE="C:\Users\chris.unwin\Documents\Data Masker(SqlServer)\Masking Sets\AzureFun.DMSMaskSet"

#Wait for masking to complete
Start-Sleep -Seconds 300

#Create the copy over onto the non prod 'server'
New-AzSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $SourceHopServer -DatabaseName $TempDBName `
    -CopyResourceGroupName $ResourceGroupName -CopyServerName $TargetServer -CopyDatabaseName $TargetDBName

#Wait for copy to complete
Start-Sleep -Seconds 300

#Remove the temporary copy
Remove-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SourceHopServer -DatabaseName $TempDBName