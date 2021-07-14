#The below script is intended to be used with SQL Code Guard Command line and has been written for v4
#A scripts folder could be imported insteadof a database, change the code accordingly
#To use SQL Auth, uncomment the user and password variables and the switches in the cmdline call

#Set Path for Code Guard, server/instance, database and output location for XML
$codeGuardPath = "C:\Users\chris.unwin\Downloads\SCG-2019-10-17-11-40-22-46"
$server = "REDACTED"
$database = "REDACTED"
$outLocation = "$codeGuardPath\myoutput.xml"
#$user = "REDACTED"
#$password = "REDACTED"

#Invoke SQL Code Guard against the DB (could be the Build Database)
& "$codeGuardPath\SqlCodeGuard.Cmd.exe" /s:$server /d:$database /out:$outLocation #/u:$user /p:$password

#Import output xml file and count contents
$blah = [xml](Get-Content -Path $outLocation)
$files = $blah.SelectNodes('//file')
$issues = $blah.SelectNodes('//file/issue')

#If number of issues > zero, exit with non-zero exit code and output list of affected objects
if ( $issues.count -gt 0 ) {

    "You have: " + $files.count + " objects, containing a total of: " + $issues.count + " issues."
    $files.fullname
    "Please review the xml output for more information."

    exit 1

}

#Else continue with no issues
else {

    "No code issues discovered."

}