# Data Catalog Connection Variables
$authToken = ""
$serverUrl = "" 
$instanceName = ''
$TargetdatabaseName = ''
$SourceDatabaseName = ''

#SQL Change Automation Release Artifact Variables
#$JsonFile = Get-Content -Raw -Path "C:\DatabaseDeploymentResources\TFS\VoiceOfTheDBA\$env:Release.ReleaseName\Acceptance\Reports\Changes.json" | ConvertFrom-Json
$JSONFile = Get-Content -Raw -Path "...\Changes.json" | ConvertFrom-Json

# Check for any changes and assert if they are table changes
If ($JSONFile.ObjectCounts.Created -gt 1 -or $JSONFile.ObjectCounts.Modified -gt 1) {

   # Connect and get existing columns from Data Catalog
   Connect-SqlDataCatalog -ServerUrl $serverUrl -AuthToken $authToken 
   $CatalogColumns = Get-ClassificationColumn -InstanceName $instanceName -DatabaseName $SourceDatabaseName
   $ChangedTables = 

   Foreach ($Table in $ChangedTables) {
        #Get the Columns / Tables that have changed and check in Data Catalog
        
    }
} 
Else { exit }