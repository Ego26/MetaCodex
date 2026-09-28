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
    [switch]$Watch,

    # Daten aus dem eigenen Sammellauf statt aus dem Nachtlauf.
    # Gedacht fuer den Moment, in dem man gerade selbst etwas
    # gesammelt hat und genau das sehen will.
    [switch]$LokaleDaten,

    # Das Nachtlauf-Zip neu holen, auch wenn schon eines liegt.
    [switch]$Neu
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

# Warnen, wenn eine lokal gesammelte Quelle alt ist.
#
# Gilt nur noch fuer -LokaleDaten. Im Normalfall kommen die Daten aus
# dem Nachtlauf und sind von heute Nacht; dann waere die Warnung eine
# Meldung ueber Dateien, die gar niemand benutzt.
function Warn-AlteDaten {
    $rohdaten = Join-Path $RepoRoot "tools\data"
    if (-not (Test-Path $rohdaten)) { return }

    $alt = Get-ChildItem -Path $rohdaten -Filter "wcl-*.json" -File |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-2) }
    if (-not $alt) { return }

    Write-Host ""
    Write-Host "ACHTUNG: diese gesammelten Daten sind aelter als zwei Tage." -ForegroundColor Yellow
    Write-Host "Sie werden trotzdem ins Spiel gespielt und ueberschreiben dort Neueres:" -ForegroundColor Yellow
    foreach ($f in ($alt | Sort-Object LastWriteTime)) {
        Write-Host ("    {0,-40} {1:dd.MM. HH:mm}" -f $f.Name, $f.LastWriteTime) -ForegroundColor Yellow
    }
    Write-Host "Ohne -LokaleDaten haette der Nachtlauf frische geliefert." -ForegroundColor Yellow
    Write-Host ""
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

# Die Daten des letzten Nachtlaufs.
#
# WARUM NICHT DIE AUS DEM REPO. Lokal wird immer nur an einer Quelle
# gesammelt - wer an M+ arbeitet, hat Raid-Daten von vorgestern liegen.
# Spielt der Sync die mit ins Spiel, ist dort hinterher WENIGER als
# vorher. Genau das ist am 28.09. passiert: frische M+-Zahlen kamen an,
# und ein Raidboss samt zweier Bosslisten verschwand dabei.
#
# Der Nachtlauf sammelt jede Nacht ALLES. Sein Zip haengt am Release
# "nightly" und ist oeffentlich - kein Anmelden noetig. Von dort
# kommen die drei Datenordner, aus dem Repo nur der Code. Damit sieht
# ein Entwicklungsstand immer aus wie der Nachtlauf, plus dem, woran
# man gerade arbeitet.
function Get-NachtlaufDaten {
    $ziel = Join-Path $env:TEMP "MetaCodex-nightly"
    $zip  = Join-Path $ziel "nightly.zip"
    $marke = Join-Path $ziel "stand.txt"
    $heute = (Get-Date).ToUniversalTime().ToString("yyyyMMdd")

    # Schon geholt und von heute? Dann nicht noch einmal.
    if ((-not $Neu) -and (Test-Path $marke) -and
        ((Get-Content $marke -Raw).Trim() -eq $heute) -and
        (Test-Path (Join-Path $ziel "MetaCodex_Data"))) {
        return $ziel
    }

    New-Item -ItemType Directory -Force -Path $ziel | Out-Null
    # Der Lauf von heute, sonst der von gestern: vor 02:05 Wien gibt es
    # das heutige Zip noch nicht.
    $kandidaten = @($heute, (Get-Date).ToUniversalTime().AddDays(-1).ToString("yyyyMMdd"))
    foreach ($tag in $kandidaten) {
        $url = "https://github.com/Ego26/MetaCodex/releases/download/nightly/MetaCodex-nightly-$tag.zip"
        try {
            Write-Host "Hole die Daten des Nachtlaufs ($tag) ..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
        } catch { continue }
        foreach ($ordner in @("MetaCodex_Data", "MetaCodex_Dungeons", "MetaCodex_Players")) {
            $alt = Join-Path $ziel $ordner
            if (Test-Path $alt) { Remove-Item $alt -Recurse -Force }
        }
        Expand-Archive -Path $zip -DestinationPath $ziel -Force
        Set-Content -Path $marke -Value $tag -Encoding utf8
        return $ziel
    }
    Write-Host "Kein Nachtlauf-Zip erreichbar - nehme die lokalen Daten." -ForegroundColor Yellow
    return $null
}
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

    # Woher die Daten kommen. Der Code kommt immer aus dem Repo.
    $datenWurzel = $RepoRoot
    if (-not $LokaleDaten) {
        $geholt = Get-NachtlaufDaten
        if ($geholt) { $datenWurzel = $geholt }
    }
    if ($datenWurzel -eq $RepoRoot) {
        Warn-AlteDaten
        Write-Host "Daten: lokal gesammelt" -ForegroundColor DarkGray
    } else {
        Write-Host "Daten: aus dem Nachtlauf" -ForegroundColor DarkGray
    }

    $dataSource = Join-Path $datenWurzel "MetaCodex_Data"
    if (Test-Path $dataSource) {
        Sync-Addon -Source $dataSource `
                   -Target (Join-Path $AddOns "MetaCodex_Data") `
                   -ExcludeFiles @("*.md")
    } else {
        Write-Host "MetaCodex_Data fehlt - erst die Sammler laufen lassen." -ForegroundColor Yellow
    }

    # Die Auswertung je Dungeon ist freiwillig: fehlt sie, faellt nur die
    # Dungeon-Auswahl weg. Deshalb hier auch keine Warnung.
    $dungeonSource = Join-Path $datenWurzel "MetaCodex_Dungeons"
    if (Test-Path $dungeonSource) {
        Sync-Addon -Source $dungeonSource `
                   -Target (Join-Path $AddOns "MetaCodex_Dungeons") `
                   -ExcludeFiles @("*.md")
    }

    $playerSource = Join-Path $datenWurzel "MetaCodex_Players"
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
