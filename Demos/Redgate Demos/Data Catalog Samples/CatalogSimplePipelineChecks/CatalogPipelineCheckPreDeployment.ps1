#### Change this section only ###

$CatalogServer="" # The lcoation of your catalog server, ending on :15156 
$authToken="" # Your Data Catalog Auth token from the Settings page
$instanceName = "" # The instance for your testing / staging database
$databaseName = "" # Your testing / staging database

#### Change this section only ###

If ($CatalogServer.Substring($CatalogServer.length - 1) -eq "/") {$fullUri = $CatalogServer + "powershell"} 
Else {$fullUri = $CatalogServer + "/powershell"}
Invoke-WebRequest -Uri $fullUri -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $authToken"}
Import-Module .\data-catalog.psm1 -Force
Connect-SqlDataCatalog -ServerUrl $CatalogServer -AuthToken $authToken 

Start-ClassificationDatabaseScan -FullyQualifiedInstanceName $instanceName -DatabaseName $databaseName

$UnclassifiedColumns = Get-ClassificationColumn -InstanceName $instanceName -DatabaseName $databaseName | Where-Object {$_.tags.count -eq 0}
$countOfColumns = $UnclassifiedColumns.count 

If ($countOfColumns -eq 0) {
    "You have no columns pending classification on $instanceName/$databaseName"
}
Else {

    "You have $countOfColumns Columns on $instanceName/$databaseName pending classification, please do so before promoting the deployment:"
    $UnclassifiedColumns | Foreach-Object {`
        $_.schemaName + '.' + $_.tableName + '.' + $_.columnName
    }
    Exit 1
}