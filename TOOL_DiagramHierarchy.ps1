
#get the function scripts
. $BaseDirectory\LibraryFiles\LIBRARY_Locations.ps1
. $BaseDirectory\LibraryFiles\LIBRARY_Functions.ps1

#display lots of Write-Host messages to help the user see progress
$global:G_VerboseDetail = $True;

#get the json documents that you will work with
$DefinitionItemFile = "$BaseDirectory\JOBS_Definition.json" #defines the jobs we have
$DependencyItemFile = "$BaseDirectory\JOBS_Dependencies.json" #defines the dependencies between jobs
$ScheduleItemFile = "$BaseDirectory\JOBS_Schedules.json" #defines the schedules to run jobs

#In a future change, I will add a validation step to the process to make sure things
#are configured as desired (no self dependencies, duplicate jobs, etc)

#Draw the diagram 
if ($VerboseDetail){Write-Host "Starting SSIS_DrawHierarchInVisio"};
SSIS_DrawHierarchyInVisio $DefinitionItemFile $DependencyItemFile $ScheduleItemFile