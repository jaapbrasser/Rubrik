#Guardians Master Builder Challenge #1 - Brandon Morris, City of Sioux Falls

Write-host "Importing Modules..."
write-host ""

Import-Module Rubrik

#Variables: Please change these
#make sure to run a rubrik user account that has read only permissions, this can be then scripted to run and generate reports automatically
$OutputDirectory = "H:\RubrikData"
$rubrik_cluster = 'rubrik cluster name or IP'
$rubrik_user = 'USE READONLY ACCOUNT DETAILS'
$rubrik_pass = 'USE READONLY ACCOUNT DETAILS'
#report ID for SLA Compliance Summary report for Rubrik report function
$report_id = "CustomReport:::0d38b685-f08c-43b9-bb80-0e661f6e3fc4"


#create functions to REST Call for missed data, gathered from rubrikinc github https://github.com/rubrikinc/rubrik-scripts-for-powershell/blob/master/create_jira_issue_missed_snapshot.ps1
function Get-RubrikVmwareMissedSnapshot ($vm_id) {
    $uri = 'vmware/vm/'+$vm_id+'/missed_snapshot'
    $method = 'GET'
    $response = Invoke-RubrikRESTCall -Endpoint $uri -Method $method
    Return $response
}
function Get-RubrikFilesetMissedSnapshot ($fileset_id) {
    $uri = 'fileset/'+$fileset_id+'/missed_snapshot'
    $method = 'GET'
    $response = Invoke-RubrikRESTCall -Endpoint $uri -Method $method
    Return $response
}
function Get-RubrikSqlDbMissedSnapshot ($sqldb_id) {
    $uri = 'mssql/db/'+$sqldb_id+'/missed_snapshot'
    $method = 'GET'
    $response = Invoke-RubrikRESTCall -Endpoint $uri -Method $method
Return $response
}

#
# Name:     get_reportdata_table_41.ps1
# Author:   Tim Hynes
# Use case: Provides an example of pulling out Envision report data for Rubrik CDM 4.1+
#
function Get-RubrikReportData41 () {
    [CmdletBinding()]
    Param (
        [string]$rubrik_cluster,
        [string]$rubrik_user,
        [string]$rubrik_pass,
        [string]$report_id,
        [System.Object]$report_query
    )

    $headers = @{
        Authorization = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $rubrik_user,$rubrik_pass)))
        Accept = 'application/json'
    }

    
    $report_output = @()
    $has_more = $true
    while ($has_more -eq $true) {
        if ($cursor -ne $null) {
            $report_query['cursor'] = $cursor
        }
        $report_response = Invoke-WebRequest -Uri $("https://"+$rubrik_cluster+"/api/internal/report/"+$report_id+"/table") -Headers $headers -Method POST -Body $(ConvertTo-Json $report_query)
        $report_data = $report_response.Content | ConvertFrom-Json
        $has_more = $report_data.hasMore
        $cursor = $report_data.cursor
        foreach ($report_entry in $report_data.dataGrid) {
            $row = '' | select $report_data.columns
            for ($i = 0; $i -lt $report_entry.count; $i++) {
                $row.$($report_data.columns[$i]) = $($report_entry[$i])
            }
            $report_output += $row
        }
    }
    return $report_output
}

$report_query = @{
    limit = 9999
}
<# Below is the complete available list of queries, copy and add these to the $report_query hash above to enable them
@{
    limit = 0
    sortBy = "Hour"
    sortOrder = "asc"
    cursor = "sring"
    objectName = "string"
    requestFilters = @{
    organization = "string"
    slaDomain = "string"
    taskType = "Backup"
    taskStatus = "Succeeded"
    objectType = "HypervVirtualMachine"
    complianceStatus = "InCompliance"
    clusterLocation = "Local"
    }
}
#>

$currentdate= get-date -Format "yyyy-mm-dd"

#Display Logo information

