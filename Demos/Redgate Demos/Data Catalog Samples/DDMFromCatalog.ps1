# Author Chris Unwin 15/07/2021 17:15
# This script is intended to be used with Azure SQL Database and Redgate SQL Data Catalog, however you are welcome to adapt and edit as required
# It will pull columns out of azure that are already being masked, and a list of columns that need to be masked with DDM
# It will then rationalise these, and configure Default DDM masks for any columns not already being masked on that Azure SQL DB

#Variables for Azure SQL DB & Catalog
$ResourceGroup = "DMDb"
$ServerName = "dmnonproduction" # Your instance minus .database.windows.net
$instance = "dmnonproduction.database.windows.net" # The instance or logical SQL Server as displayed in SQL Data Catalog
$DatabaseName = "DMDatabase_Dev"
$CatalogServer="http://pse-lt-chrisu:15156" # Your SQL Data Catalog location, leave off the trailing "/"
$authToken="REDACTED" # Your SQL Data Catalog Auth Token
$AzureSub = "Redacted" # Your Sub ID

# Get the SQL Data Catalog PowerShell Module & Connect
Invoke-WebRequest -Uri "$CatalogServer/powershell" -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $authToken"}
Import-Module .\data-catalog.psm1 -Force
Connect-SqlDataCatalog -ServerUrl $CatalogServer -AuthToken $authToken 

#Connect to your Azure Subscription
Connect-AzAccount -Subscription $AzureSub

#Get current active DDM Masks from Azure
$DdmMasks = Get-AzSqlDatabaseDataMaskingRule `
    -ResourceGroupName $ResourceGroup `
    -ServerName $ServerName `
    -DatabaseName $DatabaseName
$ListOfDDMColumns = $DdmMasks | ForEach-Object {$_.SchemaName + '.' + $_.TableName + '.' + $_.ColumnName}

#Get columns from Catalog currently marked with "Dynamic Data Masking" as a treatment intent
$CatalogColumns = Get-ClassificationColumn `
    -InstanceName $instance `
    -DatabaseName $DatabaseName | Where-Object {$_.tags.name -eq "Dynamic data masking"} 

#Filter down to a list of columns that need to be masked, that currently aren't configured with DDM
$ColumnsToDDM = $CatalogColumns | Where-Object {($_.SchemaName + '.' + $_.TableName + '.' + $_.ColumnName) -notin $ListOfDDMColumns }


#Set default DDM Masks for identified columns
$ColumnsToDDM | ForEach-Object { `
    New-AzSqlDatabaseDataMaskingRule -ResourceGroupName $ResourceGroup `
                                     -ServerName $ServerName `
                                     -DatabaseName $DatabaseName  `
                                     -SchemaName $_.schemaName `
                                     -TableName $_.tableName `
                                     -ColumnName $_.columnName `
                                     -MaskingFunction "Default"

}