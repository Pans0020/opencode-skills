[CmdletBinding()]
param(
    [switch]$IncludeMicrosoft,
    [switch]$Json
)

$ErrorActionPreference = 'Continue'

function Get-StartupApprovedStatus {
    param(
        [string]$Path,
        [string]$Name
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) {
        return [pscustomobject]@{
            Status = 'MissingKey'
            FirstByte = $null
            Bytes = $null
        }
    }

    $bytes = $item.GetValue($Name)
    if ($null -eq $bytes) {
        return [pscustomobject]@{
            Status = 'MissingValue'
            FirstByte = $null
            Bytes = $null
        }
    }

    $first = [int]$bytes[0]
    $status = if ($first -eq 2 -or $first -eq 6) {
        'Enabled'
    } elseif ($first -eq 3 -or $first -eq 7) {
        'Disabled'
    } else {
        "Unknown($first)"
    }

    [pscustomobject]@{
        Status = $status
        FirstByte = $first
        Bytes = ($bytes -join ',')
    }
}

function Get-RunEntries {
    $entries = @()
    $sources = @(
        @{
            Scope = 'HKCU Run'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            ApprovedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        },
        @{
            Scope = 'HKLM Run'
            Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            ApprovedPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        },
        @{
            Scope = 'HKLM 32-bit Run'
            Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
            ApprovedPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
        }
    )

    foreach ($source in $sources) {
        $item = Get-Item -LiteralPath $source.Path -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        foreach ($name in $item.GetValueNames()) {
            $approved = Get-StartupApprovedStatus -Path $source.ApprovedPath -Name $name
            $entries += [pscustomobject]@{
                Scope = $source.Scope
                Name = $name
                Status = $approved.Status
                FirstByte = $approved.FirstByte
                Command = $item.GetValue($name)
            }
        }
    }
    $entries
}

function Get-StartupFolderEntries {
    $entries = @()
    $sources = @(
        @{
            Scope = 'User Startup'
            Folder = [Environment]::GetFolderPath('Startup')
            ApprovedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
        },
        @{
            Scope = 'Common Startup'
            Folder = [Environment]::GetFolderPath('CommonStartup')
            ApprovedPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
        }
    )

    foreach ($source in $sources) {
        if (-not (Test-Path -LiteralPath $source.Folder)) { continue }
        Get-ChildItem -LiteralPath $source.Folder -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'desktop.ini' } |
            ForEach-Object {
                $approved = Get-StartupApprovedStatus -Path $source.ApprovedPath -Name $_.Name
                $entries += [pscustomobject]@{
                    Scope = $source.Scope
                    Name = $_.Name
                    Status = $approved.Status
                    FirstByte = $approved.FirstByte
                    Path = $_.FullName
                }
            }
    }
    $entries
}

function Get-TriggerTasks {
    $tasks = Get-ScheduledTask | Where-Object {
        $_.State -ne 'Disabled' -and
        ($IncludeMicrosoft -or $_.TaskPath -notlike '\Microsoft\*') -and
        ($_.Triggers | Where-Object {
            $_.CimClass.CimClassName -like '*LogonTrigger*' -or
            $_.CimClass.CimClassName -like '*BootTrigger*'
        })
    }

    foreach ($task in $tasks) {
        foreach ($trigger in $task.Triggers) {
            if ($trigger.CimClass.CimClassName -like '*LogonTrigger*' -or $trigger.CimClass.CimClassName -like '*BootTrigger*') {
                [pscustomobject]@{
                    Task = $task.TaskPath + $task.TaskName
                    State = $task.State
                    Trigger = $trigger.CimClass.CimClassName
                    Enabled = $trigger.Enabled
                    Delay = [string]$trigger.Delay
                    UserId = $task.Principal.UserId
                    LogonType = $task.Principal.LogonType
                    RunLevel = $task.Principal.RunLevel
                    Action = (($task.Actions | ForEach-Object { ($_.Execute + ' ' + $_.Arguments).Trim() }) -join '; ')
                }
            }
        }
    }
}

function Get-ExplorerStartupDelay {
    $paths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
    )

    foreach ($path in $paths) {
        $item = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Path = $path
            StartupDelayInMSec = if ($item) { $item.StartupDelayInMSec } else { $null }
        }
    }
}

function Get-RecentStartupProcesses {
    $patterns = 'QQ|uTools|OneDrive|RustDesk|v2rayN|Everything|PixPin|TrafficMonitor|GameViewer|Mem Reduct|DeskGo|HipsTray|Docker|Notion'
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -match $patterns -or $_.ProcessName -match $patterns } |
        Select-Object ProcessName,Id,StartTime,Path |
        Sort-Object StartTime
}

$os = Get-CimInstance Win32_OperatingSystem
$explorer = Get-Process explorer -ErrorAction SilentlyContinue | Select-Object ProcessName,Id,StartTime,Path

$result = [pscustomobject]@{
    GeneratedAt = Get-Date
    Boot = [pscustomobject]@{
        LastBootUpTime = $os.LastBootUpTime
        Uptime = [string]((Get-Date) - $os.LastBootUpTime)
        Explorer = $explorer
    }
    ExplorerStartupDelay = @(Get-ExplorerStartupDelay)
    RunEntries = @(Get-RunEntries)
    StartupFolderEntries = @(Get-StartupFolderEntries)
    TriggerTasks = @(Get-TriggerTasks)
    RecentStartupProcesses = @(Get-RecentStartupProcesses)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
    return
}

'=== Boot ==='
$result.Boot | Format-List
''
'=== Explorer Startup Delay ==='
$result.ExplorerStartupDelay | Format-Table -AutoSize -Wrap
''
'=== Run Entries ==='
$result.RunEntries | Sort-Object Scope,Name | Format-Table -AutoSize -Wrap
''
'=== Startup Folder Entries ==='
$result.StartupFolderEntries | Sort-Object Scope,Name | Format-Table -AutoSize -Wrap
''
'=== Scheduled Logon/Boot Tasks ==='
$result.TriggerTasks | Sort-Object Task,Trigger | Format-Table -AutoSize -Wrap
''
'=== Recent Startup Processes ==='
$result.RecentStartupProcesses | Format-Table -AutoSize -Wrap
