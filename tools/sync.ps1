<#
.SYNOPSIS
    Kopiert MetaCodex aus dem Repo in den WoW-AddOns-Ordner.

.DESCRIPTION
    Spiegelt die Repo-Wurzel nach AddOns\MetaCodex. Entwicklungsdateien
    (docs, tools, branding, .git, Markdown) bleiben draussen.

.PARAMETER WowPath
    Pfad zum _retail_-Ordner. Standard: C:\Spiele\World of Warcraft\_retail_

.PARAMETER Watch
    Beobachtet das Repo und synchronisiert bei jeder Aenderung automatisch.

.EXAMPLE
    .\tools\sync.ps1
    .\tools\sync.ps1 -Watch
#>

[CmdletBinding()]
param(
    [string]$WowPath = "C:\Spiele\World of Warcraft\_retail_",
    [switch]$Watch
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AddOns   = Join-Path $WowPath "Interface\AddOns"

if (-not (Test-Path $AddOns)) {
    Write-Error "AddOns-Ordner nicht gefunden: $AddOns"
    exit 1
}

# Auctionator ist bewusst nur OptionalDeps: ohne ihn laedt MetaCodex und zeigt
# die Liste, nur die Uebergabe fehlt. Ein Hinweis genuegt deshalb.
$auctionator = Join-Path $AddOns "Auctionator"
if (-not (Test-Path $auctionator)) {
    Write-Host "Auctionator nicht gefunden: $auctionator" -ForegroundColor Yellow
    Write-Host "MetaCodex laedt trotzdem - die Uebergabeknoepfe bleiben grau." -ForegroundColor Yellow
}

# Ohne erzeugten Katalog ist das Addon leer. Das faellt sonst erst im Spiel
# auf, und dann sucht man an der falschen Stelle.
$catalog = Join-Path $RepoRoot "MetaCodex_Data\Catalog.lua"
if (-not (Test-Path $catalog)) {
    Write-Host "MetaCodex_Data\Catalog.lua fehlt. Erst erzeugen:" -ForegroundColor Yellow
    Write-Host "    node tools\build-catalog.js ." -ForegroundColor Yellow
}

# Sicherheitsnetz: /MIR loescht im Ziel. Nur eigene Ordner zulassen.
function Assert-SafeTarget {
    param([string]$Target)
    $leaf = Split-Path -Leaf $Target
    if ($leaf -notlike "MetaCodex*") {
        throw "Unerwarteter Zielordner: $Target"
    }
}

# Drei Addons, drei Ziele: MetaCodex, das nachladbare MetaCodex_Data und
# das freiwillige MetaCodex_Dungeons.
# Wuerde der Datenordner mit der Wurzel gespiegelt, landete er INNERHALB
# von MetaCodex - und waere damit kein eigenes Addon mehr.

function Sync-Addon {
    param(
        [string]$Source,
        [string]$Target,
        [string[]]$ExcludeDirs  = @(),
        [string[]]$ExcludeFiles = @()
    )

    Assert-SafeTarget $Target

    $roboArgs = @($Source, $Target, "/MIR", "/NJH", "/NJS", "/NP", "/NDL", "/NFL", "/R:2", "/W:1")
    if ($ExcludeDirs.Count)  { $roboArgs += "/XD"; $roboArgs += $ExcludeDirs }
    if ($ExcludeFiles.Count) { $roboArgs += "/XF"; $roboArgs += $ExcludeFiles }

    robocopy @roboArgs | Out-Null

    # Robocopy: Exit-Codes 0-7 sind Erfolg, ab 8 liegt ein Fehler vor.
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy fehlgeschlagen ($LASTEXITCODE): $Source -> $Target"
    }

    # Sonst erbt das Skript den Robocopy-Code (1 = "Dateien kopiert") als Fehler.
    $global:LASTEXITCODE = 0
}

function Invoke-Sync {
    $stamp = Get-Date -Format "HH:mm:ss"

    Sync-Addon -Source $RepoRoot `
               -Target (Join-Path $AddOns "MetaCodex") `
               -ExcludeDirs  @(".git", ".github", ".release", ".vscode", "docs", "tools", "branding", "Tests", "MetaCodex_Data", "MetaCodex_Dungeons", "MetaCodex_Players", "intern", "node_modules") `
               -ExcludeFiles @("*.md", "*.ps1", "*.mjs", ".gitignore", ".gitattributes", ".pkgmeta", ".luacheckrc", ".editorconfig")

    $dataSource = Join-Path $RepoRoot "MetaCodex_Data"
    if (Test-Path $dataSource) {
        Sync-Addon -Source $dataSource `
                   -Target (Join-Path $AddOns "MetaCodex_Data") `
                   -ExcludeFiles @("*.md")
    } else {
        Write-Host "MetaCodex_Data fehlt - erst die Sammler laufen lassen." -ForegroundColor Yellow
    }

    # Die Auswertung je Dungeon ist freiwillig: fehlt sie, faellt nur die
    # Dungeon-Auswahl weg. Deshalb hier auch keine Warnung.
    $dungeonSource = Join-Path $RepoRoot "MetaCodex_Dungeons"
    if (Test-Path $dungeonSource) {
        Sync-Addon -Source $dungeonSource `
                   -Target (Join-Path $AddOns "MetaCodex_Dungeons") `
                   -ExcludeFiles @("*.md")
    }

    $playerSource = Join-Path $RepoRoot "MetaCodex_Players"
    if (Test-Path $playerSource) {
        Sync-Addon -Source $playerSource `
                   -Target (Join-Path $AddOns "MetaCodex_Players") `
                   -ExcludeFiles @("*.md")
    }

    Write-Host "[$stamp] MetaCodex synchronisiert" -ForegroundColor Green
}

Invoke-Sync

if (-not $Watch) {
    Write-Host "Fertig. Im Spiel: /reload" -ForegroundColor Cyan
    return
}

Write-Host "Beobachte $RepoRoot - Beenden mit Strg+C" -ForegroundColor Cyan

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path                  = $RepoRoot
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents   = $true

$lastRun = [datetime]::MinValue

while ($true) {
    $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1000)
    if ($change.TimedOut) { continue }

    if ($change.Name -match '^(\.git|\.release|docs|tools|branding|Tests|node_modules)') { continue }

    # Editoren feuern mehrere Ereignisse pro Speichervorgang - entprellen.
    if (([datetime]::Now - $lastRun).TotalMilliseconds -lt 400) { continue }
    $lastRun = [datetime]::Now

    Start-Sleep -Milliseconds 150
    try   { Invoke-Sync }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red }
}
