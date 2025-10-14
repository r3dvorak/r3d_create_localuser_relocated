# === First Login Setup: Move user data folders to D:\<User> v 1.9 ===
Start-Sleep -Seconds 120  # give Windows time to finish profile init

$User     = $env:USERNAME
$BasePath = "D:\$User"
$logPath  = Join-Path $BasePath "FirstLoginSetup.log"

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Setup started for $User" | Out-File $logPath -Encoding UTF8

# --- Define folders to relocate ---
$folders = @{
    "Desktop"   = [Environment]::GetFolderPath("Desktop")
    "Documents" = [Environment]::GetFolderPath("MyDocuments")
    "Downloads" = (Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads")
    "Music"     = [Environment]::GetFolderPath("MyMusic")
    "Pictures"  = [Environment]::GetFolderPath("MyPictures")
    "Videos"    = [Environment]::GetFolderPath("MyVideos")
}

# --- Registry paths ---
$regUSF = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
$regSF  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"

if (-not (Test-Path $regUSF)) { New-Item -Path $regUSF -Force | Out-Null }
if (-not (Test-Path $regSF))  { New-Item -Path $regSF  -Force | Out-Null }

foreach ($pair in $folders.GetEnumerator()) {
    $name   = $pair.Key
    $source = $pair.Value
    $target = Join-Path $BasePath $name

    try {
        # Skip already relocated folders
        if ((Test-Path $target) -and ((Get-ChildItem $source -ErrorAction SilentlyContinue).Count -eq 0)) {
            Write-Host "Skipping file move for $name – already relocated, but registry will be checked." -ForegroundColor DarkYellow
            "[$(Get-Date -Format 'HH:mm:ss')] Checking registry for $name (even if empty)" | Out-File $logPath -Append
            # ← kein 'continue' mehr hier!
        }

        # Ensure target folder exists
        if (-not (Test-Path $target)) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Write-Host "Created target: $target" -ForegroundColor Cyan
        }

        Write-Host "Moving $name ..." -ForegroundColor Yellow
        "[$(Get-Date -Format 'HH:mm:ss')] Moving contents from $source to $target" | Out-File $logPath -Append -Encoding UTF8

        # Move only if files exist
        $items = Get-ChildItem -Path $source -Force -ErrorAction SilentlyContinue
        if ($items) {
            $items | Move-Item -Destination $target -Force -ErrorAction SilentlyContinue
            Write-Host "Moved $($items.Count) items from $name" -ForegroundColor Green
        }

        # --- Registry redirection (both hives) ---
        $map = @{
            "Desktop"   = "Desktop"
            "Documents" = "Personal"
            "Downloads" = "{374DE290-123F-4565-9164-39C4925E467B}"
            "Music"     = "My Music"
            "Videos"    = "My Video"
            "Pictures"  = "My Pictures"
        }
        $keyName = $map[$name]

        if ($keyName) {
            # Delete & recreate to enforce correct type (UserShell=REG_EXPAND_SZ, Shell=REG_SZ)
            Remove-ItemProperty -Path $regUSF -Name $keyName -ErrorAction SilentlyContinue
            New-ItemProperty -Path $regUSF -Name $keyName -PropertyType ExpandString -Value $target -Force | Out-Null

            Remove-ItemProperty -Path $regSF  -Name $keyName -ErrorAction SilentlyContinue
            New-ItemProperty -Path $regSF  -Name $keyName -PropertyType String -Value $target -Force | Out-Null

            "[$(Get-Date -Format 'HH:mm:ss')] Redirected registry for $name → $target" | Out-File $logPath -Append -Encoding UTF8
            Write-Host "Updated registry paths for $name" -ForegroundColor Green
        }

    } catch {
        $errorMsg = "Error processing " + $name + ": " + $_.Exception.Message
        $errorMsg | Out-File $logPath -Append -Encoding UTF8
        Write-Warning $errorMsg
    }
}

# --- Create desktop.ini for correct folder icons ---
Write-Host "`nRestoring desktop.ini for folder icons..." -ForegroundColor Cyan
"[$(Get-Date -Format 'HH:mm:ss')] Restoring desktop.ini icons" | Out-File $logPath -Append -Encoding UTF8

$templates = @{
    "Desktop"   = "[.ShellClassInfo]`nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21769"
    "Documents" = "[.ShellClassInfo]`nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21770"
    "Downloads" = "[.ShellClassInfo]`nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21798"
    "Music"     = "[.ShellClassInfo]`nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21790"
    "Pictures"  = "[.ShellClassInfo]`nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21779"
    "Videos"    = "[.ShellClassInfo]`nLocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21791"
}

foreach ($n in $templates.Keys) {
    $p = Join-Path $BasePath $n
    if (Test-Path $p) {
        $ini = Join-Path $p 'desktop.ini'
        try {
            attrib -r -s -h $ini 2>$null
            $templates[$n] | Out-File $ini -Encoding UTF8 -Force
            attrib +h +s $ini 2>$null
            attrib +r $p 2>$null
            "desktop.ini updated for $n" | Out-File $logPath -Append -Encoding UTF8
            Write-Host "✓ desktop.ini gesetzt für $n" -ForegroundColor Green
        } catch {
            $warn = "⚠ Zugriff verweigert für $n ($($_.Exception.Message))"
            $warn | Out-File $logPath -Append -Encoding UTF8
            Write-Warning $warn
        }
    }
}

# --- Sync verification log ---
"[$(Get-Date -Format 'HH:mm:ss')] Registry synchronization check:" | Out-File $logPath -Append -Encoding UTF8
"--- User Shell Folders ---" | Out-File $logPath -Append -Encoding UTF8
Get-ItemProperty $regUSF | Select Desktop,Personal,'My Music','My Pictures','My Video','{374DE290-123F-4565-9164-39C4925E467B}' |
    Out-String | Out-File $logPath -Append -Encoding UTF8
"--- Shell Folders ---" | Out-File $logPath -Append -Encoding UTF8
Get-ItemProperty $regSF | Select Desktop,Personal,'My Music','My Pictures','My Video','{374DE290-123F-4565-9164-39C4925E467B}' |
    Out-String | Out-File $logPath -Append -Encoding UTF8

# --- Remove scheduled task ---
try {
    $taskName = "FirstLoginSetup_$User"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Scheduled task removed." -ForegroundColor Green
} catch {
    Write-Warning "Could not remove scheduled task: $($_.Exception.Message)"
}

# --- Restart Explorer to apply changes ---
Stop-Process -Name explorer -Force
Start-Process explorer.exe

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Setup finished successfully" | Out-File $logPath -Append -Encoding UTF8
Write-Host "`nFolder relocation complete. Icons refreshed. Log written to $logPath." -ForegroundColor Green

# --- Open log file for user visibility ---
try {
    if (Test-Path $logPath) {
        Write-Host "`nOpening setup log for review..." -ForegroundColor Cyan
        Start-Process notepad.exe $logPath
    }
    else {
        Write-Warning "Log file not found: $logPath"
    }
} catch {
    Write-Warning "Could not open log automatically: $($_.Exception.Message)"
}
