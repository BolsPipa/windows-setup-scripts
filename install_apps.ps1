# ============================================
# install_apps.ps1 – Programme automatisch installieren (Setup-kompatibel)
# ============================================

Write-Host "Starte Software-Installation..." -ForegroundColor Cyan

# Sicherheitsprotokoll für GitHub/HTTPS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Deaktiviert Microsoft Store als Quelle (verhindert Interaktivität)
try {
    winget source remove msstore -y *> $null 2>&1
} catch {}

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

# Pruefen ob Winget verfügbar ist
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log "Winget ist nicht verfuegbar. Stelle sicher, dass 'App Installer' installiert ist."
    exit 1
}

# Admin-Check (optional – im Setup meist schon Admin)
function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Log "Script lauft nicht als Administrator. Versuche Neustart..."
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell" -ArgumentList $arg -Verb RunAs -WindowStyle Normal
    exit 0
}

$results = @()

# --- Hauptfunktion: App installieren ---
function Install-App {
    param ([string]$Name, [string]$PackageID)

    Log "=> Pruefe $Name (ID: $PackageID)..."

    # Paket in Winget suchen
    & winget show --id $PackageID --exact *> $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        $msg = "❌ Paket $PackageID wurde in Winget nicht gefunden."
        Log $msg
        $results += [pscustomobject]@{Name=$Name;Status="NotFound";Message=$msg}
        return
    }

    # Prüfen, ob bereits installiert
    $list = & winget list --id $PackageID --exact 2>$null
    if ($list -and ($list -notmatch "No installed package found")) {
        $msg = "⚙️  $Name ist bereits installiert. Ueberspringe..."
        Log $msg
        $results += [pscustomobject]@{Name=$Name;Status="AlreadyInstalled";Message=$msg}
        return
    }

    Log "⬇️  Installiere $Name..."
    $args = @("install","--id",$PackageID,"--accept-package-agreements","--accept-source-agreements","--exact")
    if ($UseSilent) { $args += "--silent" }

    & winget @args
    if ($LASTEXITCODE -eq 0) {
        $msg = "✅ $Name erfolgreich installiert."
        Log $msg
        $results += [pscustomobject]@{Name=$Name;Status="Installed";Message=$msg}
    } else {
        $msg = "❗ Fehler bei $Name (ExitCode=$LASTEXITCODE)."
        Log $msg
        $results += [pscustomobject]@{Name=$Name;Status="Failed";Message=$msg;ExitCode=$LASTEXITCODE}
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

# --- Installation starten ---
foreach ($app in $apps) {
    try {
        Install-App -Name $app.Name -PackageID $app.ID
    } catch {
        Log "❗ Unbehandelter Fehler bei $($app.Name): $_"
        $results += [pscustomobject]@{Name=$app.Name;Status="Error";Message=$_.Exception.Message}
    }
}

# --- Zusammenfassung ---
Log "`n=== Zusammenfassung ==="
$results | Format-Table -AutoSize | Out-String | ForEach-Object { Log $_ }

if ($CreateLog) {
    "`n==== Installation beendet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====`n" | Out-File -FilePath $LogFile -Encoding utf8 -Append
    Log "📄 Log-Datei gespeichert unter: $LogFile"
}

Log "✅ Fertig. Bitte Ausgabe oder Log pruefen."
Start-Sleep -Seconds 2
