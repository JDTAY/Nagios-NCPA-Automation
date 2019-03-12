#====================================================================================================
#                                             Functions
#====================================================================================================
#----------------------------------------------------------------------------------------------------

    <#
    .SYNOPSIS
    Nagios roll out script, updates remote Windows hows NCPA config files and installs the client if required.

    .DESCRIPTION
    Nagios roll out script, updates remote Windows hows NCPA config files and installs the client if required.

    .NOTES
    AUTHOR  : Jonathon Taylor
    CREATED : 25/07/2018
    VERSION : 1.0

    .INPUTS
    None. This script does not allow inputs.

    .OUTPUTS
    None. This script does not output parameters.

    .PARAMETER err
    N/A
    #>

# Dot Sourcing the AuscriptCore script for error logging
. .\AuscriptCore.ps1

<#=============================================================================#>
# If you wish to search AD for hosts to push out NCPA to, add your OUs to the OUs.txt file and uncomment the two lines below
# The command will then grab the computers found in the OU's and populate servers.txt
# $OUs = Get-Content "$PsScriptRoot\OUs.txt"
# $OUs | foreach {Get-ADComputer -Filter * -SearchBase $_} | select -ExpandProperty DNSHostName | Out-File "C:\Users\a_j.taylor\source\repos\Nagios-NCPA-Automation\servers.txt" -Encoding ascii

$servers = Get-Content "$PSScriptRoot\servers.txt"

<#=============================================================================#>
# These variables shouldn't need to be changed
<#=============================================================================#>

$ServiceName = "ncpapassive", "ncpalistener"
$date = Get-Date -f HH_mm-yyyy-MM-dd # setting date
$Credential = Get-Credential
$UserName = $Credential.UserName
$Password = $Credential.GetNetworkCredential().Password

<#=============================================================================#>
# These variables should be changed as required
<#=============================================================================#>

$installerSource = "$PSScriptRoot\ncpa-2.1.3.exe" # Update this to what ever version of the NCPA client you're installing\updating
$NCPATemplate = "$PSScriptRoot\ncpa-template.cfg"
$NCPAToWrite = "$PSScriptRoot\ncpa.cfg"
$NRDPToWrite = "$PSScriptRoot\nrdp.cfg"

<#=============================================================================#>
<# No need to change any details in the script from this point onwards         #>
<#=============================================================================#>

foreach($server in $servers)
{
Clear-Variable CurrentNCPAStatus* -scope Global
Clear-Variable NCPAUpated* -scope Global
Clear-Variable PreNCPAInstall* -scope Global
Clear-Variable PostNCPAInstall* -scope Global

New-Variable -name CurrentNCPAStatus+"$server" -value "Get-Service -Name 'ncpapassive', 'ncpalistener' -ComputerName $server'"
New-Variable -name PostNCPAInstall+"$server" -value "Get-Service -Name 'ncpapassive', 'ncpalistener' -ComputerName $server'"
New-Variable -name PreNCPAUpdate+"$server" -value "Get-Service -Name 'ncpapassive', 'ncpalistener' -ComputerName $server'"
New-Variable -name PostNCPAUpdate+"$server" -value "Get-Service -Name 'ncpapassive', 'ncpalistener' -ComputerName $server'"

# Create logging function
# Starting script operation

Write-Host " "
Write-Host "========================================================================="
Write-Host "    Starting NCPA Config Script Service Monitor Script on $date for $server"
Write-Host "========================================================================="
Write-Host " "
    If  ((Get-Variable -Name $CurrentNCPAStatus+"$server" -ValueOnly).Status -eq 'Running')  {

        Write-Host " "
    	Write-Host "'$ServiceName' services found and are running on $server..."
		Write-Host "Stop services, push out config files and restart $ServiceName on $server..."
        Write-Host " "

        Get-Service -Name $Servicename -ComputerName $server -ErrorAction SilentlyContinue | Set-Service -status Stopped
        Copy-Item $NCPATemplate -Destination $NCPAToWrite -force
        (Get-Content $NCPAToWrite).replace("hostname = replaceme.local", "hostname = $server") | Out-Null

        # Remove-Item doesn't work recursively when using the -Include Parameter, so instead you must pipe the results of Get-ChildItem into Remove-Item
        # Refer to: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
        # Find all of the .cfg files in the ..\Nagios\etc directory and delete them recursively
        Get-ChildItem "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc" -Include *.cfg -Recurse | Remove-Item

        Copy-Item -Path $NCPAToWrite -Destination "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc" -force
        Copy-Item -Path $NRDPToWrite -Destination "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc\ncpa.cfg.d" -force

        Write-Host " "
        Write-Host "Restarting the NCPA Services on $server"
        Write-Host " "
        $PostNCPAInstall+"$server"
	} Else {
        $PreNCPAInstall+"$server"
        $remoteInstaller = "\\$server\C$\temp\ncpa-2.1.3.exe"
        Write-Host " "
        Write-Host "'$ServiceName' are not running on $server or were not found..."
        Write-Host "We will now install NCPA on $server using PSExec "
        Copy-Item -Path $installerSource -Destination "\\$server\C$\temp\"
        Write-Host " "
        Write-Host "Files have been pushed out to '%Program Files (x86)\Nagios' on $server and installer to '\\$server\C$\temp\' "
        Write-Host "Now running the NCPA installer on $server using PSExec"
        Write-Host " "
        PsExec.exe /accepteula \\$server -u $UserName -p $Password $remoteInstaller /S /Token='mytoken'
        Write-Host " "
        Write-Output "Stopping the NCPA services now it's been installed and pushing out new config files on $server"
        Write-Host " "

        # Get-Service -Name $ServiceName -ComputerName $server -ErrorAction SilentlyContinue | Set-Service -status Stopped

        # Remove-Item doesn't work recursively when using the -Include Parameter, so instead you must pipe the results of Get-ChildItem into Remove-Item
        # Refer to: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
        # Find all of the .cfg files in the ..\Nagios\etc directory and delete them recursively
        Get-ChildItem "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc" -Include *.cfg -Recurse | Remove-Item
        Copy-Item $NCPATemplate -Destination $NCPAToWrite -force
        (Get-Content $NCPAToWrite).replace("hostname = replaceme.local", "hostname = $server") | Out-Null
        Copy-Item -Path $NCPAToWrite -Destination "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc" -force
        Copy-Item -Path $NRDPToWrite -Destination "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc\ncpa.cfg.d" -force
        Write-Host " "
        Write-Host "Restarting the NCPA Services on $server"
        Write-Host "Error code 0 from PSExec = Success, leaving the false positive error in for posterity"
        Write-Host "Restarting NCPA services on $server, and wrapping up"
        Write-Host " "

        Get-Service -Name "ncpapassive", "ncpalistener" -ErrorAction 'SilentlyContinue' | Set-Service -status Running
        Get-Service -Name $ServiceName -ComputerName $server -ErrorAction SilentlyContinue | Set-Service -status Running

        Write-Host " "
        Write-Host "NCPCA update/rollout has been finished, output below should show $ServiceName running on $server"
        Write-Host " "

        $PostNCPAUpdate+"$server"
    }
}

Stop-Transcript -ErrorAction SilentlyContinue | Out-Null