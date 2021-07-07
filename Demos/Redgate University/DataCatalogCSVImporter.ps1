# This file is intended to classify columns on sensitive tables on 1 database
# It accepts a CSV file in the format (columns): ID, SensitiveColumns e.g. 1,dbo.Contacts.customer_firstname
# Primary/Foreign Keys and Identities will be excluded by default

### FILE OPTIONS ###
$CatalogServer="http://pse-lt-chrisu:15156" # Your SQL Data Catalog location, leave off the trailing "/"
$authToken="ODYxNTQ1MjExMjkyMDI0ODMyOjZmZThhNDFjLTNiMjAtNDQ3ZC04ODhkLWY0N2FkZGU5MjdjOQ==" # Your SQL Data Catalog Auth Token
$instance = 'dmnonproduction.database.windows.net'
$db = "DMDatabase_Dev" # The DB you want to classify
$CsvFile = "C:\Users\chris.unwin\Desktop\testimport.csv"
### /FILE OPTIONS ###

# Get the SQL Data Catalog PowerShell Module & Connect
Invoke-WebRequest -Uri "$CatalogServer/powershell" -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $authToken"}
Import-Module .\data-catalog.psm1 -Force
Connect-SqlDataCatalog -ServerUrl $CatalogServer -AuthToken $authToken 

# Open the CSV and import the results into an array
$SensitiveColumns = Import-Csv -Path $CsvFile

# Get all the columns for the list of sensitive tables
$ColumnsFromCatalog = Get-ClassificationColumn -InstanceName $instance -DatabaseName $db 

# Filter down to just common columns

$ColumnsToClassify = @()
foreach ($col in $ColumnsFromCatalog) {
    if (($col.schemaName + '.' + $col.tableName + '.' + $col.columnName) -in  $SensitiveColumns.SensitiveColumns) {
        $ColumnsToClassify += $col
    }
}

# Set the sensitivity in Catalog

$ColumnsToClassify | Add-ClassificationColumnTag -category "Classification Scope" -tags @("In-scope")
$ColumnsToClassify | Add-ClassificationColumnTag -category "Treatment Intent" -tags @("Static Masking")