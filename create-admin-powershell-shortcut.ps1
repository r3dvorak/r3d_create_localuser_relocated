<#
.SYNOPSIS
    Creates a Windows PowerShell (Admin) shortcut on the user's Desktop.

.DESCRIPTION
    The shortcut launches PowerShell with elevated privileges.
    Works on Windows 10 and 11. Detects relocated desktops automatically
    (e.g., D:\Offenbach\Desktop).

.VERSION
    1.2
#>

#Requires -Version 5.1

try {
    # --- Detect Desktop path dynamically ---
    $desktopPath = [Environment]::GetFolderPath('Desktop')

    if (-not (Test-Path $desktopPath)) {
        throw "Desktop path not found: $desktopPath"
    }

    # --- Shortcut configuration ---
    $targetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $arguments  = "-NoExit -Command `"Write-Host 'Running as Administrator...' -ForegroundColor Cyan; Get-Location`""
    $shortcutName = "PowerShell (Admin).lnk"
    $shortcutPath = Join-Path $desktopPath $shortcutName

    # --- Create shortcut ---
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.Arguments  = $arguments
    $shortcut.WorkingDirectory = $env:SystemRoot
    $shortcut.IconLocation = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe,0"
    $shortcut.Description  = "Open PowerShell with Administrator privileges"
    $shortcut.Hotkey       = "Ctrl+Shift+P"
    $shortcut.Save()

    # --- Attempt to set "Run as Administrator" flag ---
    try {
        $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
        # The flag at offset 0x15 controls "Run as Administrator"
        $bytes[0x15] = $bytes[0x15] -bor 0x20
        [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)
    }
    catch {
        Write-Warning "Could not set 'Run as Administrator' flag automatically."
        Write-Host "Please right-click the shortcut → Properties → Advanced → enable 'Run as administrator'." -ForegroundColor Yellow
    }

    # --- Verification ---
    if (Test-Path $shortcutPath) {
        Write-Host "✔ Shortcut created successfully:" -ForegroundColor Green
        Write-Host "  $shortcutPath" -ForegroundColor Cyan
        Write-Host "`nWhen launched, this PowerShell will request Administrator privileges."
    }
    else {
        throw "Shortcut file was not created."
    }
}
catch {
    Write-Error "Failed to create PowerShell (Admin) shortcut: $($_.Exception.Message)"
    exit 1
}
