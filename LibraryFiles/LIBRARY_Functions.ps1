#######################
# This file will have many of the functions needed for all of the deployment work I will be implementing
#######################
<#
function functionname($P_Parameter1) {
    Try {

    }
        Catch {
            Write-Error $_
            write-host "Error adding schedule to $P_JobName";
            THROW
        }
}
#>

function SQLAgent_FormName ($P_SystemName, $P_SubSystemName, $P_EnvironmentName, $P_JobStartType) {
    #The name of the agent job is used as the handle to access it in many places. If you want
    #to use a different form of the name, this is where you would locate it
    write-host "$NamePrefix-$P_SystemName-$P_SubSystemName-$P_EnvironmentName (Managed)"
    try {
        #prefix with TRIGGERED or SCHEDULED, the let the user know which jobs are supposed
        #to start on their own
        $NamePrefix = $P_JobStartType.ToUpper()
        
        #the (Managed) suffix will be used when we go to delete and recreate jobs in bulk"
        if ($G_VerboseDetail) {
            write-host "Defined name $NamePrefix-$P_SystemName-$P_SubSystemName-$P_EnvironmentName (Managed)"
        }
        Return("$NamePrefix-$P_SystemName-$P_SubSystemName-$P_EnvironmentName (Managed)")
    }
    catch {
        Write-Error $_
        write-host  'Error formatting SQL Agent job name'   
        throw
    }
}

function global:environmentvariable_decode ($P_itemName) {
    <#
    Used to decode an environment variable reference into its actual value. Environment variables are loaded
    in the Variables_%EnvironmentName% area, allowing for a different version in dev, prod, etc
    #>
    $items = $EnvironmentVariableArray.Count;
    for ($i = 0; $i -lt $items ; $i++) {
        #if the 0 position value matches (the name), then use the 1 postion as the return value
        if ($P_itemName -eq $EnvironmentVariableArray[$i, 0]) {
            $output = $EnvironmentVariableArray[$i, 1]
        }
    }
    if (!$output) {
        Write-Error "The array token passed in: [$P_itemName] was not found in the environment variable global array"
        Throw
    }
    else {
        return $output;
    }
};

function global:databasename_decode ($P_databaseName) {
    <#
    Used to decode an database name variable reference into its actual value. Environment variables are loaded
    in the Variables_Global file
    #>
    
    $items = $DatabaseNameArray.Count;

    for ($i = 0; $i -lt $items; $i++) {
        if ($P_databaseName -eq $DatabaseNameArray[$i, 0]) {
            $output = $DatabaseNameArray[$i, 1]
        }
    }
    if (!$output) {
        Write-Error "The database array token passed in: [$P_databaseName] was not found in the database global array"
        Throw;
    }
    else {
        return $output;
    }
};    

function global:databaseServer_decode ($P_databaseName) {
    <#
    Used to decode an database name and return its physical database name. Environment variables are loaded
    in the Variables_Global file
    #>
    $items = $DatabaseNameArray.Count;

    for ($i = 0; $i -lt $items; $i++) {
        if ($P_databaseName -eq $DatabaseNameArray[$i, 0]) {
            $output = $DatabaseNameArray[$i, 2] #Server entry
        }
    }
    if (!$output) {
        Write-Error "The database array token passed in: [$P_databaseName] was not found in the database global array"
        Throw;
    }
    else {
        return $output;
    }
};  
function global:databasename_getconnectionStringSMO ($P_databaseName) {
    <#
    Used to for a connection string for the databse variable reference. Database 
    variables are located in the Variables_Global file, but their environment based 
    location is loaded into the array during initialization
    #> 
    $serverName = databaseServer_decode($P_databasename);
    $physicaldatabaseName = databasename_decode($P_databasename)

    $connectionString = "Server=" + $serverName + ";Database=" +
    $physicaldatabaseName + ";Trusted_Connection=True;"

    return $connectionString;
};

