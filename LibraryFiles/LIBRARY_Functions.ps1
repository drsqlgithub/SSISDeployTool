#######################
# This file will have many of the functions needed for all of the deployment work I will be implementing
#######################
function agent_maintainCategory ($P_AgentServerName, $P_CategoryName) {

    Try {
            
        $ssisServer = New-Object -TypeName  Microsoft.SQLServer.Management.Smo.Server("$P_AgentServerName") 
        $JobServer = $ssisServer.JobServer

        $Category = $ssisServer.JobServer.JobCategories["$P_CategoryName"]
        if (!$Category) {
            $NewCategory = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.JobCategory') ($JobServer, "$P_CategoryName")
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

function global:environmentvariable_decode {
    <#
    Used to decode an environment variable reference into its actual value. Environment variables are loaded
    in the Variables_%EnvironmentName% area

    This function will generally be used to take a token that has been coded, and use it to 
    get the value from the array
    #>

    param($itemName)

    $items = $EnvironmentVariableArray.Length / 3

    for ($i = 0; $i -lt $items ; $i++) {
        if ($itemName -eq $EnvironmentVariableArray[$i, 0]) {
            $output = $EnvironmentVariableArray[$i, 1]
        }
    }
    if ("" + $output + "" -eq "") {
        throw "The array token passed in: [$itemName] was not found in the environment variable global array"
    }
    else {
        return $output;
    }

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