# install_apps.ps1 – Programme automatisch installieren (Setup-kompatibel)
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

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log "Winget ist nicht verfügbar. Stelle sicher, dass 'App Installer' installiert ist."
    exit 1
}

# Admin-Check (optional – in FirstLogonCommands meist schon Admin)
function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-IsAdministrator)) {
    Log "Script läuft nicht als Administrator. Versuche Neustart..."
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell" -ArgumentList $arg -Verb RunAs -WindowStyle Normal
    exit 0
}

$results = @()

function Install-App {
    param ([string]$Name, [string]$PackageID)
    Log "=> Prüfe $Name (ID: $PackageID)..."
    & winget show --id $PackageID --exact *> $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        $msg = "Paket $PackageID wurde in winget nicht gefunden."
        Log $msg
        $results += [pscustomobject]@{Name=$Name;Status="NotFound";Message=$msg}
        return
    }
    $list = & winget list --id $PackageID --exact 2>$null
    if ($list -and ($list -notmatch "No installed package found")) {
        $msg = "$Name ist bereits installiert."
        Log $msg
        $results += [pscustomobject]@{Name=$Name;Status="AlreadyInstalled";Message=$msg}
        return
    }
    Log "Installiere $Name..."
    $args = @("install","--id",$PackageID,"--accept-package-agreements","--accept-source-agreements","--exact")
    if ($UseSilent) { $args += "--silent" }
    & winget @args
    if ($LASTEXITCODE -eq 0) {
        Log "$Name erfolgreich installiert."
    } else {
        Log "Fehler bei $Name (ExitCode=$LASTEXITCODE)."
    }
}

$apps = @(
    @{Name="Blender"; ID="BlenderFoundation.Blender"},
    @{Name="Mozilla Firefox"; ID="Mozilla.Firefox"},
    @{Name="7-Zip"; ID="7zip.7zip"},
    @{Name="Steam"; ID="Valve.Steam"},
    @{Name="Godot Engine"; ID="GodotEngine.GodotEngine"},
    @{Name="Visual Studio 2022 Community"; ID="Microsoft.VisualStudio.2022.Community"}
)

foreach ($app in $apps) { try { Install-App @app } catch { Log "Fehler bei $($app.Name): $_" } }

Log "`n==== Installation beendet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===="
Log "Log-Datei: $LogFile"
Start-Sleep -Seconds 2
