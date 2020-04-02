$Environment = 'DEV'

$BaseDirectory = Get-Location #This script should be portable, so I added the path
                              #dynamically
                              
#get the function scripts
. $BaseDirectory\LibraryFiles\LIBRARY_Functions.ps1
. $BaseDirectory\LibraryFiles\LIBRARY_Variables_$Environment.ps1
. $BaseDirectory\LibraryFiles\LIBRARY_Variables_Global.ps1

Write-Host '----------------------'

$SSISServer = environmentvariable_decode('SSISServer');
$AlertEmailAddress = environmentvariable_decode('General_AlertEmailAddress');
$DeploySSISServerLogFileDirectory = environmentvariable_decode('DeploySSISServerLogFileDirectory')

Write-Host $SSISServer;
Write-Host $AlertEmailAddress;
Write-Host $DeploySSISServerLogFileDirectory


Write-Host '----------------------'

$SSISDB = databasename_decode('SSISHelper')
$SSISDBServer = databaseServer_decode('SSISHelper')
$SSISDBConnectionString = databasename_getconnectionStringSMO('SSISHelper')

write-Host $SSISDB
write-Host $SSISDBServer
Write-Host $SSISDBConnectionString

Write-Host '----------------------'