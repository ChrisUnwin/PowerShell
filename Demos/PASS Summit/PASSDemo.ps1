# Demo PowerShell Script for PASS Summit Demo
# Author: Chris Unwin - Redgate Software - chris.unwin@red-gate.com
# Last Modified Date: 29/10/2019 
# Pre-requisites: Modules: Az (https://www.powershellgallery.com/packages/Az/), dbatools (https://dbatools.io/)


###################################################################################
# Before we download this - let's make sure we have our classifications to hand #
###################################################################################

# Get Classification information from Azure DB
Connect-AzAccount 
Set-AzContext -SubscriptionID "Your Subscription"
$ServerName = "your server name"
$DatabaseName = "your azure sql db"
$Path = "C:\Temp\Classification.json"
Get-AzSqlDatabaseSensitivityClassification -ResourceGroupName "resource group" -ServerName $ServerName -DatabaseName $DatabaseName | ConvertTo-Json | Set-Content $Path


##############################################################################
# Next we need to pull down a copy of our Azure SQL DB for local development #
##############################################################################

# Start export of SQL DB
$AzureUser = "username"
$ServerName = "servername"
$StorageURI = "Your storage URI"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$ExportRequest = New-AzSqlDatabaseExport -DatabaseName "azure sql db name" `
-ServerName $ServerName `
-StorageKeyType "storageaccesskey" `
-StorageKey "your storage key" `
-StorageUri $StorageURI `
-ResourceGroupName "your resource group" `
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
Set-AzContext -SubscriptionID "your sub id"
Write-Output "Downloading bacpac file"
$BacPacBlob = "your azure sql db"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$StorageContext = New-AzStorageContext -StorageAccountName "storge account name" -StorageAccountKey "your storage account key"
Get-AzStorageBlobContent -Container "your storage container" -Blob $BacPacBlob -Context $StorageContext -Destination "C:\temp"

# Import BacPac file as data tier application
$fileExe = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\150\sqlpackage.exe"
$bacpacname = "C:\temp\your azure sql db"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$restoredDatabaseName = 'Your restored db name'
& $fileExe /a:Import /sf:$bacpacname /tdn:$restoredDatabaseName /tsn:"your local server name"


#############################################################################################################
# Optional:  Let's carry out a scan to see if there are any fields we may have missed in our Classification #
#############################################################################################################

# Check for PII with dbatools PII Scan - Have we missed anything?
$ServName = "your local instance"
$DbName = "your local db name"
$Path = "C:\Temp\PII.json"
Invoke-DbaDbPiiScan -SqlInstance $ServName -Database $DbName | ConvertTo-Json |Set-Content $Path


##############################################################################
# Now we're happy with what we have to Mask, let's build a masking definiton #
##############################################################################

# Setup Data Masking config with dbatools
$ServName = "Your local instance"
$DbName = "Local db copy"
$Path = "C:\Temp\"
New-DbaDbMaskingConfig -SqlInstance $ServName -Database $DbName -Path $Path

# Now reduce this to only what we care about - what has been classified
$classificationJsonFileName = "C:\Temp\Classification.json" #replace text with classificaiton json file name
$maskingJsonFileName = "C:\Temp\DMDatabase_Azure.DataMaskingConfig.json" #replace text with masking json file name
$newMaskingJsonFileName = "DMDatabase_Azure.DataMaskingConfig_Filtered.json" #replace text with TARGET masking json file name
$newMaskingJsonFilePath = "C:\Temp\$($newMaskingJsonFileName)"
$classificationJson = Get-Content $classificationJsonFileName | ConvertFrom-Json

$maskingJson = Get-Content $maskingJsonFileName | ConvertFrom-Json

foreach($table in $maskingJson.Tables) {
    foreach($column in $table.Columns) {
        $columnMatches = $false
        foreach($classification in $classificationJson.SensitivityLabels) {
            if($classification.ColumnName -Eq $column.Name -And $classification.TableName -Eq $table.Name -And $classification.SchemaName -Eq $table.Schema ){
                $columnMatches = $true
            }
        }
        if($columnMatches -Eq $false){
            $ccc = [System.Collections.ArrayList]$table.Columns
            $ccc.Remove($column)
            $table.Columns = $ccc
        }
    }
    if($table.Columns.Count -Eq 0){
        $ttt = [System.Collections.ArrayList]$maskingJson.Tables
        $ttt.Remove($table)
        $maskingJson.Tables = $ttt
    }
}

$maskingJson | ConvertTo-Json -depth 100 | Out-File $newMaskingJsonFilePath

# Test the masking file - will it run?
$MaskingFile = "C:\Temp\DMDatabase_Azure.DataMaskingConfig_Filtered.json"
Test-DbaDbDataMaskingConfig -FilePath $MaskingFile 

# Now we can run the masking
$ServName = "Your local instance"
$DbName = "Your local db name"
$MaskingFile = "C:\Temp\DMDatabase_Azure.DataMaskingConfig_Filtered.json"
Invoke-DbaDbDataMasking -SqlInstance $ServName -Database $DbName -FilePath $MaskingFile -Confirm:$false

# Finally restore the ref integrity as well - fan masking out to dependent tables
Invoke-DbaQuery -SqlInstance "Your local instance" -Query "USE Your restored db ; UPDATE dbo.DM_CUSTOMER_NOTES SET customer_firstname = cus.customer_firstname FROM dbo.DM_CUSTOMER cus WHERE cus.customer_id = DM_Customer_Notes.customer_id" 
Invoke-DbaQuery -SqlInstance "Your local instance" -Query "USE your restored db ; UPDATE dbo.DM_CUSTOMER_NOTES SET customer_lastname = cus.customer_lastname FROM dbo.DM_CUSTOMER cus WHERE cus.customer_id = DM_Customer_Notes.customer_id"

#########################################################################################
# Once the masking is complete we can then Clone this to any developer who needs a copy #
#########################################################################################

# Backup & Restore - clean the path first
$ServName = "Your local instance"
$DbName = "Your local db"
$Path = "C:\Temp\Backups"
Remove-Item $Path\*.* 
Start-Sleep -Seconds 3
Backup-DbaDatabase -SqlInstance $ServName -Database $DbName -Type Full -Path $Path 
Start-Sleep -Seconds 10
Restore-DbaDatabase -SqlInstance $ServName `
-Path $Path -DatabaseName "MyCopiedDatabase" `
-DestinationDataDirectory "C:\Program Files\Microsoft SQL Server\MSSQL15.WIN2019\MSSQL\DATA\DMDatabase_Azure_Copy.mdf" `
-DestinationLogDirectory "C:\Program Files\Microsoft SQL Server\MSSQL15.WIN2019\MSSQL\DATA\DMDatabase_Azure_Copy.ldf" 

# Or create a clone of the masked DB schema with same statistics
$ServName = "Your local instance"
$DbName = "Your local db"
Invoke-DbaDbClone -SqlInstance $ServName -Database $DbName -CloneDatabase "MyClone"