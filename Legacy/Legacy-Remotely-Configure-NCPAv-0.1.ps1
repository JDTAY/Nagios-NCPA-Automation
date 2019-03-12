Write-Host "<=============================================================================>"
Write-Host "Rollout NCPA updates or install NCPA to multiple hosts"
Write-Host "Written by Jonathon Taylor, 24/05/18"
Write-Host "<=============================================================================>"
Write-Host " "
Write-Host " "



<#=============================================================================#>
# If you want to use an OU search function in PowerShell to use this script against, open All-OUs.txt and add the OU's you'd like to check against.
# Once done, uncomment the below line. The PowerShell script will then find all of the hosts within those OU's and populate servers.txt

# $OUs = Get-Content "$PsScriptRoot\OUs.txt"
# $OUs | foreach {Get-ADComputer -Filter * -SearchBase $_} | select -ExpandProperty DNSHostName | Out-File "C:\Users\a_j.taylor\source\repos\Nagios-NCPA-Automation\servers.txt" -Encoding ascii

$servers = Get-Content "C:\Users\a_j.taylor\source\repos\Nagios-NCPA-Automation\servers.txt"

<#=============================================================================#>

<#=============================================================================#>
# These variables shouldn't need to be changed
<#=============================================================================#>

$ServiceName = "ncpapassive", "ncpalistener"
$date = Get-Date -f HH_mm-yyyy-MM-dd # setting date
$Credential = Get-Credential
$UserName = $Credential.UserName
$Password = $Credential.GetNetworkCredential().Password


<#=============================================================================#>

foreach ($server in $servers)
{

<#=============================================================================#>
# These variables should be changed as required
<#=============================================================================#>

#TODO: Turn these into params
$installerSource = "C:\Users\jonathon.taylor\source\repos\Nagios-NCPA-Automation\ncpa-2.1.3.exe" # Update this to what ever version of the NCPA client you're installing\updating
$NCPATemplate = "C:\Users\jonathon.taylor\source\repos\Nagios-NCPA-Automation\ncpa-template.cfg"
$NCPAToWrite = "C:\Users\jonathon.taylor\source\repos\Nagios-NCPA-Automation\ncpa.cfg"
$NRDPToWrite = "C:\Users\jonathon.taylor\source\repos\Nagios-NCPA-Automation\nrdp.cfg"

<#=============================================================================#>
<# No need to change any details in the script from this point onwards         #>
<#=============================================================================#>

$GetServices = Get-Service -ComputerName $server -Name $ServiceName
$CurrentNCPAStatus = $GetServices
$PostNCPAInstall = $GetServices
$PostNCPAUpdate = $GetServices

# Start-Logging
Remove-Variable LogFile* -Scope Global -Force
Remove-Variable CurrentNCPAStatus* -Scope Global -Force
Remove-Variable NCPAUpated* -Scope Global -Force
Remove-Variable PreNCPAInstall* -Scope Global -Force
Remove-Variable PostNCPAInstall* -Scope Global -Force

$LogFile = "$PSScriptRoot\Logs\Configure-NCPA-Log$($date)($server).txt"
Start-Transcript -Append -Force -path $LogFile

# Create logging function

# Starting script operation

Write-Host " "
Write-Host "========================================================================="
Write-Host "    Starting NCPA Config Script Service Monitor Script on $date for $server"
Write-Host "========================================================================="
Write-Host " "

	# msg.exe * /server:$server "Hello, $env:UserName is performing some testing on your machine. He's updating the NCPA client."
    If  (($CurrentNCPAStatus).Status -eq 'Running')  {

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
        $PostNCPAInstall
	} Else {
        $PreNCPAInstall
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

        $PreNCPAInstall | Set-Service -Status "Stopped"

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

        $PostNCPAUpdate
    }
}

Stop-Transcript -ErrorAction SilentlyContinue | Out-Null