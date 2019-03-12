Write-Output "<=============================================================================>" | Out-File $LogFile -append
Write-Output "Rollout NCPA updates to multiple computers" | Out-File $LogFile -append
Write-Output "Typically used before the Remotely-Configure-NCPA.ps1 script so the NCPA client can upgraded" | Out-File $LogFile -append
Write-Output "Written by Jonathon Taylor, 24/05/18" | Out-File $LogFile -append
Write-Output "<=============================================================================>" | Out-File $LogFile -append
Write-Output " " | Out-File $LogFile -append
Write-Output " "| Out-File $LogFile -append

<#=============================================================================
Enforcing the script to error our and stop if any errors are found
Comment this out if you want the script to continue and ignore errors
Set-StrictMode -Version 2.0
=============================================================================#>

<#=============================================================================
If you want to use an OU search function in PowerShell to use this script against, open All-OUs.txt and add the OU's you'd like to check against.
Once done, uncomment the below line. The PowerShell script will then find all of the hosts within those OU's and populate servers.txt

$OUs = Get-Content "$PsScriptRoot\OUs.txt"
$OUs | foreach {Get-ADComputer -Filter * -SearchBase $_} | select -ExpandProperty Name | Out-File $PsScriptRoot\servers.txt
=============================================================================#>

<#=============================================================================
These variables shouldn't need to be changed
=============================================================================#>

$ServiceName = "ncpapassive", "ncpalistener"
$NoService = @()
$ServiceArray = Get-Service -Name $ServiceName -ErrorAction 'SilentlyContinue'
$ServiceArrayCheck = Get-Service -Name $ServiceName -ErrorAction 'SilentlyContinue'
$date = Get-Date -f HH_mm-yyyy-MM-dd # setting date
$Credential = Get-Credential
$UserName = $Credential.UserName
$Password = $Credential.GetNetworkCredential().Password


<#=============================================================================#>
# These variables can be changed as required
<#=============================================================================#>

$servers = Get-Content "$PsScriptRoot\servers.txt"
$installerSource = "$PsScriptRoot\ncpa-2.1.3.exe" # Update this to what ever version of the NCPA client you're installing
$LogFile = "$PSScriptRoot\Logs\Configure-NCPA-Log$($date).txt" # setting log file - change as needed

<#=============================================================================
No need to change any details in the script from this point onwards
============================================================================= #>

# Create functions

function ServiceStatusCurrent {
	try{
		Write-Output "Get status of '$ServiceName' service" | Out-File $LogFile -append
		Get-Service $ServiceName | Select-Object Name,DisplayName,Status | Format-List
		}
	catch {
		if ($error[0].Exception -match "Error in ServiceStatusCurrent")
			Write-Error "Stopping script, error found during function call in ServiceStatusCurrent"
	else
	}
		Throw ("Errors have been found during function ServiceStatusCurrent, stopping script, check outputs and log files" + $error[0].Exception)
	}
function ServiceStatusFinal {
	try {
    Write-Output "Get status of '$ServiceName' service" | Out-File $LogFile -append
    Get-Service $ServiceName | Select-Object Name,DisplayName,Status | Format-List
		}
	catch {
		if ($error[0].Exception -match "Error in ServiceStatusCurrent")
	{
		Write-Error "Stopping script, error found during function call in ServiceStatusCurrent"
		else
	}
		Throw ("Errors have been found during function ServiceStatusFinal, stopping script, check outputs and log files" + $error[0].Exception)
	}
}

function PushNCPAConfig {
        Write-Host "NCPA is already installed . Stopping NCPA services and pushing our NRDP and NCPA config files to directory on $server"  | Out-File $LogFile -append
        ServiceStatusCurrent
        $ServiceArray | Set-Service -status Stopped
		Copy-Item $PsScriptRoot\ncpa-template.cfg -Destination $PsScriptRoot\ncpa.cfg -force
        (Get-Content $PsScriptRoot\ncpa.cfg).replace("hostname = replaceme.local", "hostname = $server") | Out-File $PsScriptRoot\ncpa.cfg -Encoding ascii

		# Remove-Item doesn't work recursively when using the -Include Parameter, so instead you must pipe the results of Get-ChildItem into Remove-Item
		# Refer to: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
		# Find all of the .cfg files in the ..\Nagios\etc directory and delete them recursively
        Get-ChildItem "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc" -Include *.cfg -Recurse -ErrorAction Suspend -ErrorVariable $ErrorLog | Remove-Item

        Copy-Item -Path $PsScriptRoot\ncpa.cfg -Destination "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc" -force
		Copy-Item -Path $PsScriptRoot\nrdp.cfg -Destination "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc\ncpa.cfg.d" -force

        Write-Host "Restarting the NCPA Services on $server"  | Out-File $LogFile -append
        $ServiceArray | Set-Service -status Running
			If($PushNCPAConfigError) {
				Write-Warning -Message 'Something went wrong during function PushNCPAConfig!' | Out-File $LogFile -append
				}
        ServiceStatusFinal
}


