#######################################################################################################
## This file contains an array of variables that are built by environment. There will be one of these
## files per environment and ALL localization of variables shall go in this file 
#######################################################################################################

#The format of this array is:
#Index,0 - Name of the variable
#Index,1 - The value of the variable

#NOTE: It is important to make sure these values are unique at the Index,0 level.
#      This file is going to be complex to maintain, 
#      so be very careful and follow the rules.

$Global:EnvironmentVariableArray = New-Object 'object[,]' 40,2 #Make sure the first index is large enough for the values that you have stored. 

#Order Doesn't Matter, as long as you don't reuse an index (that would overwrite the value)

$EnvironmentVariableArray[0,0] = "SSISServer" 
$EnvironmentVariableArray[0,1] = "." 

#-------------------------------------------------------------------------------
# Deployment variables

$EnvironmentVariableArray[29,0] = "DeploySSISServerLogFileDirectory" 
$EnvironmentVariableArray[29,1] = "E:\MSSQL\JobLogs\"

#-------------------------------------------------------------------------------
# General variables

$EnvironmentVariableArray[33,0] = "General_AlertEmailAddress" 
$EnvironmentVariableArray[33,1] = "drsql@hotmail.com"

$EnvironmentVariableArray[34,0] = "General_OperatorOnCall" 
$EnvironmentVariableArray[34,1] = "OnCall"
