<#
.SYNOPSIS
    Richtet den taeglichen Datenlauf als Windows-Aufgabe ein.

.DESCRIPTION
    Einmal ausfuehren, danach laeuft jeden Morgen um 06:00:

        node tools/collect-all.js <Repo>      alle Quellen, in der richtigen Reihenfolge
        tools/sync.ps1                        das Ergebnis ins Spiel

    Warum eine Aufgabe und keine GitHub-Action: die Warcraft-Logs-Zugangsdaten
    liegen in tools/wcl-credentials.json und bleiben auf diesem Rechner. Und
    murlok.io wird von hier abgerufen, mit einem Browser-User-Agent, den ein
    Rechenzentrum nicht bekommt.

    Der Lauf braucht etwa eine Stunde (Warcraft Logs wartet auf sein Kontingent)
    und schreibt sein Protokoll nach tools/data/last-run.log.

.PARAMETER At
    Uhrzeit, Vorgabe 06:00.

.PARAMETER WowPath
    Wird an sync.ps1 durchgereicht.

.PARAMETER Unregister
    Entfernt die Aufgabe wieder.

.PARAMETER Now
    Startet den Lauf sofort, zusaetzlich zur Registrierung.

.EXAMPLE
    .\tools\schedule.ps1
    .\tools\schedule.ps1 -At 05:30 -Now
    .\tools\schedule.ps1 -Unregister
#>

[CmdletBinding()]
param(
    [string]$At = "06:00",
    [string]$WowPath = "C:\Spiele\World of Warcraft\_retail_",
    [switch]$Unregister,
    [switch]$Now
)

$ErrorActionPreference = "Stop"

$TaskName = "MetaCodex - taeglicher Datenlauf"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Runner   = Join-Path $PSScriptRoot "run-daily.ps1"

if ($Unregister) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Aufgabe entfernt: $TaskName" -ForegroundColor Green
    } else {
        Write-Host "Keine Aufgabe registriert." -ForegroundColor Yellow
    }
    return
}

# Node muss fuer die Aufgabe auffindbar sein - mit vollem Pfad, denn die
# Aufgabe laeuft ohne das PATH der Sitzung, in der sie eingerichtet wurde.
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) { throw "node.exe nicht gefunden. Node.js muss installiert sein." }

if (-not (Test-Path (Join-Path $PSScriptRoot "wcl-credentials.json"))) {
    Write-Host "Hinweis: tools/wcl-credentials.json fehlt - der Raid- und Verbrauchsgueter-Teil wird fehlschlagen." -ForegroundColor Yellow
}

# Das Laufskript: alles in eine Datei protokolliert, damit ein Lauf, der
# um sechs Uhr morgens scheitert, am Abend noch erklaert, warum.
$runner = @"
`$ErrorActionPreference = 'Continue'
`$log = Join-Path '$RepoRoot' 'tools\data\last-run.log'
"=== Lauf am `$(Get-Date -Format 'yyyy-MM-dd HH:mm') ===" | Out-File `$log -Encoding utf8
& '$node' '$RepoRoot\tools\collect-all.js' '$RepoRoot' 2>&1 | Out-File `$log -Append -Encoding utf8
& powershell -NoProfile -ExecutionPolicy Bypass -File '$RepoRoot\tools\sync.ps1' -WowPath '$WowPath' 2>&1 | Out-File `$log -Append -Encoding utf8
"=== Ende `$(Get-Date -Format 'HH:mm') ===" | Out-File `$log -Append -Encoding utf8
"@
$runner | Out-File $Runner -Encoding utf8

$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Runner`"" `
    -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Daily -At $At
# Verpasste Laeufe nachholen: der Rechner ist morgens nicht immer an.
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Host "Aufgabe registriert: $TaskName, taeglich um $At" -ForegroundColor Green
Write-Host "Protokoll: tools\data\last-run.log"

if ($Now) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Lauf gestartet."
}
