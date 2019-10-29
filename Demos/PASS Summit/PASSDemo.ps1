# Demo PowerShell Script for PASS Summit Demo
# Author: Chris Unwin - Redgate Software - chris.unwin@red-gate.com
# Last Modified Date: 29/10/2019 
# Pre-requisites: Modules: Az (https://www.powershellgallery.com/packages/Az/), dbatools (https://dbatools.io/)


###################################################################################
# Before we download this out let's make sure we have our classifications to hand #
###################################################################################

# Get Classification information from Azure DB
Connect-AzAccount 
Set-AzContext -SubscriptionID "a36be632-e20c-48fd-8af0-ba5b2c623951"
$ServerName = "dmproduction"
$DatabaseName = "DMDatabase_Production"
$Path = "C:\Temp\DMMask\Classification.json"
Get-AzSqlDatabaseSensitivityClassification -ResourceGroupName "DMDb" -ServerName $ServerName -DatabaseName $DatabaseName | ConvertTo-Json | Set-Content $Path


##############################################################################
# Next we need to pull down a copy of our Azure SQL DB for local development #
##############################################################################

# Start export of SQL DB
$AzureUser = "chris.unwin"
$ServerName = "dmproduction"
$StorageURI = "https://dmstoragechris.blob.core.windows.net/dmblobstore/DMDatabase_Production"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$ExportRequest = New-AzSqlDatabaseExport -DatabaseName "DMDatabase_Production" `
-ServerName $ServerName `
-StorageKeyType "storageaccesskey" `
-StorageKey "LdkmJkNntY+c4Mu2++He2D//QavZFL7b0I50tkJYsESujoGpXhNpF2eRoHNc3ZoW9iRS5QIYlfa2oBrKQiFBgQ==" `
-StorageUri $StorageURI `
-ResourceGroupName "DMDb" `
-AdministratorLogin $AzureUser

# Wait for export to complete
$ExportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $ExportRequest.OperationStatusLink
[Console]::Write("Exporting")
while ($ExportStatus.Status -eq "InProgress")
{
    $ExportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $ExportRequest.OperationStatusLink
    [Console]::Write(".")
    Start-Sleep -s 30
}
[Console]::WriteLine("")
$ExportStatus

# Download the bacpac file
Connect-AzAccount
Set-AzContext -SubscriptionID "a36be632-e20c-48fd-8af0-ba5b2c623951"
Write-Output "Downloading bacpac file"
$BacPacBlob = "DMDatabase_Production-"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$StorageContext = New-AzStorageContext -StorageAccountName "dmstoragechris" -StorageAccountKey "LdkmJkNntY+c4Mu2++He2D//QavZFL7b0I50tkJYsESujoGpXhNpF2eRoHNc3ZoW9iRS5QIYlfa2oBrKQiFBgQ=="
Get-AzStorageBlobContent -Container "dmblobstore" -Blob $BacPacBlob -Context $StorageContext -Destination "C:\Users\chris.unwin\Documents\BACPACs"

# Check for existance of Imported BacPac and remove if exists
Invoke-DbaQuery -SqlInstance "PSE-LT-CHRISU\WIN2019" -Query "DROP DATABASE IF EXISTS DMDatabase_Azure;"

# Import BacPac file as data tier application
$fileExe = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\150\sqlpackage.exe"
$bacpacname = "DMDatabase_Production-"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$restoredDatabaseName = 'DMDatabase_Azure'
& $fileExe /a:Import /sf:$bacpacname /tdn:$restoredDatabaseName /tsn:"PSE-LT-CHRISU\WIN2019"


##################################################################################################
# Let's carry out a scan to see if there are any fields we may have missed in our Classification #
##################################################################################################

# Check for PII with dbatools PII Scan - Have we missed anything?
$ServName = "PSE-LT-CHRISU\WIN2019"
$DbName = "DMDatabase_Azure"
$Path = "C:\Temp\DMMask\PII.json"
Invoke-DbaDbPiiScan -SqlInstance $ServName -Database $DbName | ConvertTo-Json |Set-Content $Path


##############################################################################
# Now we're happy with what we have to Mask, let's build a masking definiton #
##############################################################################

# Setup Data Masking config with dbatools
$ServName = "PSE-LT-CHRISU\WIN2019"
$DbName = "DMDatabase_Azure"
$Path = "C:\Temp\DMMask\"
New-DbaDbMaskingConfig -SqlInstance $ServName -Database $DbName -Path $Path

# Test the masking file - will it run?
$MaskingFile = 'C:\Temp\DMMask\PSE-LT-CHRISU$WIN2019.DMDatabase_Azure.DataMaskingConfig.json'
Test-DbaDbDataMaskingConfig -FilePath $MaskingFile

# Now we can run the masking
# CODE GOES HERE

#########################################################################################
# Once the masking is complete we can then Clone this to any developer who needs a copy #
#########################################################################################

# Create a masked Image from our example database
# CODE GOES HERE

# Create Clones onto Instance
# CODE GOES HERE
