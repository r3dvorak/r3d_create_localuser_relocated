<#
===============================================================================
 R3D Create Local User (Relocated)
-------------------------------------------------------------------------------
 Creates a new local Windows user with all personal folders relocated
 (e.g. D:\Username) and prepares automatic migration tasks to finalize
 the redirection at first login.

 This script generates:
   - Relocated folder structure (Documents, Desktop, etc.)
   - First login setup scripts (01start.bat, 01run.ps1, FirstLoginSetup.ps1)
   - Scheduled task for first login execution

-------------------------------------------------------------------------------
 @package   r3d_create_localuser_relocated
 @author    Richard Dvořák | R3D, info@r3d.de
 @email     info@r3d.de
 @version   1.8.10-stable
 @date      2025-10-07
 @license   MIT License
===============================================================================
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Username,
    [Parameter(Mandatory = $true)]
    [string]$BaseDrive
)

# --- Simple BaseDrive re-prompt & validation ---
while ($true) {
    # If it's empty (e.g., invoked via CLI without value), ask for it
    if (-not $BaseDrive) {
        $BaseDrive = Read-Host "BaseDrive (e.g. D:)"
    }

    $BaseDrive = $BaseDrive.Trim().ToUpper()
    # Fix common typos
    $BaseDrive = $BaseDrive -replace ';', ':'
    if ($BaseDrive -match '^[A-Z]$') { $BaseDrive = $BaseDrive + ':' }

    # Validate format and that the drive exists
    if ($BaseDrive -match '^[A-Z]:$' -and (Test-Path ($BaseDrive + "\"))) {
        break
    }

    Write-Host "[WARN] '$BaseDrive' is not a valid, existing drive (expect like D:). Please enter again." -ForegroundColor Yellow
    $BaseDrive = $null
}


# --- Interaktive Eingaben mit Defaultwerten ---
$FullName = Read-Host "Full name (Enter = $Username)"
if (-not $FullName) { $FullName = $Username }

$Admin = (Read-Host "Add to Administrators group? (Y/n)") -notmatch '^[Nn]'
$NoPassword = (Read-Host "Create without password? (Y/n)") -notmatch '^[Nn]'
$CreateSymlinks = (Read-Host "Create symbolic links after login? (Y/n)") -notmatch '^[Nn]'

Write-Host "`n------------------------"
Write-Host "User:          $Username"
Write-Host "Full name:     $FullName"
Write-Host "Base drive:    $BaseDrive"
Write-Host "Administrator: $Admin"
Write-Host "No password:   $NoPassword"
Write-Host "Symlinks:      $CreateSymlinks"
Write-Host "------------------------`n"

# --- Adminrechte pruefen ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Error "Dieses Skript muss als Administrator ausgefuehrt werden."
    exit 1
}

$ErrorActionPreference = "Stop"

# --- Benutzerordner erstellen ---
$userRoot = Join-Path $BaseDrive $Username
if (-not (Test-Path $userRoot)) {
    New-Item -ItemType Directory -Path $userRoot | Out-Null
    Write-Host "[OK] Created main folder: $userRoot"
}

$subfolders = @("Documents", "Pictures", "Music", "Downloads", "Desktop", "Contacts", "Favorites", "Videos")
foreach ($sf in $subfolders) {
    $path = Join-Path $userRoot $sf
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
        Write-Host "  + Created: $sf"
    }
}

# --- Benutzerkonto erstellen ---
$createParams = @{
    Name                = $Username
    Description         = "Relocated user account"
    FullName            = $FullName
    AccountNeverExpires = $true
}
if ($NoPassword) {
    $createParams["NoPassword"] = $true
}
else {
    $createParams["Password"] = (ConvertTo-SecureString "" -AsPlainText -Force)
}

try {
    New-LocalUser @createParams
    Write-Host "[OK] Local user '$Username' created."
}
catch {
    Write-Error "Failed to create user: $($_.Exception.Message)"
    exit 1
}