function InstallClient {
        Write-Host "Pushing out installer to the NCPA Install directory on $server, install NCPA using PSExec and pushing out the neccessary config files" | Out-File $LogFile -append
        ServiceStatus-Current
        Copy-Item -Path $installerSource -Destination "\\$server\C$\Temp\"
        Write-Host "Files have been pushed out to %Program Files (x86)\Nagios on $server" | Out-File $LogFile -append
        Write-Host "Now running the NCPA installer on $server using PSExec" | Out-File $LogFile -append
        PsExec.exe /accepteula \\$server -u $UserName -p $Password $installerSource /S /Token='mytoken'
		Write-Host "Stopping the NCPA services now it's been installed and pushing out new config files on $server" | Out-File $LogFile -append
        Get-Service -ComputerName $server -Name $ServiceName | Set-Service -status Stopped

		# Remove-Item doesn't work recursively when using the -Include Parameter, so instead you must pipe the results of Get-ChildItem into Remove-Item
		# Refer to: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
		# Find all of the .cfg files in the ..\Nagios\etc directory and delete them recursively
        Get-ChildItem "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc" -Include *.cfg -Recurse | Remove-Item
        Copy-Item $PsScriptRoot\ncpa-template.cfg -Destination $PsScriptRoot\ncpa.cfg -force
        (Get-Content $PsScriptRoot\ncpa.cfg).replace("hostname = replaceme.local", "hostname = $server") | Out-File $PsScriptRoot\ncpa.cfg -Encoding ascii

        Copy-Item -Path $PsScriptRoot\ncpa.cfg -Destination "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc" -force
		Copy-Item -Path $PsScriptRoot\nrdp.cfg -Destination "\\$server\C$\Program Files (x86)\Nagios\NCPA\etc\ncpa.cfg.d" -force

        Write-Host "Restarting the NCPA Services on $server" | Out-File $LogFile -append
        Write-Host "Error code 0 from PSExec = success, leaving the false positive error in for posterity" | Out-File $LogFile -append

		Write-Host "Restarting NCPA services on $server, and wrapping up" | Out-File $LogFile -append
        $ServiceArray | Set-Service -status Running
        ServiceStatus-Final
}


# Starting script operation

Write-Output "=========================================================================" | Out-File $LogFile -Append
Write-Output "    Starting NCPA Config Script Service Monitor Script on $date" | Out-File $LogFile -append
Write-Output "=========================================================================" | Out-File $LogFile -append

foreach($server in $servers) {
	# Be careful when using msg.exe to Citrix XenApp servers... every user with a session on the host(s) will get your message. Speaking from experience.
	# msg.exe * /server:$server "Hello, $env:UserName is performing some testing on your machine. He's updating the NCPA client. He probably can't hear you complaining over his Death Metal coding playlist, try throwing a pen at him?"

    if (($ServiceArrayCheck).status -eq 'Running' ) {
        Write-Output "'$ServiceName' services found on $server..." | Out-File $LogFile -append
		Write-Output "Starting PushNCPAConfig function (stop services, push out config files and restart $ServiceName..." | Out-File $LogFile -append
        Write-Output " " | Out-File $LogFile -append
        PushNCPAConfig
        ServiceStatus-Final
    } Else {
        (($ServiceArrayCheck).status -ne 'Running')
        Write-Output "'$ServiceName' services were not found on $server..." | Out-File $LogFile -append
		Write-Output "'Starting 'InstallClient function on $server..." | Out-File $LogFile -append
        Write-Output " " | Out-File $LogFile -append
        InstallClient
        ServiceStatus-Final
    }
}

