---
name: windows-startup-tuning
description: Use when Windows startup or login feels slow, startup apps keep re-enabling themselves, or Codex needs to audit, disable, speed up, or move Windows startup entries across Run keys, StartupApproved, Startup folders, scheduled logon/boot tasks, and services.
---

# Windows Startup Tuning

## Overview

Windows "startup apps" are split across registry Run keys, StartupApproved state, Startup folders, scheduled tasks, and services. Treat "开机启动" carefully: UI/tray apps usually mean "after user logon", while services and boot tasks can run before the desktop exists.

Core rule: gather evidence and back up before changing anything.

## Quick Audit

Run the bundled read-only audit first:

```powershell
& "$HOME\opencode-skills\windows-startup-tuning\scripts\audit-startup.ps1"
```

If the skill is installed into OpenCode:

```powershell
& "$HOME\.config\opencode\skills\windows-startup-tuning\scripts\audit-startup.ps1"
```

Use the audit to answer four questions:

1. Which startup entry actually exists?
2. Is it enabled in `StartupApproved`?
3. Is there a scheduled task or service that can start it anyway?
4. Is perceived slowness caused by explicit task delay, Windows startup delay, or a heavy app queue?

## Evidence Workflow

1. List classic startup entries:

```powershell
Get-CimInstance Win32_StartupCommand |
  Select-Object Name,Command,Location,User |
  Sort-Object Location,Name |
  Format-Table -AutoSize -Wrap
```

2. Check real Run keys and Startup folders. `Win32_StartupCommand` can show entries even when Task Manager marks them disabled.

```powershell
$runKeys = @(
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($key in $runKeys) {
  $item = Get-Item -LiteralPath $key -ErrorAction SilentlyContinue
  if ($item) {
    foreach ($name in $item.GetValueNames()) {
      [pscustomobject]@{ Path=$key; Name=$name; Command=$item.GetValue($name) }
    }
  }
}
```

3. Decode `StartupApproved`. First byte values used here:

| First byte | Meaning |
|---:|---|
| `2` or `6` | Enabled |
| `3` or `7` | Disabled |

Important paths:

| Startup source | StartupApproved path |
|---|---|
| HKCU Run | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run` |
| HKLM Run | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run` |
| HKLM 32-bit Run | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32` |
| User Startup folder | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder` |
| Common Startup folder | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder` |

4. Inspect scheduled tasks with logon or boot triggers:

```powershell
Get-ScheduledTask |
  Where-Object {
    $_.State -ne 'Disabled' -and
    ($_.Triggers | Where-Object {
      $_.CimClass.CimClassName -like '*LogonTrigger*' -or
      $_.CimClass.CimClassName -like '*BootTrigger*'
    })
  } |
  Select-Object TaskPath,TaskName,State,
    @{Name='Triggers';Expression={($_.Triggers | ForEach-Object { $_.CimClass.CimClassName + ':' + $_.Enabled + ':Delay=' + $_.Delay }) -join '; '}},
    @{Name='Actions';Expression={($_.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) -join '; '}},
    @{Name='UserId';Expression={$_.Principal.UserId}},
    @{Name='LogonType';Expression={$_.Principal.LogonType}},
    @{Name='RunLevel';Expression={$_.Principal.RunLevel}} |
  Sort-Object TaskPath,TaskName |
  Format-Table -AutoSize -Wrap
```

`PT10M` means the task intentionally waits 10 minutes after logon.

5. Check services when an app keeps running after disabling startup. Example:

```powershell
Get-CimInstance Win32_Service |
  Where-Object { $_.Name -match 'GameViewer|Hermes|QQ|RustDesk' -or $_.PathName -match 'GameViewer|Hermes|QQ|RustDesk' } |
  Select-Object Name,DisplayName,State,StartMode,StartName,PathName |
  Format-Table -AutoSize -Wrap