# --- Benutzer zu Admin-Gruppe hinzufuegen (Sprache beruecksichtigen) ---
if ($Admin) {
    try {
        $adminGroup = @("Administrators", "Administratoren") | Where-Object {
            Get-LocalGroup -Name $_ -ErrorAction SilentlyContinue
        } | Select-Object -First 1

        if ($adminGroup) {
            Add-LocalGroupMember -Group $adminGroup -Member $Username
            Write-Host "[OK] User added to '$adminGroup' group."
        }
        else {
            Write-Warning "Administrator group not found."
        }
    }
    catch {
        Write-Warning "Could not add to Administrators: $($_.Exception.Message)"
    }
}




# --- Dateien fuer Erststart erzeugen ---
$batPath = Join-Path $userRoot "01start.bat"
$ps1Path = Join-Path $userRoot "01run.ps1"

# === 01start.bat ===
$batContent = @'
@echo off
echo Starte Setup...
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp001run.ps1"
echo.
echo Setup abgeschlossen. Druecken Sie eine Taste zum Schliessen...
pause >nul
'@

$batContent | Out-File $batPath -Encoding ASCII -Force
Write-Host "Created 01start.bat in $userRoot" -ForegroundColor Green


# === 01run.ps1 ===
$ps1Content = @"
<#
.SYNOPSIS
    Starter-Skript für FirstLoginSetup.ps1
#>

# --- Define static script path from generator ---
`$ScriptPath = "$userRoot"
Set-Location `$ScriptPath


# --- Header ---
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   R3D PowerShell Setup Launcher   " -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# --- Adminrechte prüfen ---
`$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not `$principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Erneuter Start mit Administratorrechten..." -ForegroundColor Yellow

    # Determine actual script path safely (works even if `$PSCommandPath` is null)
    `$scriptSelf = `$MyInvocation.MyCommand.Path
    if (-not `$scriptSelf -or -not (Test-Path `$scriptSelf)) {
        `$scriptSelf = Join-Path (Get-Location) "01run.ps1"
    }

    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy","Bypass",
        "-File","``"`$scriptSelf``""
    )
    exit
}

# --- ExecutionPolicy nur für diesen Prozess ---
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
} catch {
    Write-Warning "ExecutionPolicy konnte nicht gesetzt werden: `$(`$_.Exception.Message)"
}

# --- Pfade ermitteln ---
if (-not `$ScriptPath) { `$ScriptPath = Split-Path -Parent `$MyInvocation.MyCommand.Path }
`$MainScript = Join-Path `$ScriptPath "FirstLoginSetup.ps1"
`$LogFile    = Join-Path `$ScriptPath "SetupHistory.log"


# --- Logging starten ---
try {
    "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Setup gestartet." | Out-File `$LogFile -Append -Encoding UTF8
} catch {
    Write-Warning "Konnte Log-Datei nicht schreiben: `$(`$_.Exception.Message)"
}

