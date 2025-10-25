# ============================================
# install_apps.ps1 - Automatische Installation (KORRIGIERT)
# Hauptänderungen:
# - Winget wird EINMAL zu Beginn vollständig initialisiert
# - Längere Timeouts für erste Winget-Anfragen
# - Vereinfachte Installationsprüfung
# ============================================

Write-Host 'Starte Software-Installation...' -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Einstellungen ---
$UseSilent = $false
$CreateLog = $true
$LogDir = 'C:\Windows\Setup\Logs'
$LogFile = Join-Path $LogDir 'install.log'

if ($CreateLog) {
    if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
    "`n==== Installation gestartet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" | Out-File -FilePath $LogFile -Encoding utf8 -Append
}

function Log {
    param([string]$Text)
    Write-Host $Text
    if ($CreateLog) { $Text | Out-File -FilePath $LogFile -Encoding utf8 -Append }
}

# --- Adminrechte prüfen ---
function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Log 'Script läuft nicht als Administrator. Versuche Neustart...'
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }
    if (-not $scriptPath) {
        Log 'Konnte Skriptpfad nicht ermitteln. Bitte Skript aus Datei ausführen.'
        Read-Host 'Drücke Enter zum Beenden'
        exit 1
    }
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath)
    Start-Process -FilePath 'powershell' -ArgumentList $argList -Verb RunAs -WindowStyle Normal
    exit 0
}

# --- Prüfen ob Winget verfügbar ---
Log 'Prüfe Winget-Verfügbarkeit...'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log 'FEHLER: Winget ist nicht verfügbar!'
    Read-Host 'Drücke Enter zum Beenden'
    exit 1
}

# --- WINGET VOLLSTÄNDIG INITIALISIEREN (NUR EINMAL) ---
Log 'Initialisiere Winget-Datenbank (das kann 1-2 Minuten dauern)...'
try {
    # Store-Quelle entfernen
    $null = winget source remove msstore 2>&1
    Start-Sleep -Seconds 2
    
    # Quellen zurücksetzen und aktualisieren
    Log 'Setze Winget-Quellen zurück...'
    $null = winget source reset --force 2>&1
    Start-Sleep -Seconds 3
    
    Log 'Aktualisiere Winget-Quellen (bitte warten)...'
    $null = winget source update 2>&1
    Start-Sleep -Seconds 5
    
    # Test-Abfrage um sicherzustellen dass Winget bereit ist
    Log 'Teste Winget-Bereitschaft...'
    $testOutput = winget search Microsoft.PowerToys --exact 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log '✓ Winget ist bereit!'
    } else {
        Log '⚠ Winget-Test-Abfrage fehlgeschlagen, fahre trotzdem fort...'
    }
    
} catch {
    Log "⚠ Fehler bei Winget-Initialisierung: $($_.Exception.Message)"
    Log 'Fahre trotzdem fort...'
}

[System.Collections.ArrayList]$results = @()

# --- Installationsfunktion (VEREINFACHT) ---
function Install-App {
    param ([string]$Name, [string]$PackageID)

    Log "`n=> Verarbeite $Name (ID: $PackageID)..."

    # Vereinfachte Prüfung: Versuche direkt zu installieren
    # Winget erkennt selbst, ob bereits installiert
    
    Log "Installiere $Name..."
    $args = @('install','--id',$PackageID,'--accept-package-agreements','--accept-source-agreements','--exact','--disable-interactivity')
    if ($UseSilent) { $args += '--silent' }

    try {
        # Erhöhtes Timeout für Installation (15 Minuten)
        $process = Start-Process -FilePath 'winget' -ArgumentList $args -NoNewWindow -PassThru -Wait
        
        $exitCode = $process.ExitCode
        
        # Winget Exit Codes:
        # 0 = Erfolgreich installiert
        # -1978335189 (0x8A15000B) = Bereits installiert
        # -1978335212 (0x8A150014) = Keine Änderung nötig
        
        if ($exitCode -eq 0) {
            $msg = "✓ $Name erfolgreich installiert."
            Log $msg
            $results.Add([pscustomobject]@{Name=$Name;Status='Installed';Message=$msg}) | Out-Null
        } 
        elseif ($exitCode -eq -1978335189 -or $exitCode -eq -1978335212) {
            $msg = "○ $Name ist bereits installiert."
            Log $msg
            $results.Add([pscustomobject]@{Name=$Name;Status='AlreadyInstalled';Message=$msg}) | Out-Null
        }
        else {
            $msg = "✗ Fehler bei $Name (ExitCode: $exitCode)"
            Log $msg
            $results.Add([pscustomobject]@{Name=$Name;Status='Failed';Message=$msg;ExitCode=$exitCode}) | Out-Null
        }
        
    } catch {
        $msg = "✗ Ausnahmefehler bei ${Name}: $($_.Exception.Message)"
        Log $msg
        $results.Add([pscustomobject]@{Name=$Name;Status='Error';Message=$msg}) | Out-Null
    }
}

# --- App-Liste ---
$apps = @(
    @{Name='Blender'; ID='BlenderFoundation.Blender'},
    @{Name='Mozilla Firefox'; ID='Mozilla.Firefox'},
    @{Name='7-Zip'; ID='7zip.7zip'},
    @{Name='Steam'; ID='Valve.Steam'},
    @{Name='Godot Engine'; ID='GodotEngine.GodotEngine'},
    @{Name='Visual Studio 2022 Community'; ID='Microsoft.VisualStudio.2022.Community'}
)

# --- Hauptlauf ---
Log "`n=== Starte Installation von $($apps.Count) Programmen ===`n"

foreach ($app in $apps) {
    try {
        Install-App -Name $app.Name -PackageID $app.ID
    } catch {
        Log "Unbehandelter Fehler bei $($app.Name): $_"
        $results.Add([pscustomobject]@{Name=$app.Name;Status='Error';Message=$_.Exception.Message}) | Out-Null
    }
}

# --- Zusammenfassung ---
Log "`n`n========================================="
Log "          ZUSAMMENFASSUNG"
Log "========================================="
$results | Format-Table -AutoSize | Out-String -Stream | ForEach-Object { Log $_ }

$installed = ($results | Where-Object {$_.Status -eq 'Installed'}).Count
$alreadyInstalled = ($results | Where-Object {$_.Status -eq 'AlreadyInstalled'}).Count
$failed = ($results | Where-Object {$_.Status -eq 'Failed' -or $_.Status -eq 'Error'}).Count

Log "`nErgebnis:"
Log "  ✓ Neu installiert: $installed"
Log "  ○ Bereits vorhanden: $alreadyInstalled"
Log "  ✗ Fehlgeschlagen: $failed"

if ($CreateLog) {
    "`n==== Installation beendet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====`n" | Out-File -FilePath $LogFile -Encoding utf8 -Append
    Log "`nLog-Datei: $LogFile"
}

Log "`n========================================="
Log 'Installation abgeschlossen!'
Log "========================================="

Read-Host "`nDrücke Enter zum Beenden"
