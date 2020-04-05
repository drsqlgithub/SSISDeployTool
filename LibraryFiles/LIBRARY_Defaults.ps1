##############################################
#Default values used system-wide
##############################################

#When no category is included on the job, use this one
$Global:G_DefaultJobCategory = "ManagedAgentJob"

#display lots of Write-Host messages to help the user see progress
$global:G_VerboseDetail = $True;

##############################################
#Location of code used in processing
##############################################

#The template of the shapes used for graphing
$Global:G_VisioTempate = "$BaseDirectory\VisioShapes\SSISDeployShapes.vssx"

#The location of SMO being used. 
$Global:G_Smo = "C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap\SQL2019\x64\Microsoft.SqlServer.Smo.dll"