# --- Pruefen, ob Hauptskript existiert ---
if (-not (Test-Path `$MainScript)) {
    Write-Error "Hauptskript nicht gefunden: `$MainScript"
    pause
    exit 1
}

# --- Hauptskript ausfuehren ---
Write-Host "Starte Haupt-Setup Skript..." -ForegroundColor Green
try {
    & `$MainScript
    "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] FirstLoginSetup erfolgreich ausgefuehrt." | Out-File `$LogFile -Append -Encoding UTF8
    Write-Host "``n[OK] FirstLoginSetup.ps1 erfolgreich ausgefuehrt." -ForegroundColor Green
} catch {
    `$msg = "Fehler beim Ausfuehren von FirstLoginSetup.ps1: `$(`$_.Exception.Message)"
    Write-Error `$msg
    `$msg | Out-File `$LogFile -Append -Encoding UTF8
}

Write-Host "``nSetup abgeschlossen. Druecken Sie eine Taste zum Schliessen... Bitte den Benutzer neu anmelden." -ForegroundColor Cyan
pause
"@

$ps1Content | Out-File $ps1Path -Encoding UTF8 -Force
Write-Host "Created 01run.ps1 in $userRoot" -ForegroundColor Green






# --- FirstLoginSetup-Skript erstellen ---
$setupScriptPath = Join-Path $userRoot "FirstLoginSetup.ps1"

$setupScript = @"
# === First Login Setup: Move user data folders to `$Username ===
Start-Sleep -Seconds 10  # wait for profile init

# --- Static parameters injected by generator ---
`$Username  = "$Username"
`$BaseDrive = "$BaseDrive"
`$BasePath  = Join-Path `$BaseDrive `$Username
`$logPath   = Join-Path `$BasePath "FirstLoginSetup.log"

"[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Setup started for `$Username" | Out-File `$logPath -Encoding UTF8

# --- Define folders to relocate ---
`$folders = @{
    "Desktop"   = [Environment]::GetFolderPath("Desktop")
    "Documents" = [Environment]::GetFolderPath("MyDocuments")
    "Downloads" = (Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads")
    "Music"     = [Environment]::GetFolderPath("MyMusic")
    "Pictures"  = [Environment]::GetFolderPath("MyPictures")
    "Videos"    = [Environment]::GetFolderPath("MyVideos")
}

# --- Registry paths ---
`$regUSF = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
`$regSF  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"

if (-not (Test-Path `$regUSF)) { New-Item -Path `$regUSF -Force | Out-Null }
if (-not (Test-Path `$regSF))  { New-Item -Path `$regSF  -Force | Out-Null }

foreach (`$pair in `$folders.GetEnumerator()) {
    `$name   = `$pair.Key
    `$source = `$pair.Value
    `$target = Join-Path `$BasePath `$name

    try {
        # Skip already relocated folders
        if ((Test-Path `$target) -and ((Get-ChildItem `$source -ErrorAction SilentlyContinue).Count -eq 0)) {
            Write-Host "Skipping `$name already relocated, but registry will be checked." -ForegroundColor DarkYellow
            "[`$(Get-Date -Format 'HH:mm:ss')] Skipped `$name (already empty/relocated)" | Out-File `$logPath -Append -Encoding UTF8
        }

        # Ensure target folder exists
        if (-not (Test-Path `$target)) {
            New-Item -ItemType Directory -Path `$target -Force | Out-Null
            Write-Host "Created target: `$target" -ForegroundColor Cyan
        }

        Write-Host "Moving `$name ..." -ForegroundColor Yellow
        "[`$(Get-Date -Format 'HH:mm:ss')] Moving contents from `$source to `$target" | Out-File `$logPath -Append -Encoding UTF8

        # Move only if files exist
        `$items = Get-ChildItem -Path `$source -Force -ErrorAction SilentlyContinue
        if (`$items) {
            `$items | Move-Item -Destination `$target -Force -ErrorAction SilentlyContinue
            Write-Host "Moved `$(`$items.Count) items from `$name" -ForegroundColor Green
        }

        # --- Registry redirection (both hives) ---
        `$map = @{
            "Desktop"   = "Desktop"
            "Documents" = "Personal"
            "Downloads" = "{374DE290-123F-4565-9164-39C4925E467B}"
            "Music"     = "My Music"
            "Videos"    = "My Video"
            "Pictures"  = "My Pictures"
        }
        `$keyName = `$map[`$name]

        if (`$keyName) {
            Remove-ItemProperty -Path `$regUSF -Name `$keyName -ErrorAction SilentlyContinue
            New-ItemProperty -Path `$regUSF -Name `$keyName -PropertyType ExpandString -Value `$target -Force | Out-Null
            Remove-ItemProperty -Path `$regSF -Name `$keyName -ErrorAction SilentlyContinue
            New-ItemProperty -Path `$regSF -Name `$keyName -PropertyType String -Value `$target -Force | Out-Null

            "[`$(Get-Date -Format 'HH:mm:ss')] Redirected registry for `$name -> `$target" | Out-File `$logPath -Append -Encoding UTF8
            Write-Host "Updated registry paths for `$name" -ForegroundColor Green
        }
    }
    catch {
        `$errorMsg = "Error processing " + $name + ": " + `$_.Exception.Message
        `$errorMsg | Out-File `$logPath -Append -Encoding UTF8
        Write-Warning `$errorMsg
    }
}

# --- Create desktop.ini for correct folder icons ---
Write-Host "``nRestoring desktop.ini for folder icons..." -ForegroundColor Cyan
"[`$(Get-Date -Format 'HH:mm:ss')] Restoring desktop.ini icons" | Out-File `$logPath -Append -Encoding UTF8

