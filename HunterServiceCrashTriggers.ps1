function Get-ServiceTriggers {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName
    )

    $triggerPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName\TriggerInfo"

    if (-not (Test-Path $triggerPath)) {
        return @()
    }

    $triggerKeys = Get-ChildItem $triggerPath

    foreach ($key in $triggerKeys) {

        $props = Get-ItemProperty $key.PSPath
        $type = $props.Type

        $description = switch ($type) {
            1 { "Device Interface Arrival (device connection event)" }
            2 { "IP Address Availability (network becomes available)" }
            3 { "Domain Joined or Left Event" }
            4 { "Firewall Port Event" }
            5 { "Group Policy Refresh Event" }
            6 { "Network Endpoint Availability" }
            7 { "Custom System State Change Event" }
            8 { "Custom Trigger (Application Defined)" }
            default { "Undocumented Type" }
        }

        $actionDescription = switch ($props.Action) {
            1 { "Start Service" }
            2 { "Stop Service" }
            3 { "Pause Service" }
            4 { "Continue Service" }
            default { "Unknown Action ($($props.Action))" }
        }

        " Trigger Type $type : $description`n"
        "Action: $actionDescription`n"

        if ($props.Guid) {
            try {
                "GUID: $([Guid]$props.Guid)`n"
            } catch {
                "GUID: $($props.Guid)`n"
            }
        }

        ""
    }
}

# --------------------------
# Toggle stopped services for Event ID enumeration
# --------------------------
$stoppedServices = Get-Service | Where-Object { $_.Status -notmatch 'Running' }

foreach ($service in $stoppedServices) {
    if ($service.Name -eq "McmSvc") {
        Write-Host "Skipping McmSvc because it's buggy"
        continue
    }    

    $shouldDisable = $false
    if ($service.StartType -eq 'Disabled') {
        Set-Service $service.Name -StartupType Manual
        $shouldDisable = $true
    }

    Write-Host "Restarting service: $($service.Name)"
    Start-Service -Name $service.Name
    Start-Sleep -Seconds 2
    Stop-Service -Name $service.Name

    if ($shouldDisable) {
        Set-Service $service.Name -StartupType Disabled
    }
}

# --------------------------
# Parse Windows Event Log for Service Crash Events
# --------------------------
$eventIds = @(7000, 7001, 7009, 7011, 7022, 7023, 7024, 7031, 7032, 7035, 7036)
#$eventIds = @(7024, 7031)
$events = Get-WinEvent -LogName System | Where-Object { $eventIds -contains $_.Id }


$crashedServices = @()

if ($events) {
    Write-Host "============================================================"
    
    foreach ($event in $events) {

        # Try to resolve service display name
        $displayName = $event.Properties[0].Value

        # Skip invalid placeholders or empty values
        if ([string]::IsNullOrWhiteSpace($displayName) -or $displayName -match "^\d+$") {
            continue
        }

        # Resolve the service object once
        $serviceObj = Get-Service -Name $displayName -ErrorAction SilentlyContinue
        if (-not $serviceObj) { continue }

        $serviceName = $serviceObj.Name

        # Skip duplicates (using event.Message because same service can fail for different reasons
        if ($crashedServices -contains $event.Message) { continue }
        $crashedServices += $event.Message

        $triggerPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName\TriggerInfo"

        # Get CIM info for additional properties
        $svcCim = Get-CimInstance Win32_Service -Filter "Name='$serviceName'"
        # Determine category
        if ($serviceObj.StartType -like "*Automatic*") {
            $category = "[AUTOSTART] Crashed Service Found (starts on boot, not recommended as this is likely a false-positive)"
        }
        elseif ($serviceObj.StartType -like "*Manual*" -and (Test-Path $triggerPath)) {
            $category = "[MANUAL TRIGGER] Crashed Service Found (Make sure the Action is StartService, might need to modify this service's StartType to abuse it)"
            $category += "`n`nEnabled triggers:`n"
            $category += Get-ServiceTriggers -ServiceName $serviceName

        }
        else {
            $category = "[MANUAL or DISABLED] Crashed Service Found (you have to modify this service's StartType to abuse it)"
        }

        Write-Host "Display Name: $displayName"
        Write-Host "Category: $category"
        Write-Host "Service Name: $serviceName"
        Write-Host "Crash Event ID: $($event.Id)"
        Write-Host "Crash Message: $($event.Message)"
        Write-Host "------------------------------------------------------------"
    }
} else {
    Write-Host "No crashed services found in the last 5 seconds."
}

