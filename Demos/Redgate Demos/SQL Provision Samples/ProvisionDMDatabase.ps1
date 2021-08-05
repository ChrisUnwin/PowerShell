# For use on the Redgate Demonstration VM
# Will create a masked image using an existing masking set called DMDatabase_Production
# Created by Chris Unwin 26/11/2019 09:36

# Connect to SQL Clone Server
Connect-SqlClone -ServerUrl 'http://WIN2016:14145'

# Set variables for Image and Clone Location
$SqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName 'WIN2016' -InstanceName ''
$ImageDestination = Get-SqlCloneImageLocation -Path '\\WIN2016\LocalCloneImages'
$MaskingScript = New-SqlCloneMask -Path 'C:\Users\redgate\Documents\Data Masker(SqlServer)\Masking Sets\DMDatabaseMaskFull.DMSMaskSet'

# Create New Masked Image from Clone
New-SqlCloneImage -Name 'DMDatabase_Production' -SqlServerInstance $SqlServerInstance -DatabaseName 'DMDatabase' `
-Modifications @($MaskingScript) `
-Destination $ImageDestination | Wait-SqlCloneOperation

$DevImage = Get-SqlCloneImage -Name 'DMDatabase_Production' 

# Set names for developers to receive Clones
$Devs = @("Dev_Chris", "Dev_Kendra", "Dev_Andreea", "Testing", "UAT", "QA")

# Create New Clones for Devs
$Devs| ForEach-Object { # note - '{' needs to be on same line as 'foreach' !
   $DevImage | New-SqlClone -Name "DMDatabase_$_" -Location $SqlServerInstance 
};