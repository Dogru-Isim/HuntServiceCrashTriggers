# HuntServiceCrashTriggers

## Description

PowerShell utility for enumerating potential services that can be abused for persistence with Windows service failure recovery functions (Service FailureCommand, Service FailureActions).

This persistence mechanism has been known for a long time, but I believe recent tool resurfaced it to the general audience: https://cybersecuritynews.com/recoverit-tool/

Example service recovery abuse:

1. https://pentestlab.blog/tag/failurecommand/

2. https://www.zerosalarium.com/2026/02/Defense-Evasion-The-service-run-failed-successfully.html

3. https://isc.sans.edu/diary/15406

This script is primarily useful for:

- Security research

- Privilege escalation surface analysis

- Persistence mechanism discovery

- Service misconfiguration auditing

## What the Script Does

**Temporarily Start Stopped Services**

1. Find all non-running services (indicates a potential startup failure)

2. Temporarily change StartType of *Disabled* services to *Manual*

3. Start -> Wait -> Stop found services

4. Restore original StartType if changed

This helps generate Event Log entries for services that may crash on startup.

[!] Skips McmSvc service due to observed instability.

**Parse Windows Event Logs for Crash Events**

1. Scan the Event Logs for service failure related Event IDs: 7000, 7001, 7009, 7011, 7022, 7023, 7024, 7031, 7032, 7035, 7036 (more Event IDs are used for identification than the RecoverIt blog post)

2. Collect information about services that produced the above Event IDs (event ID, crash message, service display and internal names...)

**Enumerate Service Trigger Configurations**

1. Inspect registry to extract crashed services' metadata from: `HKLM:\SYSTEM\CurrentControlSet\Services\<ServiceName>\TriggerInfo`

2. Find service triggers (Start on boot, manual startup, runtime trigger etc.)

3. Map trigger information to human-readable description (e.g. 3 -> Domain Joined or Left Event)

3. Find trigger actions (Start, Stop, Pause, Continue)

**Output Enumerated Data**

1. Correlate the collected data and display said data in a human-readable format with abuse information. If the service has configured triggers, the output includes them.


Example:

```
------------------------------------------------------------
Display Name: Connected Devices Platform Service
Category: [AUTOSTART] Crashed Service Found (starts on boot, not recommended as this is likely a false-positive)
Service Name: CDPSvc
Crash Event ID: 7022
Crash Message: The Connected Devices Platform Service service did not respond on starting.
------------------------------------------------------------
Display Name: Network List Service
Category: [MANUAL or DISABLED] Crashed Service Found (you have to modify this service's StartType to abuse it)
Service Name: netprofm
Crash Event ID: 7023
Crash Message: The Network List Service service terminated with the following error:
The device is not ready.
------------------------------------------------------------
Display Name: Hyper-V Time Synchronization Service
Category: [MANUAL TRIGGER] Crashed Service Found (Make sure the Action is StartService, might need to modify this service's StartType to abuse it)

Enabled triggers:
 Trigger Type 1 : Device Interface Arrival (device connection event)
 Action: Start Service
 GUID: 9527e630-d0ae-497b-adce-e80ab0175caf

Service Name: vmictimesync
Crash Event ID: 7001
Crash Message: The Hyper-V Time Synchronization Service service depends on the Microsoft Hyper-V Guest Infrastructure Driver service which failed to start because of the following error:
A hypervisor feature is not available to the user.
------------------------------------------------------------
```

Finally, the operator parses the output and picks a reliable service that crashes upon reboot or other triggers. In my experience, the Crash Message is extremely important to find the right service.

MANUAL or DISABLED services are the most reliable in my experience as they are more prune to crashes if they are run standalone by switching the StartType to Autostart etc. They usually require additional steps before reliable startup.

If you can find a reliably crashing AUTOSTART service then you don't have to modify the Autostart type of a service. Good for OPSEC, but make sure it's not a false positive. Another problem with modifying AUTOSTART services is that if you modify all recovery options to execute a backdoor (RecoverIt's default behavior) then you put a probably critical service at risk which might cause the Windows host to crash.

I have not tested any MANUAL TRIGGER services with the mentioned persistence technique. But in theory, they can also be used without modifying the Autostart type.

## How To Use

**Requirements**

1. PowerShell (5.1+ recommended)

2. Administrator privileges

3. Windows OS

**Usage**

1. Run the Script: `powershell -ep bypass .\HuntServiceCrashTriggers.ps1`

2. Parse the output with at least one of your eyes.

## Demo

![demo](./HuntServiceCrashTriggers-2026-02-12_13.24.29.mkv)

## License

Use at your own risk.
No warranty provided.

[!] Use responsibly and only on systems you own or are authorized to test.
