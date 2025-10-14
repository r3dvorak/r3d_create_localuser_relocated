# R3D Create Local User (Relocated)
Practical automation for clean multi-drive Windows setups.
**Version:** 1.8.10 · Stable  
**Author:** Richard Dvořák · © R3D, info@r3d.de

## Overview
This PowerShell utility automates the creation of local Windows user accounts whose personal folders (Documents, Desktop, etc.) are relocated to another drive — typically **D:\<User>**.  
It also prepares scheduled tasks and setup scripts (`01start.bat`, `01run.ps1`, `FirstLoginSetup.ps1`) that finalize the redirection on first login.

---

## Features
- Creates local users with or without password
- Optional administrator privileges
- Automatically generates relocated folder structure
- Safe re-launch with elevated rights
- Auto-executes setup after first login (via scheduled task)
- Clean logs and UTF-8 encoding throughout
- Fully update-safe: no system files modified

---

## ⚙️ Prerequisites

Before using `create-localuser-relocated.ps1`, ensure that the following requirements are met:

- **Operating System:** Windows 10 or Windows 11 (x64)
- **PowerShell:** Version **5.1** or later (PowerShell 7.x supported)
- **Privileges:** Script must be run **as Administrator**
- **Execution Policy:** Allow local scripts (temporary bypass is automatically applied)
- **Drives:** Secondary data drive (e.g., `D:`) must be writable  
  *(if missing, the script will re-prompt for a valid drive letter)*
- **Windows Task Scheduler:** Active service required for delayed first-login setup task
- **User Account Control (UAC):** Enabled — admin elevation is handled automatically

Optional but recommended:
- Run inside a clean system session (no open Explorer windows for the new user)
- Ensure no third-party antivirus interferes with PowerShell or scheduled tasks

---

## Usage

### 1. Run the Script as Administrator
```powershell
PS C:\> .\create-localuser-relocated.ps1
```

### 2. Follow the Prompts

You’ll be asked for:
 - Username (works with spaces and special characters)
 - Base drive (e.g. D: — validated for correctness)
 - Full name (optional)
 - Administrator rights (Y/n, without it won't do much)
 - No password (Y/n, you will be prompt to create one at first login)
 - Create symbolic links (Y/n, Compatibility with software that expects paths like C:\Users\<User>\Documents)

### 3. Login as the New User

After the first login, the generated task runs automatically (90 seconds after first login) and moves folders + updates registry entries.
A log file is written to:
```powershell
D:\<User>\FirstLoginSetup.log
```
## Folder Structure
/r3d_create_localuser_relocated
│
├─ create-localuser-relocated.ps1
├─ LICENSE
└─ README.md

## Notes
Tested on Windows 10 / 11 (PowerShell 5.1 and 7+)
Requires Administrator rights
No Group Policy or registry hacks outside the user context
Update-safe and reversible via normal folder moves


R3D Create Local User (Relocated) — MIT License
