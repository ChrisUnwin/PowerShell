# Data Catalog Connection Variables
$authToken = "NzIwODk5NDkyMDg1MjM1NzEyOjE5NGJhNDA1LWM0ODctNGVmOS1iMGZkLTMxOTAzNzliZjdjZA=="
$serverUrl = "http://pse-lt-chrisu:15156"
$WebRequestURI = "http://pse-lt-chrisu:15156/powershell"
$SourceInstanceName = 'PSE-LT-CHRISU\'
$TargetInstanceName = 'PSE-LT-CHRISU\'
$SourceDatabaseName = 'VoiceOfTheDBA_Acceptance'
$TargetdatabaseName = 'VoiceOfTheDBA_Production'

#SQL Change Automation Release Artifact Variables
#$JsonFile = Get-Content -Raw -Path "C:\DatabaseDeploymentResources\TFS\VoiceOfTheDBA\$env:Release.ReleaseName\Acceptance\Reports\Changes.json" | ConvertFrom-Json
$JSONFile = Get-Content -Raw -Path "C:\Users\chris.unwin\Desktop\Changes.json" | ConvertFrom-Json

# Check for any changes and assert if they are table changes
   
   $ModifiedTables = $JSONFile.modifiedObjects.atSource.objectName | Where-Object {$JSONFile.modifiedObjects.objectType -eq "Table"}
   $ModifiedOwners = $JSONFile.modifiedObjects.atSource.owner | Where-Object {$JSONFile.modifiedObjects.objectType -eq "Table"}
   $CreatedTables = $JSONFile.createdObjects.atSource.objectName | Where-Object {$JSONFile.createdObjects.objectType -eq "Table"}
   $CreatedOwners = $JSONFile.createdObjects.atSource.objectOwner | Where-Object {$JSONFile.createdObjects.objectType -eq "Table"}

   # Connect and get existing columns from Data Catalog
   Invoke-WebRequest -Uri $WebRequestURI -OutFile 'data-catalog.psm1' -Headers @{"Authorization"="Bearer $authToken"}
   Import-Module .\data-catalog.psm1 -Force
   Connect-SqlDataCatalog -ServerUrl $serverUrl -AuthToken $authToken 

   Start-ClassificationDatabaseScan -FullyQualifiedInstanceName $SourceInstanceName -DatabaseName $SourceDatabaseName | Wait-SqlDataCatalogOperation
   Start-ClassificationDatabaseScan -FullyQualifiedInstanceName $TargetInstanceName -DatabaseName $TargetDatabaseName | Wait-SqlDataCatalogOperation

   $SourceColumnsMissingClass = @()
   $TargetColumnsMissingClass = @()
   $ColumnsClassInSourceNotInTarget = @()
   $ColumnsNotClassInSourceNotInTarget = @()
   $CatalogSourceColumns = Get-ClassificationColumn -InstanceName $SourceInstanceName -DatabaseName $SourceDatabaseName 
   $CatalogTargetColumns = Get-ClassificationColumn -InstanceName $TargetInstanceName -DatabaseName $TargetDatabaseName 

   foreach ($column in $CatalogTargetColumns) {
        If ($column.sensitivityLabel -and $column.tags )  { Continue }
        Else { $TargetColumnsMissingClass += ("$($column.schemaName).$($column.tableName).$($column.columnName)") }
    }
    foreach ($column in $CatalogSourceColumns) {
        If ($column.sensitivityLabel -or $column.tags )  {
            $Mix = ("$($column.schemaName).$($column.tableName).$($column.columnName)")  
            $ColumnsClassInSourceNotInTarget +=  $Mix | Where-Object {$Mix -in $TargetColumnsMissingClass}
        }
        Else { 
            $Mix = ("$($column.schemaName).$($column.tableName).$($column.columnName)") 
            $SourceColumnsMissingClass += $Mix
            $ColumnsNotClassInSourceNotInTarget +=  $Mix | Where-Object {$Mix -notin $TargetColumnsMissingClass}
        }
    }

    $ColumnsClassInSourceNotInTarget2 = $ColumnsClassInSourceNotInTarget | Select-Object -Unique
    $ColumnsNotClassInSourceNotInTarget2 = $ColumnsNotClassInSourceNotInTarget | Select-Object -Unique
    
   #Get the Columns / Tables that have _changed_ 
   $ModTab = @() 
   If ($ModifiedTables.count -gt 1){
        $i = 0
        While ($i -lt $ModifiedTables.count) {
            $ModTab += $ModifiedOwners[$i] + "." + $ModifiedTables[$i]
            Write-Host "(Information) Table $($ModifiedOwners[$i]).$($ModifiedTables[$i]) was modified in this deployment."  -BackgroundColor green -ForegroundColor black
            $i = $i + 1    
            }
    }
    Elseif ($ModifiedTables.count -eq 1) {
        $ModTab += $ModifiedOwners+"."+$ModifiedTables
        Write-Host "$ModTab was modified in this deployment." -BackgroundColor green -ForegroundColor black
    }
    Else {
        Write-Host "No tables were modified in this deployment." -BackgroundColor green -ForegroundColor black
    }

    #Get the Columns / Tables that have been added 
    If ($CreatedTables.count -gt 1){
        $i = 0
        While ($i -lt $CreatedTables.count) {
            Write-Host "$($CreatedOwners[$i]).$($CreatedTables[$i]) was created in this deployment."  -BackgroundColor green -ForegroundColor black
            $i = $i + 1    
            }
    }
    Elseif ($CreatedTables.count -eq 1) {
        Write-Host "Table $($CreatedOwners).$($CreatedTables) was created." -BackgroundColor green -ForegroundColor black
    }
    Else {
        Write-Host "No tables were created in this deployment." -BackgroundColor green -ForegroundColor black
    }

    #Action: If modified tables contain columns only classified in source, copy classifications up

    If ($ColumnsClassInSourceNotInTarget2.count -gt 0) {
        Write-Host "$($ColumnsClassInSourceNotInTarget2.count) column(s) with classifications were discovered on $($SourceDatabaseName) that are not classified in $($TargetDatabaseName):"`n"$ColumnsClassInSourceNotInTarget2" -BackgroundColor green -ForegroundColor black
        Write-Host "(Action) Copying classifications from $($SourceInstanceName)$($SourceDatabaseName) to $($TargetInstanceName)$($TargetDatabaseName)" -ForegroundColor Black -BackgroundColor Green
        Copy-Classification -sourceInstanceName $SourceInstanceName -sourceDatabaseName $SourceDatabaseName -destinationInstanceName $TargetInstanceName -destinationDatabaseName $TargetdatabaseName | Wait-SqlDataCatalogOperation
    }

    # Action: If Columns exist in source that have not been classified then tell them to classify them : Warning

    If ($ColumnsNotClassInSourceNotInTarget2.count -gt 0) {
        Write-Host "(Warning) The following columns have been discovered on $($SourceDatabaseName) that do not have classifications and are not present in $($TargetDatabaseName):"`n"$ColumnsNotClassInSourceNotInTarget2 "`n"You should classify these columns prior to deployment." -BackgroundColor yellow -ForegroundColor black 
    }
    Else { Write-Host "No columns were discovered on $($SourceDatabaseName) that do not have classifications and are not present in $($TargetDatabaseName)." -BackgroundColor green -ForegroundColor black }

    # Action: If columns exist on the target that have not been classified tell them to classify them : Alert

    If ($TargetColumnsMissingClass.count -gt 0) {
        Write-Host "(Alert) The following columns have been discovered on $($TargetDatabaseName) that require classification:"`n"$TargetColumnsMissingClass "`n"You should classify these columns in $($SourceInstanceName)$($SourceDatabaseName) prior to the next deployment." -BackgroundColor red -ForegroundColor white 
    }
    Else { Write-Host "No columns were discovered on $($TargetDatabaseName) that require classification." -BackgroundColor green -ForegroundColor black }
