$authToken = "blahblahblahblahblahblah" # Your authToken from Data Catalog
$serverUrl = "http://yourserver:15156" # The fully qualified server URL for SQL Data Catalog, missing the trailing forward slash ('/')
$instanceName = 'Your Fully Qualified Instance Name' # As it appears in SQL Data Catalog
$databaseName = 'DMDatabase2019' # The database you're checking
$unusedTag = "Out of Scope - Unused" # The Out Of Scope Unused Tag
 
# Get the PowerShell module for Data Catalog

Invoke-WebRequest -Uri "$serverUrl/powershell" -OutFile 'data-catalog.psm1' `
    -Headers @{"Authorization" = "Bearer $authToken" }
 
Import-Module .\data-catalog.psm1 -Force
 
# Connect to your SQL Data Catalog instance - you'll need to generate an auth token in the UI
Connect-SqlDataCatalog -AuthToken $authToken -ServerUrl $serverUrl

# Quickly refresh the scan of the Instance to get accurate row counts
Start-ClassificationDatabaseScan -FullyQualifiedInstanceName $instanceName -DatabaseName $databaseName | Wait-SqlDataCatalogOperation

# Get all columns into a collection & create a collection for already tagged items
$allColumns = Get-ClassificationColumn -instanceName $instanceName -databaseName $databaseName
$emptyTableColumns = $allColumns | Where-Object { $_.tableRowCount -eq 0 }

# Collection for columns that are tagged as empty
$ColumnstaggedAsEmpty = $allColumns | Where-Object { $_.tags.name -eq $unusedTag }

# Collections for columns both tagged as empty but not, and empty columns not tagged as such
$ColumnsNowInUse = $ColumnstaggedAsEmpty | Where-Object { $_.id -notin $emptyTableColumns.id}
$ColumnsMissingClassification = $emptyTableColumns | Where-Object { $_.id -notin $ColumnstaggedAsEmpty.id}

# Report back to the user the state of unused tables
If ($ColumnsNowInUse.id.count -gt 0) {
    "You have " + $ColumnsNowInUse.id.count + " columns classified as Out of Scope - Unused, now populated with Data:"
    $ColumnsNowInUse | ForEach-Object {"$($_.schemaName).$($_.tableName).$($_.columnName)"}
}
Else {"You have 0 columns classified as Out of Scope - Unused, now populated with Data."}

If ($ColumnsMissingClassification.id.count -gt 0) {
    "You have " + $ColumnsMissingClassification.id.count + " columns currently with no data missing the Out of Scope - Unused tag:"
    $ColumnsMissingClassification | ForEach-Object {"$($_.schemaName).$($_.tableName).$($_.columnName)"}
}
Else {"You have 0 columns currently with no data missing the Out of Scope - Unused tag."}