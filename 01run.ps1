<#
.SYNOPSIS
    Starter-Skript für FirstLoginSetup.ps1
    - prüft Adminrechte
    - setzt ExecutionPolicy (Scope: Process)
    - startet das Hauptskript im selben Ordner
    - loggt Ablauf in SetupHistory.log
#>

# --- Header ---
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   R3D PowerShell Setup Launcher   " -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# --- Adminrechte prüfen ---
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Erneuter Start mit Administratorrechten..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`""
    exit
}

# --- ExecutionPolicy nur für diesen Prozess ---
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
} catch {
    Write-Warning "ExecutionPolicy konnte nicht gesetzt werden: $($_.Exception.Message)"
}

# --- Pfade ermitteln ---
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$MainScript = Join-Path $ScriptPath "FirstLoginSetup.ps1"

# --- Logging starten ---
try {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Setup gestartet." | Out-File $LogFile -Append -Encoding UTF8
} catch {
    Write-Warning "Konnte Log-Datei nicht schreiben: $($_.Exception.Message)"
}

# --- Prüfen, ob Hauptskript existiert ---
if (-not (Test-Path $MainScript)) {
    Write-Error "Hauptskript nicht gefunden: $MainScript"
    pause
    exit 1
}

# --- Hauptskript ausführen ---
Write-Host "Starte Haupt-Setup Skript..." -ForegroundColor Green
try {
    & $MainScript
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] FirstLoginSetup erfolgreich ausgefuehrt." | Out-File $LogFile -Append -Encoding UTF8
    Write-Host "`n[OK] FirstLoginSetup.ps1 erfolgreich ausgefuehrt." -ForegroundColor Green
} catch {
    $msg = "Fehler beim Ausfuehren von FirstLoginSetup.ps1: $($_.Exception.Message)"
    Write-Error $msg
    $msg | Out-File $LogFile -Append -Encoding UTF8
}

Write-Host "`nSetup abgeschlossen. Druecken Sie eine Taste zum Schliessen... Biite den Benutzer neu anmleden."
pause