function SSIS_DrawHierarchyInVisio ($P_DefinitionJsonFile, $P_DependencyJsonFile, $P_SchedulesJsonFile) {
    #Required: 
    #   1. Install Visio to your machine
    #   2. In Powershell run: install-module visio as administrator

    #Minimal File Formats for this function:
    #$P_DefinitionItems Jobs:(SystemName, SubsystemName, EnvironmentName)
    #$P_DependencyItems JobDependency:(SystemName, SubsystemName, EnvironmentName, 
    #DependsOnSystemName, DependsOnSubsystemName, DependsOnEnvironmentName)
    #$P_ScheduleItems JobSchedule:(SystemName, SubsystemName, EnvironmentName)

    TRY {
        if ($G_VerboseDetail) {
            Write-Host "SSIS_DrawHierarchInVisio $P_DefinitionJsonFile,$P_DependencyJsonFile,$P_SchedulesJsonFile"
        }
        
        #Opens Visio you should see the window open
        New-VisioApplication

        #Adds a document to the Visio window
        $VisioDoc = New-VisioDocument
        
        #now the shapes are added to the window
        $viShapes = Open-VisioDocument -Filename $G_VisioTempate

        #Set shape we will use for the job
        $ParentItem = $viShapes.Masters.Item("ParentNode")
        $ChildItem = $viShapes.Masters.Item("ChildNode")
        $connector = $viShapes.Masters.item("RightDirectedConnection")

        #Set context to a page for later use
        $Page = $VisioDoc.Pages[1]

        #Open the JSON files
        $DependencyItems = Get-Content $P_DependencyJsonFile | ConvertFrom-Json 
        $DefinitionItems = Get-Content $P_DefinitionJsonFile | ConvertFrom-Json 
        $ScheduleItems = Get-Content $P_SchedulesJsonFile | ConvertFrom-Json 

        #Loop through the nodes items, and create a node on the diagram
        if ($G_VerboseDetail) {
            Write-Host "Creating Nodes"
        }
        $itemsI = $DefinitionItems.Jobs.Count
            
        for ($i = 0; $i -lt $itemsI ; $i++) {
            #fetch the three name parts (if your folder and project names differ, you can easily add that)
            $L1_SystemName = $DefinitionItems.Jobs[$i].SystemName
            $L1_SubsystemName = $DefinitionItems.Jobs[$i].SubsystemName
            $L1_EnvironmentName = $DefinitionItems.Jobs[$i].EnvironmentName

            #give the shape a name. The text may differ
            $ShapeName = "$L1_SystemName-$L1_SubsystemName-$L1_EnvironmentName"
            $ShapeText = "$L1_SystemName $L1_SubsystemName $L1_EnvironmentName"

            #This subloop tells me if the item has a schedule. A scheduled node is a root node to the directed graph
            #so I make it look different
            $ItemsJ = $ScheduleItems.JobSchedule.Count
            $DrawingItem = $ChildItem #default to it being a child node
            for ($j = 0; $j -lt $itemsJ ; $j++) {
                
                $L11_SystemName = $ScheduleItems.JobSchedule[$j].SystemName
                $L11_SubsystemName = $ScheduleItems.JobSchedule[$j].SubsystemName
                $L11_EnvironmentName = $ScheduleItems.JobSchedule[$j].EnvironmentName
        
                IF ($L11_SystemName -eq $L1_SystemName -And $L11_SubSystemName -eq $L1_SubSystemName -And $L11_EnvironmentName -eq $L1_EnvironmentName ) {
                    $DrawingItem = $ParentItem #Make the node look like a parent node if a row matched;
                    break; #can stop because it is already a parent
                }
                else {
                }
            }
            #drop the item on the canvas anywhere, we will redraw
            $Shape = $Page.drop($DrawingItem, 1.0, 1.0)
            #set the text and name of the shape
            $Shape.Text = "$ShapeText"
            $Shape.Name = "$ShapeName"
        }
        if ($G_VerboseDetail) {
            Write-Host "Creating Edges"
        }
        
        #dependencies are predecessors in the chain
        $itemsI = $DependencyItems.JobDependency.Count
        for ($i = 0; $i -lt $itemsI ; $i++) {
            #this is the child node
            $L2_SystemName = $DependencyItems.JobDependency[$i].SystemName
            $L2_SubsystemName = $DependencyItems.JobDependency[$i].SubsystemName
            $L2_EnvironmentName = $DependencyItems.JobDependency[$i].EnvironmentName

            #this is the node that must finish first in the calling hierarchy
            $L2_DependsOnSystemName = $DependencyItems.JobDependency[$i].DependsOnSystemName
            $L2_DependsOnSubsystemName = $DependencyItems.JobDependency[$i].DependsOnSubsystemName
            $L2_DependsOnEnvironmentName = $DependencyItems.JobDependency[$i].DependsOnEnvironmentName

            #Format the names of the shapes for referencing
            $ShapeName = "$L2_SystemName-$L2_SubsystemName-$L2_EnvironmentName"
            $DependsOnShapeName = "$L2_DependsOnSystemName-$L2_DependsOnSubsystemName-$L2_DependsOnEnvironmentName"

            #add a connector from the DependsOnShapeName to the Shape
            $Page.Shapes["$DependsOnShapeName"].AutoConnect($Page.Shapes["$ShapeName"], 0, $Connector)
        }

        #Layout the diagram as a flowchart. A good starting point, but even in this example not enough
        $LayoutStyle = New-Object VisioAutomation.Models.LayoutStyles.FlowchartLayoutStyle
        #Apply the format, and I made it Landscape for wider models
        Format-VisioPage -LayoutStyle $LayoutStyle -Orientation "Landscape" 
        if ($G_VerboseDetail) {
            Write-Host "Diagram completed and created in a Seperate Window, Not Saved."
        }
    }
    catch {
        Write-Error $_
        Write-Host "Something is incorrect in the JOBS_BuildBaseFile"
        Throw
    }
}

