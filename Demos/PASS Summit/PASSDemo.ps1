# Demo PowerShell Script for PASS Summit Demo
# Author: Chris Unwin - Redgate Software - chris.unwin@red-gate.com
# Last Modified Date: 29/10/2019 
# Pre-requisites: Modules: Az (https://www.powershellgallery.com/packages/Az/), dbatools (https://dbatools.io/)


###################################################################################
# Before we download this - let's make sure we have our classifications to hand #
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
$BacPacBlob = "DMDatabase_Production"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$StorageContext = New-AzStorageContext -StorageAccountName "dmstoragechris" -StorageAccountKey "LdkmJkNntY+c4Mu2++He2D//QavZFL7b0I50tkJYsESujoGpXhNpF2eRoHNc3ZoW9iRS5QIYlfa2oBrKQiFBgQ=="
Get-AzStorageBlobContent -Container "dmblobstore" -Blob $BacPacBlob -Context $StorageContext -Destination "C:\Users\chris.unwin\Documents\BACPACs"

# Check for existance of Imported BacPac and remove if exists
#Invoke-DbaQuery -SqlInstance "PSE-LT-CHRISU\WIN2019" -Query "DROP DATABASE IF EXISTS DMDatabase_Azure;"

# Import BacPac file as data tier application
$fileExe = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\Extensions\Microsoft\SQLDB\DAC\150\sqlpackage.exe"
$bacpacname = "C:\Users\chris.unwin\Documents\BACPACs\DMDatabase_Production"+ [datetime]::Today.ToString('yyyy-MM-dd') +".bacpac"
$restoredDatabaseName = 'DMDatabase_Azure'
& $fileExe /a:Import /sf:$bacpacname /tdn:$restoredDatabaseName /tsn:"PSE-LT-CHRISU\WIN2019"


#############################################################################################################
# Optional:  Let's carry out a scan to see if there are any fields we may have missed in our Classification #
#############################################################################################################

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

# Delete old copies then rename the masking file to something more friendly
Remove-Item -Path "C:\Temp\DMMask\DMDatabase_Azure.DataMaskingConfig.json" | Wait-Process
Remove-Item -Path "C:\Temp\DMMask\DMDatabase_Azure.DataMaskingConfig_Filtered.json" | Wait-Process
Rename-Item -Path 'C:\Temp\DMMask\PSE-LT-CHRISU$WIN2019.DMDatabase_Azure.DataMaskingConfig.json' -NewName "DMDatabase_Azure.DataMaskingConfig.json"

# Now reduce this to only what we care about - what has been classified
$classificationJsonFileName = "C:\Temp\DMMask\Classification.json" #replace text with classificaiton json file name
$maskingJsonFileName = "C:\Temp\DMMask\DMDatabase_Azure.DataMaskingConfig.json" #replace text with masking json file name
$newMaskingJsonFileName = "DMDatabase_Azure.DataMaskingConfig_Filtered.json" #replace text with TARGET masking json file name
$newMaskingJsonFilePath = "C:\Temp\DMMask\$($newMaskingJsonFileName)"
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
$MaskingFile = "C:\Temp\DMMask\DMDatabase_Azure.DataMaskingConfig_Filtered.json"
Test-DbaDbDataMaskingConfig -FilePath $MaskingFile 

# Now we can run the masking
$ServName = "PSE-LT-CHRISU\WIN2019"
$DbName = "DMDatabase_Azure"
$MaskingFile = "C:\Temp\DMMask\DMDatabase_Azure.DataMaskingConfig_Filtered.json"
Invoke-DbaDbDataMasking -SqlInstance $ServName -Database $DbName -FilePath $MaskingFile -Confirm:$false

#########################################################################################
# Once the masking is complete we can then Clone this to any developer who needs a copy #
#########################################################################################

# Create a masked Image from our example database
# CODE GOES HERE

# Create Clones onto Instance
# CODE GOES HERE