`$templates = @{
    "Desktop"   = "[.ShellClassInfo]``nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21769"
    "Documents" = "[.ShellClassInfo]``nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21770"
    "Downloads" = "[.ShellClassInfo]``nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21798"
    "Music"     = "[.ShellClassInfo]``nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21790"
    "Pictures"  = "[.ShellClassInfo]``nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21779"
    "Videos"    = "[.ShellClassInfo]``nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21791"
}

foreach (`$n in `$templates.Keys) {
    `$p = Join-Path `$BasePath `$n
    if (Test-Path `$p) {
        `$ini = Join-Path `$p 'desktop.ini'
        try {
            attrib -r -s -h `$ini 2>`$null
            `$templates[`$n] | Out-File `$ini -Encoding UTF8 -Force
            attrib +h +s `$ini 2>`$null
            attrib +r `$p 2>`$null
            "desktop.ini updated for `$n" | Out-File `$logPath -Append -Encoding UTF8
            Write-Host "OK desktop.ini gesetzt fuer `$n" -ForegroundColor Green
        } catch {
            `$warn = "Zugriff verweigert fuer `$n (`$(`$_.Exception.Message))"
            `$warn | Out-File `$logPath -Append -Encoding UTF8
            Write-Warning `$warn
        }
    }
}

"[`$(Get-Date -Format 'HH:mm:ss')] Registry synchronization check:" | Out-File `$logPath -Append -Encoding UTF8
"--- User Shell Folders ---" | Out-File `$logPath -Append -Encoding UTF8
Get-ItemProperty `$regUSF | Select Desktop,Personal,'My Music','My Pictures','My Video','{374DE290-123F-4565-9164-39C4925E467B}' |
    Out-String | Out-File `$logPath -Append -Encoding UTF8
"--- Shell Folders ---" | Out-File `$logPath -Append -Encoding UTF8
Get-ItemProperty `$regSF | Select Desktop,Personal,'My Music','My Pictures','My Video','{374DE290-123F-4565-9164-39C4925E467B}' |
    Out-String | Out-File `$logPath -Append -Encoding UTF8

try {
    `$taskName = "FirstLoginSetup_`$User"
    Unregister-ScheduledTask -TaskName `$taskName -Confirm:`$false -ErrorAction SilentlyContinue
    Write-Host "Scheduled task removed." -ForegroundColor Green
} catch {
    Write-Warning "Could not remove scheduled task: `$(`$_.Exception.Message)"
}

Stop-Process -Name explorer -Force
Start-Process explorer.exe

"[`$(Get-Date -Format 'HH:mm:ss')]  Setup finished successfully" | Out-File `$logPath -Append -Encoding UTF8
Write-Host "``nFolder relocation complete. Icons refreshed. Log written to `$logPath." -ForegroundColor Green
"@

$setupScript | Out-File $setupScriptPath -Encoding UTF8 -Force
Write-Host "[OK] Created FirstLoginSetup.ps1 at: $setupScriptPath" -ForegroundColor Green





# --- Task fuer ersten Login (Start 1 Minute nach Logon) ---
$taskName = "FirstLoginSetup_$Username"
$batFile = Join-Path $userRoot "01start.bat"

$action = New-ScheduledTaskAction -Execute $batFile
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $Username
$trigger.Delay = "PT90S"   

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $Username -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Run 01start.bat (delayed 1 minute after first login)" -Force | Out-Null
Write-Host "[OK] Scheduled task created (delayed 90 seconds after first login)."
Write-Host "`nSetup complete. Please log in as '$Username' to finalize the user folder relocation." -ForegroundColor Green