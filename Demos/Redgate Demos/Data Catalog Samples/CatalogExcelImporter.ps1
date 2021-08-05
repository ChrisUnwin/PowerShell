# This file is intended to classify all columns on sensitive tables on 1 database, regardless of column level sensitivity
# It accepts a CSV file in the format (columns): TableID, SchemaName, TableName & Combination with a '.' e.g. 1       dbo        DM_Customer       dbo.DM_Customer
# Primary/Foreign Keys and Identities will be excluded by default

### FILE OPTIONS ###
$CatalogServer="http://pse-lt-chrisu:15156" # Your SQL Data Catalog location, leave off the trailing "/"
$authToken="ODEzMzU1NjMzNTIzODE4NDk2OjYwMjIzODVkLTA5YWItNDNmZC1iN2RmLTNjZDVlYWNlNTVmNg==" # Your SQL Data Catalog Auth Token
$instance = 'PSE-LT-CHRISU\TOOLS'
$db = "DMDatabaseAutomation" # The DB you want to classify
$CsvFile = "C:\Users\chris.unwin\Desktop\testimport.csv"
$logDirectory = "C:\Scripts\MaskerCatalog\Logs"
$mappingFile = "C:\Scripts\MaskerCatalog\mapping.json"
$parfile = "C:\Scripts\MaskerCatalog\PARFILE.txt"
$maskingSet = "C:\Scripts\MaskerCatalog\$db.DMSMaskSet"
### /FILE OPTIONS ###


# Get the SQL Data Catalog PowerShell Module & Connect
Invoke-WebRequest -Uri "$CatalogServer/powershell" -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $authToken"}
Import-Module .\data-catalog.psm1 -Force
Connect-SqlDataCatalog -ServerUrl $CatalogServer -AuthToken $authToken 

"Data Catalog Connected"

# Open the CSV and import the results into an array
$SensitiveTables = Import-Csv -Path $CsvFile

"$CsvFile imported, $($SensitiveTables.Count) objects counted"

# Get all the columns for the list of sensitive tables
$SensitiveColumns = @()
$toClass = ""
foreach($tab in $SensitiveTables)
{
    $toClass = "$($tab.Combo)"
    "Getting columns for $toClass"
    $SensitiveColumns += Get-ClassificationColumn -InstanceName $instance -DatabaseName $db -TableNamesWithSchemas $toClass
}

# Filter down to just the Data Types we want
"Filtering columns to specified data types"
$ColumnsToClassify = $SensitiveColumns | 
    Where-Object { ($_.dataType -notlike "float*")`
    -and ($_.dataType -notlike "decimal*")`
    -and ($_.dataType -notlike "date*")`
    -and ($_.dataType -notlike "*identi*")`
    -and ($_.dataType -notlike "*money*")`
    -and ($_.dataType -notlike "geography*")`
    -and ($_.dataType -notlike "image*")`
    -and ($_.dataType -notlike "numeric*")`
    -and ($_.dataType -notlike "bigint")`
    -and ($_.columnName -notlike "*id*")
}
"Filtering successful"

# Set the sensitivity in Catalog

"Classifying columns in Data Catalog"
$ColumnsToClassify | Add-ClassificationColumnTag -category "Treatment Intent" -tags @("Static Masking")
"Classification Successful"

# Invoke Data Masker to create set
"Creating Masking Mapping File"
& "C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe" column-template build-mapping-file `
    --catalog-uri $CatalogServer `
    --api-key $authToken `
    --instance $instance `
    --database $db `
    --log-directory $logDirectory `
    --mapping-file $mappingFile `
    --sensitivity-category "Treatment Intent" `
    --sensitivity-tag "Static Masking" 
"Success"
"Creating Masking Set"
& "C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe" build using-windows-auth `
    --mapping-file $mappingFile `
    --log-directory $logDirectory  `
    --instance $instance `
    --database $db `
    --masking-set-file $maskingSet `
    --parfile $parfile
"Success"