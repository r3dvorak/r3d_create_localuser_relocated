<#
.SYNOPSIS
  Remove a local Windows user and all related folders.

.DESCRIPTION
  Deletes:
   • Local user account
   • C:\Users\<Username>
   • D:\<Username>
   • ProfileList registry key
#>

param(
    [Parameter(Mandatory = $true)][string]$Username,
    [string]$BaseDrive = "D:",
    [switch]$Force
)

# --- Require admin ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Error "Run this script as Administrator."
    exit 1
}

$ErrorActionPreference = "Stop"
$profilePath = "C:\Users\$Username"
$dPath = Join-Path $BaseDrive $Username

Write-Host "Removing user '$Username' ..." -ForegroundColor Cyan

# --- Confirm ---
if (-not $Force) {
    $ans = Read-Host "Delete user '$Username' and all data? (Y/N)"
    if ($ans -notmatch '^[Yy]$') { Write-Host "Cancelled."; exit }
}

# --- 1: Delete local account ---
try {
    $u = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if ($u) {
        Remove-LocalUser -Name $Username
        Write-Host "Removed account."
    }
    else {
        Write-Host "No such user (skipped)."
    }
}
catch { Write-Warning ("Account remove failed: {0}" -f $_.Exception.Message) }

# --- 2: Remove registry profile entry ---
try {
    $keys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    foreach ($k in $keys) {
        $p = (Get-ItemProperty $k.PSPath).ProfileImagePath
        if ($p -like "*\$Username") {
            Remove-Item $k.PSPath -Recurse -Force
            Write-Host "Removed registry profile key."
        }
    }
}
catch { Write-Warning ("Registry cleanup failed: {0}" -f $_.Exception.Message) }

# --- 3: Delete C:\Users\<Username> ---
try {
    if (Test-Path $profilePath) {
        takeown /F $profilePath /R /D Y | Out-Null
        icacls $profilePath /grant Administrators:F /T | Out-Null
        Remove-Item $profilePath -Recurse -Force
        Write-Host "Deleted $profilePath."
    }
    else {
        Write-Host "No folder at $profilePath."
    }
}
catch { Write-Warning "Delete failed on ${profilePath}: $($_.Exception.Message)" }

# --- 4: Delete D:\<Username> ---
try {
    if (Test-Path $dPath) {
        takeown /F $dPath /R /D Y | Out-Null
        icacls $dPath /grant Administrators:F /T | Out-Null
        Remove-Item $dPath -Recurse -Force
        Write-Host "Deleted $dPath."
    }
    else {
        Write-Host "No folder at $dPath."
    }
}
catch { Write-Warning "Delete failed on ${dPath}: $($_.Exception.Message)" }

# --- Done ---
Write-Host "User '$Username' and data removed." -ForegroundColor Green
Write-Host "Restart Windows to clear profile cache."
