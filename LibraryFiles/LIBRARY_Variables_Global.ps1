#######################################################################################################
## This file contains arrays of variables that are useful for indirection, but are the same in every
## environment
#######################################################################################################

#Paths
$Global:ArtifactDirectory = "E:\DeploymentArtifacts\Jobs"

#These are databases we work with, along with the server that they reside on
$Global:DatabaseNameArray = New-Object 'object[,]' 100,4

#item 1 - the name that we will reference in code
#item 2 - the actual name of the database
#item 3 - the server where it is located, pulled from global list
#item 3 - the database where a snapshot would actually exist

$DatabaseNameArray[0,0] = "SSISHelper" 
$DatabaseNameArray[0,1] = "SSISHelper" 
$DatabaseNameArray[0,2] = environmentvariable_decode("SSISServer"); #must decode value from the environment level list
