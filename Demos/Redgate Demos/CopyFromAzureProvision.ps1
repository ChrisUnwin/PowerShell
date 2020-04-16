#Variables to be used in the script
$ResourceGroupName = 'DMDb' 
$ServerName = 'dmproduction' 
$DBName = 'DMDatabase_Production' 
$StorageAccount = 'dmstoragechris'
$StorageURI = "https://dmstoragechris.blob.core.windows.net/bacpacs/DMDatabase_"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$StorageKey = "XMMRlrVR1FzQGwvpA9FTHAUYQihgWles7sE3vjk9ZF0i3s+0WoeHlDHQX04HhvVBl/AI2sooCHG5L1bzEyhZwQ=="
$StorageContainer = 'bacpacs'
$AdminLogin = "Chris.Unwin"
$BacPacBlob = "DMDatabase_"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$LocalSQLServer = "PSE-LT-CHRISU"
$restoredDatabaseName = 'DMDatabase_Temp_Restore'

#Connect to Azure Account and set subscription context
Connect-AzAccount 
Set-AzContext -SubscriptionId 'a36be632-e20c-48fd-8af0-ba5b2c623951'

# Start export of SQL DB
$ExportRequest = New-AzSqlDatabaseExport -DatabaseName $DBName `
-ServerName $ServerName `
-StorageKeyType "storageaccesskey" `
-StorageKey $StorageKey `
-StorageUri $StorageURI `
-ResourceGroupName $ResourceGroupName `
-AdministratorLogin $AdminLogin

# Wait for export to complete
$ExportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $ExportRequest.OperationStatusLink
[Console]::Write("Exporting")
while ($ExportStatus.Status -eq "InProgress")
{
    $ExportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $ExportRequest.OperationStatusLink
    [Console]::Write(".")
    Start-Sleep -s 10
}
[Console]::WriteLine("")
$ExportStatus

# Download the bacpac file
Write-Output "Downloading bacpac file"
$StorageContext = New-AzStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $StorageKey
Get-AzStorageBlobContent -Container $StorageContainer -Blob $BacPacBlob -Context $StorageContext -Destination "C:\temp\BACPACS"

# Import BacPac file as data tier application
$fileExe = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\150\sqlpackage.exe"
$bacpacname = "C:\temp\BACPACS\"+ $BacPacBlob 
& $fileExe /a:Import /sf:$bacpacname /tdn:$restoredDatabaseName /tsn:$LocalSQLServer