$Logo = @'
   _____                     _ _                   __  __           _              ____        _ _     _    _____ _           _ _                           _  _  __ 
  / ____|                   | (_)                 |  \/  |         | |            |  _ \      (_) |   | |  / ____| |         | | |                        _| || |__ |
 | |  __ _   _  __ _ _ __ __| |_  __ _ _ __  ___  | \  / | __ _ ___| |_ ___ _ __  | |_) |_   _ _| | __| | | |    | |__   __ _| | | ___ _ __   __ _  ___  |_  __  _| |
 | | |_ | | | |/ _` | '__/ _` | |/ _` | '_ \/ __| | |\/| |/ _` / __| __/ _ \ '__| |  _ <| | | | | |/ _` | | |    | '_ \ / _` | | |/ _ \ '_ \ / _` |/ _ \  _| || |_| |
 | |__| | |_| | (_| | | | (_| | | (_| | | | \__ \ | |  | | (_| \__ \ |_  __/ |    | |_) | |_| | | | (_| | | |____| | | | (_| | | |  __/ | | | (_| |  __/ |_  __  _| |
  \_____|\__,_|\__,_|_|  \__,_|_|\__,_|_| |_|___/ |_|  |_|\__,_|___/\__\___|_|    |____/ \__,_|_|_|\__,_|  \_____|_| |_|\__,_|_|_|\___|_| |_|\__, |\___|   |_||_| |_|
                                                                                                                                              __/ |                  
                                                                                                                                             |___/                   
'@
write-host $Logo
write-host "by Brandon Morris"
write-host ""

$SecurePassword= ConvertTo-SecureString $rubrik_pass -AsPlainText -Force

try
{
    Connect-Rubrik -Server $rubrik_cluster -Username $rubrik_user -Password $securePassword -ErrorAction Stop |out-null
    write-host "Connected to Rubrik array at" $Rubrik_Cluster
    write-host ""
}
catch
{
    write-host "Failed to connect to Rubrik Cluster" 
    return
}

#Get the report data
$reportdata = Get-RubrikReportData41 -rubrik_cluster $rubrik_cluster -rubrik_user $rubrik_user -rubrik_pass $rubrik_pass -report_query $report_query -report_id $report_id
$Report=@()

#Run through each object from the report, gather host and cluster for each virtual machine, VMWare only but could add for others as needed

foreach ($row in $reportdata) {
	$objectname = $row.objectname
	$objecttype = $row.objecttype
    $location = $row.location
    $sladomain = $row.SlaDomain
    $compliancestatus = $row.ComplianceStatus
    $lastsnapshot = $row.LastSnapshot
    $totalsnapshots= $row.TotalSnapshots
    $missedsnapshots = $row.MissedSnapshots
    $VMHostName = ""
    $VMclustername = ""

    if ( $objecttype -eq "VmwareVirtualMachine" ){
      $VMHostName = Get-rubrikvm -name $row.ObjectName | select -ExpandProperty hostName
      $VMclustername = get-rubrikvm -name $row.ObjectName | select -ExpandProperty clustername
      }

    #this could be commented out to save a lot of console output if ran programatically
    write-host "proccessing" $row.objectname
	
    $ReportLine = new-object PSObject
    $ReportLine | Add-Member -MemberType NoteProperty -Name "Object Name" -Value "$objectname"
    $ReportLine | Add-Member -MemberType NoteProperty -Name "Object Type" -Value "$objecttype"
    $ReportLine | Add-Member -MemberType NoteProperty -Name "Location" -Value "$location"
    $reportline | Add-Member -MemberType NoteProperty -Name "HostName" -Value "$VMHostName"
    $Reportline | add-member -MemberType NoteProperty -Name "ClusterName" -Value "$VMClusterName"
	$ReportLine | Add-Member -MemberType NoteProperty -Name "SLA Name" -Value "$sladomain"
    $ReportLine | Add-Member -MemberType NoteProperty -Name "Compliance Status" -Value "$compliancestatus"
	$ReportLine | Add-Member -MemberType NoteProperty -Name "Last Snapshot" -Value "$lastsnapshot"
	$ReportLine | Add-Member -MemberType NoteProperty -Name "Total Snapshots" -Value "$totalsnapshots"
	$ReportLine | Add-Member -MemberType NoteProperty -Name "Missed Snapshot Count" -Value "$missedsnapshots"
    
    $Report += $ReportLine
}

#display report
$report | format-table

#export to path with date
$report | export-csv -path ($OutputDirectory + '\' + $currentdate + '- Backup Information.csv')