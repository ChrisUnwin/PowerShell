#### Change this section only ###

$CatalogServer="" # The lcoation of your catalog server, ending on :15156 
$authToken="" # Your Data Catalog Auth token from the Settings page
$sourceInstanceName = "" 
$targetInstanceName = ""
$sourceDatabaseName = ""
$targetDatabaseName = ""

#### Change this section only ###

If ($CatalogServer.Substring($CatalogServer.length - 1) -eq "/") {$fullUri = $CatalogServer + "powershell"} 
Else {$fullUri = $CatalogServer + "/powershell"}
Invoke-WebRequest -Uri $fullUri -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $authToken"}
Import-Module .\data-catalog.psm1 -Force
Connect-SqlDataCatalog -ServerUrl $CatalogServer -AuthToken $authToken 

Start-ClassificationDatabaseScan -FullyQualifiedInstanceName $targetInstanceName -DatabaseName $targetDatabaseName

Copy-Classification -SourceInstanceName $sourceInstanceName -DestinationInstanceName $targetInstanceName `
 -SourceDatabaseName $sourceDatabaseName -DestinationDatabaseName $targetDatabaseName