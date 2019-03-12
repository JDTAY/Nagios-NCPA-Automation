# Start-Logging

Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
$LogFile = "$PSScriptRoot\Logs\Configure-NCPA-Log$($date).txt"  # setting log file - change as needed
Start-Transcript -Append -Force -path $LogFile

Write-Host "<=============================================================================>"
Write-Host "Check if NCPAPassive and NCPAListener are running on remote hosts"
Write-Host "Written by Jonathon Taylor, 05/07/18"
Write-Host "<=============================================================================>"
Write-Host " "
Write-Host " "

<#=============================================================================#>
# If you want to use an OU search function in PowerShell to use this script against, open All-OUs.txt and add the OU's you'd like to check against.
# Once done, uncomment the below line. The PowerShell script will then find all of the hosts within those OU's and populate servers.txt

# $OUs = Get-Content "$PsScriptRoot\OUs.txt"
# $OUs | foreach {Get-ADComputer -Filter * -SearchBase $_} | select -ExpandProperty Name | Out-File $PsScriptRoot\servers.txt
<#=============================================================================#>

<#=============================================================================#>
# These variables can be changed as required
<#=============================================================================#>

$servers = Get-Content "$PsScriptRoot\servers.txt"

<#=============================================================================#>
# These variables shouldn't need to be changed
<#=============================================================================#>

$ServiceName = "ncpapassive", "ncpalistener"
$date = Get-Date -f HH_mm-yyyy-MM-dd # setting date
$Credential = Get-Credential
$UserName = $Credential.UserName
$Password = $Credential.GetNetworkCredential().Password

<#=============================================================================#>
<# No need to change any details in the script from this point onwards         #>
<#=============================================================================#>

# Create Service Check functions

function CurrentServiceStatus {
    Write-Output "Status of '$ServiceName' service:" | Out-File $LogFile -append
    Get-Service $ServiceName | Select-Object Name,DisplayName,Status | Format-Table -AutoSize | Out-File $LogFile -append
}

function FinalServiceStatus {
    Write-Output "Status of '$ServiceName' service:" | Out-File $LogFile -append
    Get-Service $ServiceName | Select-Object Name,DisplayName,Status | Format-Table -AutoSize | Out-File $LogFile -append
}


foreach($server in $servers) {

Write-Host " "
Write-Host "========================================================================="
Write-Host "    Starting NCPA Service Check Script on $date for $server"
Write-Host "========================================================================="
Write-Host " "

	# Be careful when using msg.exe to Citrix XenApp servers... every user with a session on the host(s) will get your message. Speaking from experience.
	# msg.exe * /server:$server "Hello, $env:UserName is performing some testing on your machine. He's updating the NCPA client. He probably can't hear you complaining over his Death Metal coding playlist, try throwing a pen at him?"
if ($arrServiceCheck){
    Write-Output "'$ServiceName' service found on $env:ComputerName..." | Out-File $LogFile -append
    Write-Output " " | Out-File $LogFile -append

    if ($arrService.Status -eq "Running"){
           Write-Output "'$ServiceName' is already started..." | Out-File $LogFile -append
           Write-Output " " | Out-File $LogFile -append
           FinalServiceStatus
}

    if ($arrService.Status -ne "Running"){
        CurrentServiceStatus
        $arrService = Start-Service $ServiceName -PassThru
        if ($arrService.Status -eq "Running"){
           Write-Output "$date - '$ServiceName' started..." | Out-File $LogFile -append
           Write-Output " " | Out-File $LogFile -append
           FinalServiceStatus
        }
        elseif ($arrService.Status -ne "Running"){
           Write-Output "Error: '$ServiceName' service could not be started..." | Out-File $LogFile -append
           Write-Output " " | Out-File $LogFile -append
           FinalServiceStatus
            }
        }
    }
}