function agent_maintainCategory ($P_AgentServerName, $P_CategoryName) {
    Try {
        #Connect to the SQL Server, you will need to be using a trusted connection here.            
        $SQLServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server("$P_AgentServerName") 
        
        #variable for the jobserver
        $JobServer = $SQLServer.JobServer

        #grab the job category by name that was passed in
        $Category = $JobServer.JobCategories["$P_CategoryName"] 
        #if it wasn't found, add it
        if (!$Category) {
            #create the new category
            $NewCategory = New-Object `
            ('Microsoft.SqlServer.Management.Smo.Agent.JobCategory')`
            ($JobServer, "$P_CategoryName")
            #This was really hard for me. There is a JobCategories collection too... But you add
            #the new Category here.
            $NewCategory.Create()
        
            if ($G_VerboseDetail) {
                Write-Host "Added category name: $NewCategory"
            }
        }
    }      
    catch {
        Write-Error $_
        Write-Host "Something failed handling the category $P_CategoryName"
        Throw;
    }
}

function agent_CreateJobsFromJson ($P_ServerName, $P_DefinitionJsonFile, $P_DependencyJsonFile, $P_ScheduleJsonFile) {
    TRY {
   
        #Open the JSON files
        $DefinitionItems = Get-Content $P_DefinitionJsonFile | ConvertFrom-Json 
        $ScheduleItems = Get-Content $P_ScheduleJsonFile | ConvertFrom-Json 
        $DependencyItems = Get-Content $P_DependencyJsonFile | ConvertFrom-Json 

        #Loop through the nodes items, and create a node on the diagram
        if ($G_VerboseDetail) {
            Write-Host "Creating Jobs"
        }
        $itemsI = $DefinitionItems.Jobs.Count
        
        for ($i = 0; $i -lt $itemsI ; $i++) {
            #fetch the three name parts (if your folder and project names differ,
            #     you can easily add that)
            $L1_SystemName = $DefinitionItems.Jobs[$i].SystemName
            $L1_SubsystemName = $DefinitionItems.Jobs[$i].SubsystemName
            $L1_EnvironmentName = $DefinitionItems.Jobs[$i].EnvironmentName
            $L1_JobCategory = $DefinitionItems.Jobs[$i].JobCategory
            $L1_JobStartType = $DefinitionItems.Jobs[$i].JobStartType
            $L1_JobDescription = $DefinitionItems.Jobs[$i].JobDescription
            $L1_JobType = $DefinitionItems.Jobs[$i].JobType
            $L1_JobCodeText = $DefinitionItems.Jobs[$i].JobCodeText
            $L1_JobCodeDatabase = $DefinitionItems.Jobs[$i].JobcodeDatabase

            #if JobCategory is not included, use the default
            if (!$L1_JobCategory) {
                $L1_JobCategory = $G_DefaultJobCategory;
            }

            if ($G_VerboseDetail) {
                Write-Host "Handling Job Category: [$L1_JobCategory]"
            }
            #check for existence/create category
            agent_maintainCategory -P_AgentServerName $P_ServerName `
                -P_CategoryName $L1_JobCategory

            $L1_AgentJobName = SQLAgent_FormName -P_SystemName $L1_SystemName -P_SubSystemName $L1_SubSystemName `
                                  -P_EnvironmentName $L1_EnvironmentName -P_JobStartType $L1_JobStartType
            
            if ($G_VerboseDetail) {
                Write-Host "Creating Job [$L1_AgentJobName]"
            }                   
                                  
            agent_createManagedJobBase -P_ServerName $P_ServerName -P_AgentJobName $L1_AgentJobName `
                                       -P_JobCategory $L1_JobCategory -P_JobDescription $L1_JobDescription

            #This is where error step will go, first to make it easier to reference

            ##This is where dependency starting step will go

            #step to add in the primary job step, depending on the type of job
            IF ($L1_JobType -eq "TSQL") {
                agent_addTSQLJobStep -P_ServerName $P_ServerName -P_AgentJobName $L1_AgentJobName `
                            -P_JobCodeText $L1_JobCodeText -P_JobCodeDatabase $L1_JobCodeDatabase
            }

            ##This is where dependency finalize and launch depencencies will go

            ##This is where emailing upon completion will go

        }
    
        $itemsI = $DependencyItems.JobDependency.Count
        
        for ($i = 0; $i -lt $itemsI ; $i++) {
            #fetch the three name parts (if your folder and project 
            #                         names differ, you can easily add that)
            #$L2_SystemName = $DependencyItems.JobDependency[$i].SystemName
            #$L2_SubsystemName = $DependencyItems.JobDependency[$i].SubsystemName
            #$L2_EnvironmentName = $DependencyItems.JobDependency[$i].EnvironmentName
       
        }

        if ($G_VerboseDetail) {
            Write-Host "Creating Schedules"
        }
        $itemsI = $ScheduleItems.JobSchedule.Count
        
        for ($i = 0; $i -lt $itemsI ; $i++) {
            $L3_SystemName = $ScheduleItems.JobSchedule[$i].SystemName
            $L3_SubsystemName = $ScheduleItems.JobSchedule[$i].SubsystemName
            $L3_EnvironmentName = $ScheduleItems.JobSchedule[$i].EnvironmentName
            $L3_ScheduleType = $ScheduleItems.JobSchedule[$i].ScheduleType
            
            $L3_RecurrenceFrequency = $ScheduleItems.JobSchedule[$i].RecurrenceFrequency
            $L3_DaysofTheWeek = $ScheduleItems.JobSchedule[$i].DaysOfTheWeek
            $L3_InDayInterval = $ScheduleItems.JobSchedule[$i].InDayInterval
            $L3_InDayIntervalType = $ScheduleItems.JobSchedule[$i].InDayIntervalType
            $L3_MonthlyDayOfTheMonth = $ScheduleItems.JobSchedule[$i].MonthlyDayOfTheMonth
            
            $L3_JobStartDate = $ScheduleItems.JobSchedule[$i].JobStartDate
            $L3_JobStartTime = $ScheduleItems.JobSchedule[$i].JobStartTime
            $L3_JobEndDate = $ScheduleItems.JobSchedule[$i].JobEndDate
            $L3_JobEndTime = $ScheduleItems.JobSchedule[$i].JobEndTime
            $L3_Enabled = $ScheduleItems.JobSchedule[$i].Enabled
            
            
            #default the start date
            if (!$L3_JobStartDate) {$L3_JobStartDate = Get-Date}
            #default the days of the week
            if (!$L3_DaysOfTheWeek) {$L3_DaysOfTheWeek = "SUN,MON,TUE,WED,THU,FRI,SAT"}
            #default recurrency frequency to be every 1 time period (week or month)
            if (!$L3_RecurrenceFrequency) {$L3_RecurrenceFrequency = 1}
            #default enabled to enabled
            if (!$L3_Enabled) {$L3_Enabled = "True"}

            #etch the name of the agent job you are adding the schedule to
            $L3_AgentJobName = SQLAgent_FormName -P_SystemName $L3_SystemName -P_SubSystemName $L3_SubSystemName `
            -P_EnvironmentName $L3_EnvironmentName -P_JobStartType "Scheduled" #Part of the definition of having a schedule

            #onetime schedules are a lot easier, so I made it it's own function
            if ($L3_ScheduleType -eq "Once") {
                agent_AddOneTimeScheduleToJob -P_ServerName $P_ServerName -P_JobName $L3_AgentJobName `
                                              -P_jobStartDate $L3_jobStartDate -P_JobStartTime $L3_JobStartTime `
                                              -P_Enabled $L3_Enabled
            }
            else {
                #monthly and weekly schedules varied only with the day/days it ran, so it became one call
                agent_AddRecurringScheduleToJob -P_ServerName $P_ServerName -P_JobName $L3_AgentJobName `
                            -P_ScheduleType $L3_ScheduleType -P_RecurrenceFrequency $L3_RecurrenceFrequency `
                            -P_DaysOfTheWeek $L3_DaysOfTheWeek -P_InDayIntervalType $L3_InDayIntervalType `
                            -P_InDayInterval $L3_InDayInterval -P_JobStartDate $L3_JobStartDate `
                            -P_JobStartTime $L3_JobStartTime -P_JobEndDate $L3_JobEndDate `
                            -P_JobEndTime $L3_JobEndTime -P_MonthlyDayOfTheMonth $L3_MonthlyDayOfTheMonth `
                            -P_Enabled $L3_Enabled
            }
        }
    }
    catch {
        Write-Error $_
        Write-Host "Something failed creating the Jobs."
        Throw;
    }
}

function agent_createManagedJobBase ($P_ServerName, $P_AgentJobName, $P_JobCategory, $P_JobDescription) {
    #The base Job creation step
    TRY {
        #Connect to our SQL Server Instance, using a trusted connection
        $SQLServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server("$P_ServerName")

        if ($G_VerboseDetail) {
            write-host "Creating [$P_AgentJobName]"
        }

        # Check if job already exists. Then rename for safety
        $SQLAgentJob = $SQLServer.JobServer.Jobs[$P_AgentJobName]
        if ($SQLAgentJob) {
        
            if ($G_VerboseDetail) {
                Write-Host "*** Job with name '$AgentJobName' found, renaming and disabling it"
            }
            $SQLAgentJob.Rename("z_old_" + $SQLAgentJob.Name + (Get-Date -f MM-dd-yyyy_HH_mm_ss))
            $SQLAgentJob.IsEnabled = $false
            $SQLAgentJob.Alter()
        }

        #Create new (empty) job 
        $NewSQLAgentJob = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.Job `
            -argumentlist $SQLServer.JobServer, $P_AgentJobName
        $NewSQLAgentJob.OwnerLoginName = "SA" #you could change this if you wanted, but this is typically
        $NewSQLAgentJob.Description = $P_JobDescription         #best to have jobs owned by SA
        $NewSQLAgentJob.Create()

        #May alter this later, or leave to someone else.
        $NewSQLAgentJob.ApplyToTargetServer("(local)") 
        
        #set the job category
        $NewSQLAgentJob.Category = $P_JobCategory 

        #set the operator to call if the job fails, based on the next settings
        $OperatorOnCall = environmentvariable_decode('General_OperatorOnCall')
        $NewSQLAgentJob.EmailLevel = [Microsoft.SqlServer.Management.Smo.Agent.CompletionAction]::OnFailure
        $NewSQLAgentJob.OperatorToEmail = "$OperatorOnCall";
        $NewSQLAgentJob.Alter()

        if ($G_VerboseDetail) {
            Write-Host "*** Job '$P_AgentJobName' created"
        }
    }
    catch {
        Write-Error $_
        Write-Host "Something failed creating $P_AgentJobName"
        Throw;
    }
}

