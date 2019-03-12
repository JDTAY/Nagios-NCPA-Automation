# Setting variables

$date = Get-Date -f HH_mm-yyyy-MM-dd # setting date
$LogFile = "$PSScriptRoot\Logs\Check-NCPA-Service$-($date).txt" # setting log file - change as needed
$ServiceName = "ncpapassive", "ncpalistener" # setting service name - change as needed
$arrService = Get-Service -Name $ServiceName
$arrServiceCheck = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue -ErrorVariable NoService
$noService = @()
$servers = "$PSScriptRoot\servers.txt"

<# =============== DO NOT CHANGE ANYTHING BELOW THIS POINT =============== #>
# Creating functions for re-use throughout script

function CurrentServiceStatus {
    Write-Output "Status of '$ServiceName' service:" | Out-File $LogFile -append
    Get-Service $ServiceName | Select-Object Name,DisplayName,Status | Format-List | Out-File $LogFile -append
}

function FinalServiceStatus {
    Write-Output "Status of '$ServiceName' service:" | Out-File $LogFile -append
    Get-Service $ServiceName | Select-Object Name,DisplayName,Status | Format-List | Out-File $LogFile -append
}

# Starting script operation

Write-Output "=========================================================================" | Out-File $LogFile
Write-Output "    Starting '$ServiceName' Service Monitor Script on $date" | Out-File $LogFile -append
Write-Output "=========================================================================" | Out-File $LogFile -append
Write-Output " " | Out-File $LogFile -append

# Looking for service. If service was found, checking it's status. If status is not running, starting the service.

foreach($server in $servers) {
		Write-Output "'$ServiceName service found on $server..." | Out-File $LogFile -append
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
	if ($arrServiceCheck){
		}
        elseif ($arrService.Status -ne "Running"){
			Write-Output "Error: '$ServiceName' service could not be started..." | Out-File $LogFile -Append
			Write-Output " " | Out-File $LogFile -append
			FinalServiceStatus
		}
    }
}

# If service was not found, making note of it to log file

if ($NoService){
    Write-Output " " | Out-File $LogFile -append
Write-Output $NoService[0].exception.message | Out-File $LogFile -append
    Write-Output " " | Out-File $LogFile -append
}


# Completing running of script

Write-Output "=========================================================================" | Out-File $LogFile -append
Write-Output "    Finished '$ServiceName' Service Monitor Script on $date" | Out-File $LogFile -append
Write-Output "=========================================================================" | Out-File $LogFile -append
Write-Output " " | Out-File $LogFile -append
Write-Output " " | Out-File $LogFile -append