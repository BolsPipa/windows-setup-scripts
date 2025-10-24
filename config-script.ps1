# Windows 11 Konfigurations-Script
# Läuft automatisch direkt nach der Installation (KEIN Internet nötig)

# Protokoll-Datei
$logFile = "C:\Windows\Temp\config-script.log"
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
    Write-Host $Message
}

Write-Log "=== Windows Konfiguration gestartet ==="

# ===== WINDOWS EINSTELLUNGEN =====

# Dark Mode aktivieren
Write-Log "Aktiviere Dark Mode..."
try {
    New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -PropertyType DWORD -Force | Out-Null
    Write-Log "✓ Dark Mode aktiviert"
} catch {
    Write-Log "✗ Fehler beim Aktivieren des Dark Mode"
}

# Dateierweiterungen anzeigen
Write-Log "Zeige Dateierweiterungen..."
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Write-Log "✓ Dateierweiterungen werden angezeigt"
} catch {
    Write-Log "✗ Fehler beim Ändern der Dateierweiterungen"
}

# Versteckte Dateien anzeigen
Write-Log "Zeige versteckte Dateien..."
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Write-Log "✓ Versteckte Dateien werden angezeigt"
} catch {
    Write-Log "✗ Fehler beim Ändern der versteckten Dateien"
}

# Taskleiste: Suchfeld ausblenden
Write-Log "Konfiguriere Taskleiste..."
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
    Write-Log "✓ Taskleiste konfiguriert"
} catch {
    Write-Log "✗ Fehler bei Taskleisten-Konfiguration"
}

# Windows Update auf "Benachrichtigen vor Download" setzen
Write-Log "Konfiguriere Windows Update..."
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 2 -Force -ErrorAction SilentlyContinue
    Write-Log "✓ Windows Update konfiguriert"
} catch {
    Write-Log "⚠ Windows Update-Einstellung übersprungen (erfordert Admin-Rechte)"
}

# ===== WINDOWS FEATURES =====

# Hyper-V deaktivieren (falls nicht benötigt)
# Write-Log "Deaktiviere Hyper-V..."
# Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart

# WSL2 aktivieren (falls benötigt)
# Write-Log "Aktiviere WSL2..."
# dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
# dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# ===== EXPLORER NEUSTARTEN =====
Write-Log "Starte Explorer neu..."
try {
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 2
    Write-Log "✓ Explorer neugestartet"
} catch {
    Write-Log "⚠ Explorer-Neustart übersprungen"
}

# ===== ZUSÄTZLICHE KONFIGURATIONEN =====

# Desktop-Icons erstellen (Beispiel: Dieser PC, Papierkorb)
# Write-Log "Erstelle Desktop-Icons..."
# $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
# Set-ItemProperty -Path $path -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0  # Dieser PC
# Set-ItemProperty -Path $path -Name "{645FF040-5081-101B-9F08-00AA002F954E}" -Value 0  # Papierkorb

# Performance-Einstellungen
Write-Log "Optimiere Performance-Einstellungen..."
try {
    # Visuelle Effekte auf Performance optimieren
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2
    Write-Log "✓ Performance optimiert"
} catch {
    Write-Log "⚠ Performance-Optimierung übersprungen"
}

Write-Log "=== Windows Konfiguration abgeschlossen ==="
Write-Log "Log-Datei: $logFile"

# Script löscht sich selbst
Start-Sleep -Seconds 2
Remove-Item $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
