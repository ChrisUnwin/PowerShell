#Variables to be used in the script
$ResourceGroupName = 'DMDb' 
$ServerName = 'dmproduction' 
$DBName = 'DMDatabase_Production' 
$StorageAccount = 'dmstoragechris'
$StorageURI = "https://dmstoragechris.blob.core.windows.net/bacpacs/DMDatabase_"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$StorageKey = "[REDACTED FOR SECURITY]"
$StorageContainer = 'bacpacs'
$AdminLogin = "Chris.Unwin"
$BacPacBlob = "DMDatabase_"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$LocalSQLServer = "PSE-LT-CHRISU\WIN2019"
$restoredDatabaseName = 'DMDatabase_Temp_Restore'
$SQLCloneServer = 'http://PSE-LT-CHRISU:14145'
$CurrentMachine = 'PSE-LT-CHRISU'
$InstanceName = 'WIN2019'
$ImagePath = 'C:\Temp\Images'
$ImageName = 'DMDatabase_Production'
$MaskingScriptLocation = 'C:\Users\chris.unwin\Documents\Data Masker(SqlServer)\Masking Sets\AzureMaskingFun.DMSMaskSet'

# Set names for developers to receive Clones
$Devs = @("Dev_Chris", "Dev_Kendra", "Dev_Andreea")

#Connect to Azure Account and set subscription context
Connect-AzAccount 
Set-AzContext -SubscriptionId '[REDACTED FOR SECURITY]'

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

#Mask and Provision the copy
# Connect to SQL Clone Server
Connect-SqlClone -ServerUrl $SQLCloneServer

# Set variables for Image and Clone Location
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $CurrentMachine -InstanceName $InstanceName
$ImageDestination = Get-SqlCloneImageLocation -Path $ImagePath
$MaskingScript = New-SqlCloneMask -Path $MaskingScriptLocation

# Create New Masked Image from Clone
New-SqlCloneImage -Name $ImageName -SqlServerInstance $SqlServerInstance -DatabaseName $restoredDatabaseName `
-Modifications @($MaskingScript) `
-Destination $ImageDestination | Wait-SqlCloneOperation

$DevImage = Get-SqlCloneImage -Name $ImageName

# Create New Clones for Devs
$Devs| ForEach-Object { # note - '{' needs to be on same line as 'foreach' !
   $DevImage | New-SqlClone -Name "DMDatabase_$_" -Location $SqlServerInstance 
};

#Drop the Temp Copy
Invoke-Sqlcmd -SqlInstance $LocalSqlServer -Query "DROP DATABASE $BacPacBlob;" 