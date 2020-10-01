# Catalog instance location
$catalogUri = “http://localhost:15156”
$apikey = “NzQwOTA3OTQxMjU0NjYwMDk2OmNkYWVmNjA5LWI0ZjUtNDA1ZS1hMDEyLWI3MjdmY2RjMTQ5Mw==” 
$InstanceToCheck = "PSE-LT-CHRISU\"

# Connect to Catalog and get the PowerShell Module
Invoke-WebRequest -Uri "$catalogUri/powershell" -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $apikey"}
   Import-Module .\data-catalog.psm1 -Force
   Connect-SqlDataCatalog -ServerUrl $catalogUri -AuthToken $apikey

# Get Instances and tags
$ColumnsWithSensitiveTag = @()
 
$Databases = Get-ClassificationDatabase -InstanceName $InstanceToCheck
    
 foreach ($dat in $Databases) {
    
      $ListOfColumns = Get-ClassificationColumn -Instance $InstanceToCheck -Database $dat.name 
      $ColumnsWithSensitiveTag += ($ListOfColumns.schemaName + "." + $ListOfColumns.tableName + "." + $ListOfColumns.columnName) | Where-Object ($ListOfColumns -Contains "7 Yr financial")

 }
 Write-Output $ColumnsWithSensitiveTag