```

## Safety Rules

1. Back up registry keys and scheduled task XML before changing state.
2. Prefer disabling via `StartupApproved` before deleting Run values or shortcuts.
3. Do not remove entries the user asked to keep.
4. Do not convert every logon task to a boot task. UI/tray apps need a user desktop session.
5. Keep a log when running elevated scripts.
6. Use `-EncodedCommand` for elevated PowerShell that contains Chinese names such as `SOLIDWORKS 2024 快速启动.lnk`; plain UTF-8 script launch may create mojibake registry values.

## Backups

Create a timestamped folder:

```powershell
$backupDir = Join-Path $HOME ("Desktop\startup-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
```

Export registry keys:

```powershell
reg export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' "$backupDir\HKCU_Run.reg" /y
reg export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' "$backupDir\HKCU_StartupApproved_Run.reg" /y
reg export 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' "$backupDir\HKLM_StartupApproved_Run32.reg" /y
reg export 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' "$backupDir\HKLM_StartupApproved_StartupFolder.reg" /y
```

Export a task:

```powershell
Export-ScheduledTask -TaskPath '\' -TaskName 'HermesQQGateway' |
  Set-Content -LiteralPath "$backupDir\HermesQQGateway.xml" -Encoding UTF8
```

## Disable Startup Entries

Disable a Task Manager startup entry by writing the binary disabled state:

```powershell
$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$name = 'RazerAppEngine'
New-ItemProperty -LiteralPath $path -Name $name -PropertyType Binary -Value ([byte[]](3,0,0,0,0,0,0,0,0,0,0,0)) -Force | Out-Null
```

For 32-bit HKLM Run entries such as `Adobe CCXProcess`, `HPUsageTracking`, or `vmware-tray.exe`, use:

```powershell
$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
```

For Common Startup shortcuts such as `SOLIDWORKS 2024 快速启动.lnk`, use:

```powershell
$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
```

## Disable Scheduled Tasks

Stop a running task first, then disable it:

```powershell
Stop-ScheduledTask -TaskPath '\DouyinUser\DouyinGuard\' -TaskName 'LaunchDouyinGuard' -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskPath '\DouyinUser\DouyinGuard\' -TaskName 'LaunchDouyinGuard'
Get-Process -Name 'douyin_guard' -ErrorAction SilentlyContinue | Stop-Process -Force
```

If disabling returns `Access is denied`, run the same change elevated.

## Elevated Unicode-Safe Pattern

Use this pattern when a registry/task name contains Chinese or when HKLM changes require admin:

```powershell
$cmd = @'
$log = "$HOME\Desktop\startup-admin-fix.log"
"=== startup admin fix $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Set-Content -LiteralPath $log -Encoding UTF8
$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
$name = 'SOLIDWORKS 2024 快速启动.lnk'
New-ItemProperty -LiteralPath $path -Name $name -PropertyType Binary -Value ([byte[]](3,0,0,0,0,0,0,0,0,0,0,0)) -Force | Out-Null
"After: $((Get-Item -LiteralPath $path).GetValue($name) -join ',')" | Add-Content -LiteralPath $log -Encoding UTF8
'@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
Start-Process powershell.exe -ArgumentList @('-NoProfile','-EncodedCommand',$encoded) -Verb RunAs -WindowStyle Normal
```

After elevated work, read the log and re-query the real registry values. Remove any mojibake value if one was accidentally created.

## Boot Trigger vs Logon Trigger

Use this decision table:

| App type | Recommended trigger |
|---|---|
| Windows service, daemon without UI | Service auto-start or boot trigger |
| Tray app, UI app, app needing user profile/session | Logon trigger |
| User automation that can start early but also needs desktop fallback | Keep logon trigger and add boot trigger |

When adding boot trigger to a user task such as `HermesQQGateway`, keep the logon trigger:

```powershell
$taskName = 'HermesQQGateway'
$task = Get-ScheduledTask -TaskName $taskName
$triggers = @($task.Triggers)
if (-not ($triggers | Where-Object { $_.CimClass.CimClassName -like '*BootTrigger*' })) {
  $triggers += New-ScheduledTaskTrigger -AtStartup
  Set-ScheduledTask -TaskName $taskName -Trigger $triggers
}
```

Reason: the boot trigger can try early, while the logon trigger is the desktop/session fallback. This is safer than replacing logon with boot.

## Diagnose Slow Login Startup

Compare system boot, Explorer start, scheduled task start, and app process start times:

```powershell
$os = Get-CimInstance Win32_OperatingSystem
Get-Process explorer | Select-Object ProcessName,Id,StartTime
Get-Process |
  Where-Object { $_.Path -match 'QQ|uTools|OneDrive|RustDesk|v2rayN|Everything|PixPin|TrafficMonitor|GameViewer|Mem Reduct' } |
  Select-Object ProcessName,Id,StartTime,Path |
  Sort-Object StartTime |
  Format-Table -AutoSize -Wrap
[pscustomobject]@{ Boot=$os.LastBootUpTime; Now=Get-Date }
```

Check explicit scheduled task delays:

```powershell
Get-ScheduledTask |
  Where-Object { $_.State -ne 'Disabled' -and ($_.Triggers | Where-Object { $_.CimClass.CimClassName -like '*LogonTrigger*' }) } |
  ForEach-Object {
    $task = $_
    foreach ($tr in $task.Triggers) {
      if ($tr.CimClass.CimClassName -like '*LogonTrigger*') {
        [pscustomobject]@{ Task=$task.TaskPath+$task.TaskName; State=$task.State; Delay=$tr.Delay }
      }
    }
  } |
  Sort-Object Task |
  Format-Table -AutoSize -Wrap
```

If Explorer starts quickly but Run-key apps start 45-120 seconds later, disable Windows Explorer's startup app delay for the current user:

```powershell
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
New-ItemProperty -LiteralPath $key -Name 'StartupDelayInMSec' -PropertyType DWord -Value 0 -Force | Out-Null
```

This takes effect after the next sign-out or reboot.

## Known Machine-Specific Clues

On Pans0020's Windows machine:

| Entry | Meaning |
|---|---|
| `GameViewer` | NetEase `网易UU远程`; also installs `GameViewerService` with `Auto` start |
| `HermesQQGateway` | Local Hermes QQ gateway: scheduled task -> `wscript.exe` -> hidden PowerShell watchdog -> Python runner |
| `DouyinGuard` | Douyin scheduled task may require admin to disable |
| `OneDrive Startup Task...` | Often has `PT10M` logon delay even if OneDrive also starts from Run |
| `PixPin` / `TrafficMonitor` | Scheduled logon tasks with short `PT3S` delay |

## Verification

Never claim success until a fresh query shows the final state:

```powershell
Get-ScheduledTask -TaskPath '\DouyinUser\DouyinGuard\' -TaskName 'LaunchDouyinGuard' |
  Select-Object TaskPath,TaskName,State

(Get-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize').GetValue('StartupDelayInMSec')
```

For startup speed, reboot or sign out/in, then compare `Explorer` and target app `StartTime` values from the new session.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Treating Task Manager startup state as the whole truth | Check Run keys, StartupApproved, scheduled tasks, and services |
| Using `WOW6432Node\...\StartupApproved\Run` | Use `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32` |
| Replacing logon triggers with boot triggers for tray apps | Keep logon trigger; add boot only when early start is useful and safe |
| Ignoring `Delay=PT10M` | The task is intentionally delayed by 10 minutes |
| Launching elevated UTF-8 scripts containing Chinese names directly | Use `-EncodedCommand` with UTF-16LE |
| Saying "fixed" after editing only | Re-query final registry/task state and, for speed, verify after next reboot |
