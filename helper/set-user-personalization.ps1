<#
===============================================================================
 R3D User Personalization Setup
-------------------------------------------------------------------------------
 Applies Windows personalization and usability defaults for newly created
 local users after folder relocation.

 This script configures:
   - Taskbar layout and pinned icons
   - Background, color theme, and accent behavior
   - Lock screen and power timeout policies
   - Desktop icons (without "User Files")
   - Desktop shortcuts for user folders (no "– Verknüpfung")
   - Removes Outlook and Microsoft Store from taskbar
   - Restarts Explorer for immediate effect

-------------------------------------------------------------------------------
 @package   r3d_create_localuser_relocated
 @author    Richard Dvořák | R3D Internet Dienstleistungen
 @email     info@r3d.de
 @version   1.0.0
 @date      2025-10-16
 @license   MIT License
===============================================================================
#>


param(
    [ValidateSet('Blue', 'Mint', 'Camouflage', 'Black')]
    [string]$Theme = 'Blue'
)

$ErrorActionPreference = 'SilentlyContinue'

# --- kleines Logging
$Log = "$env:USERPROFILE\set-user-personalization.log"
function Log($m) { "[{0}] {1}" -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $m | Out-File $Log -Append -Encoding UTF8; Write-Host $m }

# --- Farbpaletten (RGB)
$bgMap = @{
    Blue       = '32 109 184'      # Blau
    Mint       = '0 102 102'       # dunkles Mint
    Camouflage = '80 120 90'
    Black      = '0 0 0'
}
$accentBgrHex = @{
    Blue       = 0x00D77800        # ca. Windows Blau (BGR DWORD)
    Mint       = 0x00666600
    Camouflage = 0x005A7850
    Black      = 0x00000000
}

# --- TASKLEISTE
Log "Taskleisten-Einstellungen anwenden"
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Type DWord -Value 1   # 0=Aus, 1=Symbol, 2=Box

New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Type DWord -Value 0   # Widgets AUS
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Type DWord -Value 0   # links

# --- FARBEN / DESIGN
Log "Farben/Design setzen"
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Force | Out-Null
# Benutzerdefiniert: Windows dunkel, Apps hell
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Type DWord -Value 0
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme'   -Type DWord -Value 1
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency'  -Type DWord -Value 1
# Akzentfarbe auf Taskleiste & Titelleisten
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'ColorPrevalence'     -Type DWord -Value 1
# Akzentfarbe setzen (DWM)
New-Item 'HKCU:\Software\Microsoft\Windows\DWM' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'ColorizationColor'        -Type DWord -Value $accentBgrHex[$Theme]
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'AccentColor'              -Type DWord -Value $accentBgrHex[$Theme]
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'ColorizationColorBalance' -Type DWord -Value 59

# --- HINTERGRUND = Volltonfarbe
Log "Hintergrund (Volltonfarbe) setzen: $Theme"
New-Item 'HKCU:\Control Panel\Colors' -Force | Out-Null
Set-ItemProperty 'HKCU:\Control Panel\Colors' -Name 'Background' -Value $bgMap[$Theme]
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -Name 'BackgroundType' -Type DWord -Value 1
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name 'Wallpaper' -Value ''
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name 'WallpaperStyle' -Value '0'

# --- SPERRBILDSCHIRM: Bild-Modus + Tipps AUS
Log "Sperrbildschirm konfigurieren"
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenEnabled'   -Type DWord -Value 0
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenOverlayEnabled' -Type DWord -Value 0
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338387Enabled' -Type DWord -Value 0  # Tipps/Tricks AUS

# --- ENERGIE
Log "Energie-Timeouts setzen"
# 0 = Nie (AC/DC Sleep)
powercfg /change monitor-timeout-ac 180 | Out-Null   # 3h
powercfg /change monitor-timeout-dc 15  | Out-Null   # 15min
powercfg /change standby-timeout-ac 0   | Out-Null   # Nie
powercfg /change standby-timeout-dc 0   | Out-Null   # Nie

