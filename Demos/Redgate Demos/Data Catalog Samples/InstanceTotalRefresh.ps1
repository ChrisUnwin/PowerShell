###########################################################################################################

$ServerUrl = 'http://PSE-LT-CHRISU:14145' # Set to your Clone server URL
Connect-SqlClone -ServerUrl $ServerUrl # Connect to SQL Clone
$ServerToRefresh = "PSE-LT-CHRISU\TOOLS" #The Source Instance you want to refresh your images of
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName "PSE-LT-CHRISU" -InstanceName "TOOLS" # Instance to use for Image Creation
$ImageDestination = Get-SqlCloneImageLocation -Path "C:\Images" # The location where you store your images

############################################################################################################

$AllImages = Get-SqlCloneImage | Where-Object {$_.OriginServerName -eq $ServerToRefresh} # Fetch all sql clone images for that origin server

$AllImages | ForEach-Object {

    $oldImage = $_
    $oldClones = Get-SqlClone | Where-Object {$_.ParentImageId -eq $oldImage.Id}
    $originDatabase = $_.OriginDatabaseName
    $newImageName = "$originDatabase-$(Get-Date -Format yyyyMMddHHmm)"
    $newImage = New-SqlCloneImage -Name $newImageName `
        -SqlServerInstance $SqlServerInstance `
        -DatabaseName $originDatabase `
        -Destination $ImageDestination
    
    Wait-SqlCloneOperation -Operation $newImage # Create a new image to replace the old image

    foreach ($clone in $oldClones)
    {
        $thisDestination = Get-SqlCloneSqlServerInstance | Where-Object {$_.Id -eq $clone.LocationId} # Get the current Clone location

        Remove-SqlClone $clone | Wait-SqlCloneOperation 

        "Removed clone ""{0}"" from instance ""{1}"" " -f $clone.Name , $thisDestination.Server + '\' + $thisDestination.Instance;

        $ImageToClone = Get-SqlCloneImage -Name $newImageName
        $ImageToClone | New-SqlClone -Name $clone.Name -Location $thisDestination | Wait-SqlCloneOperation # Create a new Image

        "Added clone ""{0}"" to instance ""{1}"" " -f $clone.Name , $thisDestination.Server + '\' + $thisDestination.Instance;
    }

    # Remove the old image
    Remove-SqlCloneImage -Image $oldImage
}