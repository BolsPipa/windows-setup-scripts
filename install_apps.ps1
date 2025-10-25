# install_apps.ps1 – Programme automatisch installieren
Write-Host "Starte Software-Installation..." -ForegroundColor Cyan

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "Winget ist nicht verfügbar. Stelle sicher, dass App Installer installiert ist."
    exit 1
}

function Install-App {
    param ([string]$Name, [string]$PackageID)
    Write-Host "Installiere $Name..." -ForegroundColor Yellow
    try {
        Start-Process winget -ArgumentList @("install","--id",$PackageID,"--accept-package-agreements","--accept-source-agreements","-h","-e") -Wait -NoNewWindow
        Write-Host "$Name erfolgreich installiert.`n" -ForegroundColor Green
    } catch {
        Write-Warning "Fehler bei $Name: $_"
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

foreach ($app in $apps) { Install-App -Name $app.Name -PackageID $app.ID }

Write-Host "Alle Programme wurden Installiert." -ForegroundColor Cyan
Start-Sleep -Seconds 3
