### CHANGE THIS ###

$MaskingSet = "yourmaskingset.DMSMaskSet" # Your masking set including the DMSMaskSet file extension
$instance = "yourinstance" # The Instance as it is shown in Data Catalog that hosts the database
$DatabaseName = "yourdatabase" # The DB you want classification info for
$CatalogServer="http://yourmachine:15156" # The lcoation of your catalog server, ending on :15156
$authToken="redacted" # Your Data Catalog Auth token from the Settings page
$tagName = "Static Masking" # The tag you're using to identify which columns need to be masked

### DONT CHANGE THIS ###

Invoke-WebRequest -Uri "$CatalogServer/powershell" -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $authToken"}
Import-Module .\data-catalog.psm1 -Force
Connect-SqlDataCatalog -ServerUrl $CatalogServer -AuthToken $authToken 
$ColumnsMarkedForMasking = Get-ClassificationColumn `
    -InstanceName $instance `
    -DatabaseName $DatabaseName | Where-Object {$_.tags.name -eq $tagName} 
$MaskingSetXML = [xml](Get-Content -Path $MaskingSet)
$subrules = $MaskingSetXML.SelectNodes('//DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleSubstitution')
$internalrules = $MaskingSetXML.SelectNodes('//DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleRowInternal')
$shufflerules = $MaskingSetXML.SelectNodes('//DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleShuffle')
$searchreplacerules = $MaskingSetXML.SelectNodes('//DMSSetContainer_MaskingSet/DMSSetContainer/DMSRuleBindingList/RuleSearchReplace')
$TablesAndColumns = @()

$subrules | ForEach-Object {`
    $CurrentTable = $_.TargetTableName.value
    $_.DMSPickedColumnAndDataSetCollection.DMSPickedColumnAndDataSet.N2KSQLServerEntity_PickedColumn.ColumnName.value | ForEach-Object {$TablesAndColumns+= $CurrentTable + "." + $_ }
}

$internalrules | ForEach-Object {`
    $TablesAndColumns+= $_.TargetTableName.value + "." + $_.TargetColumnName.value
}

$shufflerules | ForEach-Object {`
    $CurrentTable = $_.TargetTableName.value
    $_.DMSPickedColumnCollection.DMSPickedColumn.N2KSQLServerEntity_PickedColumn.ColumnName.value | ForEach-Object {$TablesAndColumns+= $CurrentTable + "." + $_ }
}

$searchreplacerules | ForEach-Object {`
    $TablesAndColumns+= $_.TargetTableName.value + "." + $_.TargetColumnName.value
}

$result = $TablesAndColumns | Sort -Unique
$ColumnsNeedingRules = $ColumnsMarkedForMasking | Where-Object {($_.tableName + "." + $_.columnName) -notin $result}

"`nThere are " + $ColumnsMarkedForMasking.count + " columns that require masking for database " + $DatabaseName + "in SQL Data Catalog."
"You are masking " + $result.count + " distinct columns in masking set: " + $MaskingSet
"`nThe columns that do not currently have a mask configured are:`n"

$ColumnsNeedingRules | ForEach-Object {$_.tableName + "." + $_.columnName + "     (" + $_.dataType + ")"}

$next = Read-Host -Prompt "`nWould you like to see the columns currently in your masking set? (Y/N)"
if ($next -in ("Y", "y")) {$result}