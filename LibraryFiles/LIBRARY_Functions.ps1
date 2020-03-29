function ssisHierarchy_DrawInVisio

#install-module visio

New-VisioApplication
$VisioDoc = New-VisioDocument

$viShapes=Open-VisioDocument -Filename "C:\Users\lbdavi\Documents\My Shapes\Favorites.vssx"

$item = $viShapes.Masters.Item("Entity")
$Page = $VisioDoc.Pages[1]
$Connector = $viShapes.Masters.item("Line Right")

$DependencyJsonFile = ".\JOBS_JobDependencies.json"
$DefinitionJsonFile = ".\JOBS_JobDefinition.json"
$SchedulesJsonFile = ".\JOBS_JobSchedules.json"

$DependencyItems = Get-Content $DependencyJsonFile | ConvertFrom-Json 
$DefinitionItems = Get-Content $DefinitionJsonFile | ConvertFrom-Json 
$ScheduleItems = Get-Content $SchedulesJsonFile | ConvertFrom-Json 

Write-Host "Creating Nodes"
$itemsI = 1000 
for ($i = 0; $i -lt $itemsI ; $i++) {
    $L3_SystemName = $DefinitionItems.Jobs[$i].SystemName
    $L3_SubsystemName = $DefinitionItems.Jobs[$i].SubsystemName
    $L3_EnvironmentName = $DefinitionItems.Jobs[$i].EnvironmentName

    if (!($L3_SystemName)) {Break}

    $ShapeName = "$L3_SystemName-$L3_SubsystemName-$L3_EnvironmentName"
    $ShapeText = "$L3_SystemName $L3_SubsystemName $L3_EnvironmentName"

    $Shape = $Page.drop($Item,1.0,1.0)
    $Shape.Text = "$ShapeText"
    $Shape.Name = "$ShapeName"
   
}

Write-Host "Creating Edges"
for ($i = 0; $i -lt $itemsI ; $i++) {
    $L_SystemName = $DependencyItems.JobDependency[$i].SystemName
    $L_SubsystemName = $DependencyItems.JobDependency[$i].SubsystemName
    $L_EnvironmentName = $DependencyItems.JobDependency[$i].EnvironmentName

    $L_DependsOnSystemName = $DependencyItems.JobDependency[$i].DependsOnSystemName
    $L_DependsOnSubsystemName = $DependencyItems.JobDependency[$i].DependsOnSubsystemName
    $L_DependsOnEnvironmentName = $DependencyItems.JobDependency[$i].DependsOnEnvironmentName
    if (!($L_SystemName)) {Break}

    $ShapeName = "$L_SystemName-$L_SubsystemName-$L_EnvironmentName"
    $DependsOnShapeName = "$L_DependsOnSystemName-$L_DependsOnSubsystemName-$L_DependsOnEnvironmentName"

    $Page.Shapes["$DependsOnShapeName"].AutoConnect($Page.Shapes["$ShapeName"], 0, $Connector)
}

Write-Host "Notating Schedule Details"
for ($i = 0; $i -lt $itemsI ; $i++) {
    $L2_SystemName = $ScheduleItems.Schedules[$i].SystemName
    $L2_SubsystemName = $ScheduleItems.Schedules[$i].SubsystemName
    $L2_EnvironmentName = $ScheduleItems.Schedules[$i].EnvironmentName
    if (!($L2_SystemName)) {Break}

    $ShapeName = "$L2_SystemName-$L2_SubsystemName-$L2_EnvironmentName"

    $Page.Shapes["$ShapeName"].CellsU('TextBkgnd').FormulaU = 30
        
    #$Page.Shapes["$ShapeName"].CellsU('DoubleULine').FormulaU = $True
}

Write-Host "Done"
