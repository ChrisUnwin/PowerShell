# Data Catalog Connection Variables
$authToken = "NzIwODk5NDkyMDg1MjM1NzEyOjE5NGJhNDA1LWM0ODctNGVmOS1iMGZkLTMxOTAzNzliZjdjZA=="
$serverUrl = "http://pse-lt-chrisu:15156" 
$instanceName = 'PSE-LT-CHRISU\'
$SourceDatabaseName = 'VoiceOfTheDBA_Acceptance'
$TargetdatabaseName = 'VoiceOfTheDBA_Production'

#SQL Change Automation Release Artifact Variables
#$JsonFile = Get-Content -Raw -Path "C:\DatabaseDeploymentResources\TFS\VoiceOfTheDBA\$env:Release.ReleaseName\Acceptance\Reports\Changes.json" | ConvertFrom-Json
$JSONFile = Get-Content -Raw -Path "C:\Users\chris.unwin\Desktop\Changes.json" | ConvertFrom-Json

# Check for any changes and assert if they are table changes
If ($JSONFile.ObjectCounts.Created -gt 0 -or $JSONFile.ObjectCounts.Modified -gt 0) {
   
   $ModifiedTables = $JSONFile.modifiedObjects.atSource.objectName | Where-Object {$JSONFile.modifiedObjects.objectType -eq "Table"}
   $ModifiedOwners = $JSONFile.modifiedObjects.atSource.owner | Where-Object {$JSONFile.modifiedObjects.objectType -eq "Table"}
   $CreatedTables = $JSONFile.createdObjects.atSource.objectName | Where-Object {$JSONFile.createdObjects.objectType -eq "Table"}
   $CreatedOwners = $JSONFile.createdObjects.atSource.objectOwner | Where-Object {$JSONFile.createdObjects.objectType -eq "Table"}

   # Connect and get existing columns from Data Catalog
   Invoke-WebRequest -Uri "http://pse-lt-chrisu:15156/powershell" -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $authToken"}
   Import-Module .\data-catalog.psm1 -Force
   Connect-SqlDataCatalog -ServerUrl $serverUrl -AuthToken $authToken 
   $CatalogSourceColumns = Get-ClassificationColumn -InstanceName $instanceName -DatabaseName $SourceDatabaseName 
   $CatalogTargetColumns = Get-ClassificationColumn -InstanceName $instanceName -DatabaseName $TargetDatabaseName 
   
   #Get the Columns / Tables that have _changed_ and check in Data Catalog
    If ($ModifiedTables.count -gt 1){
        $i = 0
        While ($i -lt $ModifiedTables.count) {
            $ModTab = $ModifiedOwners[$i] + "." + $ModifiedTables[$i]

            Write-Host "Table $ModTab was modified."  
            $i = $i + 1    
            }
    }
    Elseif ($ModifiedTables.count -eq 1) {
        Write-Host "$($ModifiedOwners).$($ModifiedTables) was modified."
    }
    Else {
        Write-Host "No tables were created."
    }

    #Get the Columns / Tables that have been added and check in Data Catalog
    If ($CreatedTables.count -gt 1){
        $i = 0
        While ($i -lt $CreatedTables.count) {
            Write-Host "$($CreatedOwners[$i]).$($CreatedTables[$i]) was created."  
            $i = $i + 1    
            }
    }
    Elseif ($CreatedTables.count -eq 1) {
        Write-Host "$($CreatedOwners).$($CreatedTables) was created."
    }
    Else {
        Write-Host "No tables were created."
    }
} Else { Exit }