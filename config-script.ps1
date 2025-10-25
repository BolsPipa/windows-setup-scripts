# ============================================
# install_apps.ps1 – Automatische Installation (stabil + Setup-kompatibel)
# Änderungen:
# - Lokalisierungsunabhängige Prüfung, ob ein Paket bereits installiert ist
# - Klarere Fehler-/Output-Redirection in Winget-Init-Job
# - Sicherer Relaunch als Administrator (Fallback, wenn $PSCommandPath leer ist)
# - Kleinere Robustheitsverbesserungen
# ============================================

Write-Host "Starte Software-Installation..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Einstellungen ---
$UseSilent = $false
$CreateLog = $true
$LogDir = "C:\Windows\Setup\Logs"
$LogFile = Join-Path $LogDir "install.log"

if ($CreateLog) {
    if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
    "`n==== Installation gestartet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" | Out-File -FilePath $LogFile -Encoding utf8 -Append
}

function Log {
    param([string]$Text)
    Write-Host $Text
    if ($CreateLog) { $Text | Out-File -FilePath $LogFile -Encoding utf8 -Append }
}

# --- Winget-Initialisierung (nicht-blockierend) ---
Log "Initialisiere Winget-Datenbank (nicht-blockierend)..."
try {
    # Store-Quelle entfernen, damit keine Lizenzabfrage kommt
    Start-Job -ScriptBlock {
        try {
            # 2>$null ist kompatibler zu PowerShell 5.1 und PowerShell 7
            winget source remove msstore -y 2>$null
            winget source reset --force 2>$null
            winget source update 2>$null
        } catch {}
    } | Out-Null
    Start-Sleep -Seconds 5
    Log "Winget-Initialisierung im Hintergrund gestartet."
} catch {
    Log "Fehler bei Winget-Initialisierung: $_"
}

# --- Prüfen ob Winget verfügbar ---
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log "Winget ist nicht verfügbar. Stelle sicher, dass 'App Installer' installiert ist."
    exit 1
}

# --- Adminrechte prüfen ---
function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Log "Script lauft nicht als Administrator. Versuche Neustart..."
    # Versuche verlässliche Pfadbestimmung des aktuell ausgeführten Skripts
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }
    if (-not $scriptPath) {
        Log "Konnte Skriptpfad nicht ermitteln. Bitte Skript aus Datei ausführen."
        exit 1
    }
    $argList = @("-NoProfile","-ExecutionPolicy","Bypass","-File",$scriptPath)
    Start-Process -FilePath "powershell" -ArgumentList $argList -Verb RunAs -WindowStyle Normal
    exit 0
}

# Optional: bessere Append-Performance bei vielen Einträgen
[System.Collections.ArrayList]$results = @()

# --- Installationsfunktion ---
function Install-App {
    param ([string]$Name, [string]$PackageID)

    Log "=> Prüfe $Name (ID: $PackageID)..."

    # Timeout-geschützte Prüfung: winget show
    $proc = Start-Process -FilePath "winget" -ArgumentList @("show","--id",$PackageID,"--exact") -PassThru -WindowStyle Hidden
    if (-not $proc.WaitForExit(30*1000)) {
        try { $proc.Kill() } catch {}
        Log "Winget-Anfrage für $Name hat zu lange gedauert, überspringe..."
        $results.Add([pscustomobject]@{Name=$Name;Status="Timeout";Message="Winget-Show hing zu lange."}) | Out-Null
        return
    }

    if ($proc.ExitCode -ne 0) {
        $msg = "Paket $PackageID wurde in Winget nicht gefunden."
        Log $msg
        $results.Add([pscustomobject]@{Name=$Name;Status="NotFound";Message=$msg}) | Out-Null
        return
    }

    # Prüfen ob installiert — lokalitätsunabhängig: auf leere Ausgabe prüfen
    $listOutput = (& winget list --id $PackageID --exact 2>$null) -join "`n"
    if ($listOutput -and $listOutput.Trim().Length -gt 0) {
        $msg = "$Name ist bereits installiert. Überspringe..."
        Log $msg
        $results.Add([pscustomobject]@{Name=$Name;Status="AlreadyInstalled";Message=$msg}) | Out-Null
        return
    }

    # Installation starten
    Log "Installiere $Name..."
    $args = @("install","--id",$PackageID,"--accept-package-agreements","--accept-source-agreements","--exact")
    if ($UseSilent) { $args += "--silent" }

    $proc = Start-Process -FilePath "winget" -ArgumentList $args -PassThru -WindowStyle Hidden
    if (-not $proc.WaitForExit(600*1000)) { # 10 Minuten Timeout
        try { $proc.Kill() } catch {}
        Log "Installation von $Name hat zu lange gedauert – abgebrochen."
        $results.Add([pscustomobject]@{Name=$Name;Status="Timeout";Message="Installation zu lange gedauert."}) | Out-Null
        return
    }

    if ($proc.ExitCode -eq 0) {
        $msg = "$Name erfolgreich installiert."
        Log $msg
        $results.Add([pscustomobject]@{Name=$Name;Status="Installed";Message=$msg}) | Out-Null
    } else {
        $msg = "Fehler bei $Name (ExitCode=$($proc.ExitCode))."
        Log $msg
        $results.Add([pscustomobject]@{Name=$Name;Status="Failed";Message=$msg;ExitCode=$proc.ExitCode}) | Out-Null
    }
}

# --- App-Liste ---
$apps = @(
    @{Name="Blender"; ID="BlenderFoundation.Blender"},
    @{Name="Mozilla Firefox"; ID="Mozilla.Firefox"},
    @{Name="7-Zip"; ID="7zip.7zip"},
    @{Name="Steam"; ID="Valve.Steam"},
    @{Name="Godot Engine"; ID="GodotEngine.GodotEngine"},
    @{Name="Visual Studio 2022 Community"; ID="Microsoft.VisualStudio.2022.Community"}
)

# --- Hauptlauf ---
foreach ($app in $apps) {
    try {
        Install-App -Name $app.Name -PackageID $app.ID
    } catch {
        Log "Unbehandelter Fehler bei $($app.Name): $_"
        $results.Add([pscustomobject]@{Name=$app.Name;Status="Error";Message=$_.Exception.Message}) | Out-Null
    }
}

# --- Zusammenfassung ---
Log "`n=== Zusammenfassung ==="
$results | Format-Table -AutoSize | Out-String | ForEach-Object { Log $_ }

if ($CreateLog) {
    "`n==== Installation beendet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====`n" | Out-File -FilePath $LogFile -Encoding utf8 -Append
    Log "Log-Datei gespeichert unter: $LogFile"
}

Log "Fertig. Bitte Ausgabe oder Log pruefen."
Start-Sleep -Seconds 3