function agent_addTSQLJobStep ($P_ServerName, $P_AgentJobName, $P_JobCodeText, $P_JobCodeDatabase) {
    #Used to create the primary jobsetp when it is a T-SQL job step

    TRY {

        if ($G_VerboseDetail){ 
            Write-Host " Creating TSQL:Jobstep for the $P_AgentJobName" 
        }
        #Connect to the sql server with a trusted connection        
        $SQLServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server("$P_ServerName")

        #attach to the job we just created
        $SQLAgentJob = $SQLServer.JobServer.Jobs[$P_AgentJobName]                    

        #Add the base job step
        $JobStepTSQL = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobStep `
                                  -argumentlist $SQLAgentJob, "Primary Work Step - TSQL"
    
        #set the text of the command and the database where it executes
        $JobStepTSQL.Command = $P_JobCodeText
        $JobStepTSQL.DatabaseName = $P_JobCodeDatabase

        #set what occurs on failure. For now, just quit with faiure
        $JobStepTSQL.OnFailAction = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]::QuitWithFailure

        #create the step
        $JobStepTSQL.Create()

        if ($G_VerboseDetail){
            Write-Host "*** TSQL:Jobstep created for the $P_AgentJobName"
        }

    }
    catch {
        Write-Error $_
        Write-Host "Something failed creating the TSQL Jobstep for the $P_AgentJobName"
        Throw;
    }
}

function agent_SplitFrequency($P_JobFrequencyIntervalList) {
#return the bitmask for the days of the week that correspond to the
#list in the schedule
    try {
        
        #split the items in the frequency list (which we do not check for
        #dups or misspellings, so that is up to you)
        $ItemList = $P_JobFrequencyIntervalList -split ","
        $items = $ItemList.length 
        $frequencyIntervalOutput = 0
    
        for ($i = 0; $i -lt $items ; $i++) {
            switch ($ItemList[$i]) {
                "SUN" { $frequencyIntervalOutput = $frequencyIntervalOutput + 1 }
                "MON" { $frequencyIntervalOutput = $frequencyIntervalOutput + 2 }
                "TUE" { $frequencyIntervalOutput = $frequencyIntervalOutput + 4 }
                "WED" { $frequencyIntervalOutput = $frequencyIntervalOutput + 8 }
                "THU" { $frequencyIntervalOutput = $frequencyIntervalOutput + 16 }
                "FRI" { $frequencyIntervalOutput = $frequencyIntervalOutput + 32 }
                "SAT" { $frequencyIntervalOutput = $frequencyIntervalOutput + 64 }
            }
        }
        Return $FrequencyIntervalOutput
    }
    catch {
        Write-Error $_
        write-host "Error Splitting String For Frequency"   
        THROW
    }
}

function agent_AddRecurringScheduleToJob($P_ServerName, $P_JobName, $P_ScheduleType, $P_RecurrenceFrequency, `
                     $P_DaysOfTheWeek, $P_InDayIntervalType, $P_InDayInterval, $P_jobStartDate, $P_JobStartTime, `
                     $P_jobEndDate, $P_JobEndTime, $P_MonthlyDayOfTheMonth, $P_Enabled){

    Try {

        #connect to the sql server, and then connect to the job that was passed in
        $SQLServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server($P_ServerName) 
        $sqlJob = $SQLServer.JobServer.Jobs[$P_JobName]

        #split the time into minutes and seconds, feed that to a timespan
        $TimeList = $P_JobStartTime -split ":"
        $jobStartTime = New-TimeSpan -Hour $TimeList[0] -Minutes $TimeList[1]
        
        #create a new schedule
        $sqlJobSchedule = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.JobSchedule') ($sqlJob, "$P_JobName")
        #provide a slightly descriptive name
        $sqlJobSchedule.Name = "$P_ScheduleType $P_DaysOfTheWeek $jobStartTime"

        #set enabled status of the job
        if ($P_Enabled -eq "False") {
            $sqlJobSchedule.IsEnabled = $false
        } Else {
            $sqlJobSchedule.IsEnabled = $true
        }
        
        #set the start date and time of the job
        $sqlJobSchedule.activeStartDate = $P_jobStartDate
        $sqlJobSchedule.ActiveStartTimeofDay = $JobStartTime

        #set how often the job recurs, based on requency type
        $sqlJobSchedule.FrequencyRecurrenceFactor = $P_RecurrenceFrequency

        if ($P_ScheduleType -eq "Weekly"){
            $sqlJobSchedule.FrequencyTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Weekly
            #for weekly uses the bitmask from the weekdays
            $JobFrequencyIntervalNumeric = agent_SplitFrequency($P_DaysOfTheWeek)
            $sqlJobSchedule.FrequencyInterval = $JobFrequencyIntervalNumeric
        }
        elseif ($P_ScheduleType -eq "Monthly") {
            $sqlJobSchedule.FrequencyTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Monthly
            
            #for montly uses the day of the month (could get kind of ugly error if you put in illogical day)
            if (!$P_MonthlyDayOfTheMonth) {$P_MonthlyDayOfTheMonth = 1}
            $sqlJobSchedule.Frequencyinterval = $P_MonthlyDayOfTheMonth
            
        } else {
            Throw "Unsupported Scheduletype value: [$P_ScheduleType]"
        }
        
        #Enddate is not required, so I did not default this
        If ($P_jobEndDate){
            $sqlJobSchedule.ActiveEndDate = $P_JobEndDate
        }

        #The default is onlyonce, but if you choose minutes for in day interval type, you can choose to have things repeat multiple times
        if ($P_InDayIntervalType -eq "Minutes") {
            $sqlJobSchedule.frequencySubDayTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencySubDayTypes]::Minute
            #this is now the number of minutes in the interval
            $sqlJobSchedule.frequencySubdayInterval = $P_InDayInterval
            
            #it repeats until this time, which we convert to a time span
            if (!$P_JobEndTime){
                $P_JobEndTime = "23:59:59"
            }
            $EndTimeList = $P_JobEndTime -split ":"
            IF (!$EndTimeSeconds) { $EndTimeSeconds = 59}
            $jobEndTime = New-TimeSpan -Hour $EndTimeList[0] -Minutes $EndTimeList[1] -Seconds $EndTimeSeconds
            $sqlJobSchedule.ActiveEndTimeofDay = $JobEndTime

        } Else {
            #otherwise it is a onetime operation
            $sqlJobSchedule.frequencySubDayTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencySubDayTypes]::Once
            $sqlJobSchedule.frequencySubdayInterval = 0
        }
        
        #create the schedule
        $sqlJobSchedule.Create()     
        
        #alter the job
        $sqlJob.Alter()

        if ($G_VerboseDetail){
                Write-Host " Added schedule to $P_JobName"
        }
    }
    Catch {
        Write-Error $_
        write-host "Error adding schedule to $P_JobName";
        THROW
    }

}
function agent_AddOneTimeScheduleToJob($P_ServerName, $P_JobName, $P_jobStartDate, $P_JobStartTime, $P_Enabled) {
    #use to add a onetime schedule to a job
    Try {
        if ($G_VerboseDetail) {
            write-host "Adding onetime schedule to $P_JobName"
        }

        
        #connect to the sql server, and then connect to the job that was passed in
        $SQLServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server($P_ServerName) 
        $sqlJob = $SQLServer.JobServer.Jobs[$P_JobName]

        #create the new schedule
        $sqlJobSchedule = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.JobSchedule') ($sqlJob, "$p_JobName")
        
        #give it an obvious name
        $sqlJobSchedule.Name = "ONETIME-$P_JobName-$JobStartTime"
        
        #enable the job based on the setting
        if ($P_Enabled -eq "False") {
            $sqlJobSchedule.IsEnabled = $false
        } Else {
            $sqlJobSchedule.IsEnabled = $true
        }

        $sqlJobSchedule.FrequencyTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::OneTime

        #set the start time from the required prarmeter
        $TimeList = $P_JobStartTime -split ":"
        $jobStartTime = New-TimeSpan -Hour $TimeList[0] -Minute $TimeList[1]
        $sqlJobSchedule.ActiveStartTimeofDay = $JobStartTime
    
        #set the job start date from a standard data format
        $JobStartDate = [datetime]::parseexact($P_JobStartDate, 'yyyy-MM-dd', $null)
        $sqlJobSchedule.activeStartDate = $JobStartDate

        #create the schedule
        $sqlJobSchedule.Create()

        #alter the job
        $sqlJob.Alter()

    }
        Catch {
            Write-Error $_
            write-host "Error adding schedule to $P_JobName";
            THROW
        }
}

