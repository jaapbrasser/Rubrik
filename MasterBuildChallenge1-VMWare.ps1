#Guardians Master Builder Challenge #1 - Brandon Morris, City of Sioux Falls

Write-host "Importing Modules..."
write-host ""

Import-Module Rubrik
Import-Module VMware.PowerCLI

#Variables: Please change these

#Rubrik Cluster ID, enter your clusters name or IP address
$RubrikCluster = "rubrik.city.siouxfallssd.org"
#Directory to output data too
$OutputDirectory = "H:\RubrikData"


#create functions to REST Call for missed data, gathered from rubrikinc github https://github.com/rubrikinc/rubrik-scripts-for-powershell/blob/master/create_jira_issue_missed_snapshot.ps1
function Get-RubrikVmwareMissedSnapshot ($vm_id) {
    $uri = 'vmware/vm/'+$vm_id+'/missed_snapshot'
    $method = 'GET'
    $response = Invoke-RubrikRESTCall -Endpoint $uri -Method $method
    Return $response
}

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

#Prompt user for a credential to connect to Rubrik, then connect to the cluster, fail out if connection fails

write-host "Please enter a credential to connect to the Rubrik Array"
write-host ""
$Credential = Get-Credential $null

try
{
    Connect-Rubrik -Server $RubrikCluster -Credential $Credentials -ErrorAction Stop |out-null
    write-host "Connected to Rubrik array at" $RubrikCluster
    write-host ""
}
catch
{
    write-host "Failed to connect to Rubrik Cluster" 
    return
}

#Gather list of VMs.  VMWare only, does anyone even run Hyper-V in production?

write-host "Gathering list of all VMware Virtual Machines"
write-host ""

#Get all vms
$RubrikVMlist = Get-RubrikVM | Select id,name,hostName,effectiveSLADomainName,clustername,isRelic
#Sory by name
$RubrikVMlist = $RubrikVMlist | Sort-Object name

write-host "Gathered basic information on" $RubrikVMlist.Count "virtual machines."
write-host ""

#Gather data on missed SLA snapshots
write-host "Gathering data on Virtual Machines Snapshots"

$Report=@()

foreach ($vm in $RubrikVMlist) {
	$VirtualMachine = $vm.Name
	write-host "Processing" $VirtualMachine
	$HostName = $vm.HostName
	$EffectiveSlaDomainName = $vm.effectiveSlaDomainName
	$ClusterName = $vm.clusterName
	$MissedSnapshot = Get-RubrikVmwareMissedSnapshot $vm.id
	$MissedSnapshotTotal = $MissedSnapshot.total
    $isRelic = $vm.isRelic
	$ReportLine = new-object PSObject
	$ReportLine | Add-Member -MemberType NoteProperty -Name "Virtual Machine Name" -Value "$VirtualMachine"
	$ReportLine | Add-Member -MemberType NoteProperty -Name "SLA Name" -Value "$EffectiveSlaDomainName"
	$ReportLine | Add-Member -MemberType NoteProperty -Name "ClusterName" -Value "$ClusterName"
	$ReportLine | Add-Member -MemberType NoteProperty -Name "HostName" -Value "$HostName"
	$ReportLine | Add-Member -MemberType NoteProperty -Name "Missed Snapshot Count" -Value "$MissedSnapshotTotal"
    $ReportLine | Add-Member -MemberType NoteProperty -Name "Relic" -Value $isRelic
	$Report += $ReportLine
}

#Output sorted list of VMs then save to file
$Report | Format-Table
$Report | export-csv -path ($OutputDirectory + '\' + $currentdate + '-vmlist.csv')