# Catalog instance location
$catalogUri = "http://localhost:15156"
$apikey = "NzQwOTA3OTQxMjU0NjYwMDk2OmNkYWVmNjA5LWI0ZjUtNDA1ZS1hMDEyLWI3MjdmY2RjMTQ5Mw=="
# Target database
$server = "PSE-LT-CHRISU\"
$database = "DMDatabase"
# Files needed by Masker
$logDirectory = "C:\Scripts\MaskerCatalog\Logs"
$mappingFile = "C:\Scripts\MaskerCatalog\mapping.json"
$parfile = "C:\Scripts\MaskerCatalog\PARFILE.txt"
$maskingSet = "C:\Scripts\MaskerCatalog\$database.DMSMaskSet"

# Invoke Data Masker to create set
& ‘C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe’ column-template build-mapping-file `
    --catalog-uri $catalogUri `
    --api-key $apikey `
    --instance $server `
    --database $database `
    --log-directory $logDirectory `
    --mapping-file $mappingFile `
    --sensitivity-category "Treatment Intent" `
    --sensitivity-tag "Static Masking" `
    --information-type-category "Masking Data Set"

& ‘C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe’ build using-windows-auth `
    --mapping-file $mappingFile `
    --log-directory $logDirectory  `
    --instance $server `
    --database $database `
    --masking-set-file $maskingSet `
    --parfile $parfile

# Run generated set if required
# & ‘C:\Program Files\Red Gate\Data Masker for SQL Server 7\DataMaskerCmdLine.exe’ run --parfile $parfile
