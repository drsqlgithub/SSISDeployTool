$Environment = 'DEV' #later, this will be moved to a file named
                     #TOOL_JobsDeploy_DEV.ps1 and Environment will be a param

$BaseDirectory = Get-Location #This script should be portable, so I added the path
                              #dynamically
                              
#get the function scripts
. $BaseDirectory\LibraryFiles\LIBRARY_Defaults.ps1
. $BaseDirectory\LibraryFiles\LIBRARY_Functions.ps1
. $BaseDirectory\LibraryFiles\LIBRARY_Variables_$Environment.ps1
. $BaseDirectory\LibraryFiles\LIBRARY_Variables_Global.ps1


#get the json documents that you will work with

#defines the jobs we have
$DefinitionItemFile = "$BaseDirectory\JOBS_Definition.json"
#defines the dependencies between jobs
$DependencyItemFile = "$BaseDirectory\JOBS_Dependencies.json" 
 #defines the schedules to run jobs
$ScheduleItemFile = "$BaseDirectory\JOBS_Schedules.json"

#Make sure SMO is in path
Add-Type -Path "$G_Smo"

#Get the servername from the variable
$ServerName = environmentvariable_decode('SSISServer');

#call the function 
agent_CreateJobsFromJson -P_ServerName $ServerName -P_DefinitionJsonFile $DefinitionItemFile `
                -P_DependencyJsonFile $DependencyItemFile -P_ScheduleJsonFile $ScheduleItemFile
    