# --- DESKTOP-SYMBOLE: Alle außer 'Benutzerdateien'
Log "Desktop-Symbole aktivieren (ohne 'Benutzerdateien')"
$clsid = @{
    ThisPC       = '{20D04FE0-3AEA-1069-A2D8-08002B30309D}'
    UserFiles    = '{59031a47-3f72-44a7-89c5-5595fe6b30ee}'
    Network      = '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}'
    RecycleBin   = '{645FF040-5081-101B-9F08-00AA002F954E}'
    ControlPanel = '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}'
}
$hidePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
New-Item $hidePath -Force | Out-Null
# 0 = anzeigen, 1 = verstecken
@(
    @{id = $clsid.ThisPC; val = 0 }
    @{id = $clsid.Network; val = 0 }
    @{id = $clsid.ControlPanel; val = 0 }
    @{id = $clsid.RecycleBin; val = 0 }
    @{id = $clsid.UserFiles; val = 1 }
) | ForEach-Object { Set-ItemProperty $hidePath -Name $_.id -Type DWord -Value $_.val }

# --- DESKTOP-VERKNÜPFUNGEN (ohne „– Verknüpfung“)
Log "Desktop-Verknüpfungen erstellen (Dokumente/Bilder/Musik/Videos/Downloads)"
$user = $env:USERNAME
$base = Join-Path 'D:' $user  # wenn deine Ordner auf D:\<User> liegen
$targets = @{
    'Dokumente' = Join-Path $base 'Documents'
    'Bilder'    = Join-Path $base 'Pictures'
    'Musik'     = Join-Path $base 'Music'
    'Videos'    = Join-Path $base 'Videos'
    'Downloads' = Join-Path $base 'Downloads'
}
$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
foreach ($n in $targets.Keys) {
    $lnk = Join-Path $desktop "$n.lnk"
    if (Test-Path $lnk) { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }
    $s = $wsh.CreateShortcut($lnk)
    $s.TargetPath = $targets[$n]
    $s.WorkingDirectory = $targets[$n]
    $s.IconLocation = "$env:SystemRoot\System32\imageres.dll,3"  # generisches Ordnersymbol
    $s.Save()
}

# --- TASKLEISTE: Outlook & Store entfernen (gezielt)
function Unpin-AppxFromTaskbar {
    param([Parameter(Mandatory)][string]$AUMID, [Parameter(Mandatory)][string]$TempName)
    try {
        $desk = [Environment]::GetFolderPath('Desktop')
        $lnk = Join-Path $desk ($TempName + '.lnk')
        if (Test-Path $lnk) { Remove-Item $lnk -Force }
        # App-Shortcut auf Desktop erzeugen
        $WScriptShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WScriptShell.CreateShortcut($lnk)
        $Shortcut.TargetPath = "shell:AppsFolder\$AUMID"
        $Shortcut.Save()
        Start-Sleep -Milliseconds 300
        # Unpin-Verb ausführen (de/en)
        $shell = New-Object -ComObject Shell.Application
        $item = $shell.Namespace($desk).ParseName((Split-Path $lnk -Leaf))
        $verb = $item.Verbs() | Where-Object { $_.Name -match 'Von Taskleiste lösen|Unpin from taskbar' }
        if ($verb) { $verb.DoIt() }
        Remove-Item $lnk -Force -ErrorAction SilentlyContinue
    }
    catch {}
}

Log "Outlook & Microsoft Store von Taskleiste entfernen (falls vorhanden)"
# Neue Outlook-App (AUMID kann je nach Build variieren – diese sind die häufigsten)
$possibleOutlook = @(
    'microsoft.windowscommunicationsapps_8wekyb3d8bbwe!Microsoft.WindowsLive.Mail',
    'Microsoft.OutlookForWindows_8wekyb3d8bbwe!OutlookForWindows'
)
foreach ($id in $possibleOutlook) { Unpin-AppxFromTaskbar -AUMID $id -TempName 'tmpOutlook' }

# Microsoft Store
Unpin-AppxFromTaskbar -AUMID 'Microsoft.WindowsStore_8wekyb3d8bbwe!App' -TempName 'tmpStore'

# --- Explorer neu starten, damit alles sichtbar wird
Log "Explorer neu starten"
Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
Log "Fertig."
Write-Host "`n[OK] Personalisierung angewendet. Details: $Log" -ForegroundColor Green
