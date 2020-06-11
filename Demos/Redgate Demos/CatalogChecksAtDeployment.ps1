# Data Catalog Connection Variables
$authToken = "NzIwNTQ5ODUyODk4OTE4NDAwOjhlNTFhMzY4LTM0MDUtNGVlNi1hNTNkLTViMzExNWMxODE1MA=="
$serverUrl = "http://win2016:15156" 
$instanceName = 'WIN2016'
$TargetdatabaseName = 'VoiceOfTheDBA_Production'
$SourceDatabaseName = 'VoiceOfTheDBA_Acceptance'

#SQL Change Automation Release Artifact Variables
#$JsonFile = Get-Content -Raw -Path "C:\DatabaseDeploymentResources\TFS\VoiceOfTheDBA\$env:Release.ReleaseName\Acceptance\Reports\Changes.json" | ConvertFrom-Json
$JSONFile = Get-Content -Raw -Path "C:\DatabaseDeploymentResources\TFS\VoiceOfTheDBA\Release-37\Integration\Reports\Changes.json" | ConvertFrom-Json

# Check for any changes and assert if they are table changes
If ($JSONFile.ObjectCounts.Created -gt 1 -or $JSONFile.ObjectCounts.Modified -gt 1) {
   
   $ModifiedTables = $JSONFile.modifiedObjects.atSource.objectName
   $ModifiedOwners = $JSONFile.modifiedObjects.atSource.owner
   $CreatedTables = $JSONFile.createdObjects.atSource.objectName
   $CreatedOwners = $JSONFile.createdObjects.atSource.objectOwner

   # Connect and get existing columns from Data Catalog
   Import-Module .\data-catalog.psm1 -Force
   Connect-SqlDataCatalog -ServerUrl $serverUrl -AuthToken $authToken 
   $CatalogColumns = Get-ClassificationColumn -InstanceName $instanceName -DatabaseName $SourceDatabaseName
   
   #Get the Columns / Tables that have _changed_ and check in Data Catalog
   $i = 0
   While ($i -lt $ModifiedTables.count) {
    Write-Host "$($ModifiedOwners[$i]).$($ModifiedTables[$i])"  
    $i = $i + 1    
    }
} 
Else { exit }