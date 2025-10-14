# 🧾 R3D Create Local User (Relocated) — Changelog

All notable changes to this project will be documented in this file.  
This project adheres to [Semantic Versioning](https://semver.org/) and is licensed under the **MIT License**.

---

## [1.8.10] – 2025-10-14
### 🟢 Stable Release
**Finalized build with fully self-contained folder relocation setup.**

- Added **self-contained script generation**:
  - Automatically creates `01start.bat`, `01run.ps1`, and `FirstLoginSetup.ps1` inside the new user directory.
  - Scripts are fully encoded in UTF-8 and ready for standalone execution.
- Implemented **path inheritance** between scripts:
  - `$userRoot`, `$Username`, and `$BaseDrive` are passed directly from the generator.
  - Each sub-script resolves its path automatically, independent of the working directory.
- Fixed **admin elevation logic**:
  - `01run.ps1` now reliably re-launches itself with `RunAs` if not elevated.
  - Handles PowerShell argument quoting correctly.
- Added **BaseDrive input validation**:
  - Prevents invalid input such as `D;` or missing colon.
  - Re-prompts user for valid drive letter instead of silently defaulting.
- Improved **encoding and log file handling**:
  - All logs (`SetupHistory.log`, `FirstLoginSetup.log`) are written in UTF-8.
  - Time-stamped entries with consistent `yyyy-MM-dd HH:mm:ss` format.
- Refined **desktop.ini recreation**:
  - Each relocated folder (Desktop, Documents, etc.) now gets proper localized icons and titles.
- Adjusted **scheduled task creation**:
  - Task runs `01start.bat` **90 seconds after first login** to allow Windows initialization.
  - Task is automatically removed after first successful run.
- Improved **robustness**:
  - Works even if Explorer or profile initialization are still ongoing.
  - Handles re-runs gracefully — detects already relocated folders and skips safely.

---

## [1.8.9] – 2025-10-13
### 🔧 Feature Integration
- Integrated automatic delayed scheduled task for `FirstLoginSetup.ps1`.
- Added admin auto-elevation for 01run.ps1 (RunAs logic).
- Introduced full UTF-8 output for all generated scripts.
- Enhanced console color coding for readability (`Green`, `Yellow`, `Cyan`, `DarkYellow`).
- Added automatic folder existence checks before registry rewrite.
- Implemented early log initialization and per-step timestamps.
- Added support for re-running setup on existing accounts.

---

## [1.8.8] – 2025-10-12
### 🧩 Functional Expansion
- Added generator logic for all user-level setup scripts.
- Implemented consistent relocation for:
  - Desktop
  - Documents
  - Downloads
  - Music
  - Pictures
  - Videos
- Registry keys (`User Shell Folders` and `Shell Folders`) are rewritten with correct data types.
- Introduced automatic restart of Explorer to apply new paths.
- Added verification section in log with a dump of registry redirections.
- Cleaned and unified message structure for better debugging.

---

## [1.8.7] – 2025-10-11
### ⚙️ Structural & Refactor Phase
- Simplified setup logic to make `create-localuser-relocated.ps1` fully standalone.
- Integrated automatic creation of main user directories.
- Added confirmation prompts for admin group membership, passwordless creation, and symlink setup.
- Implemented interactive input flow for user and drive configuration.
- Added localized colored output for readability.
- Replaced static folder creation with dynamic join paths to support other drives than D:.

---

## [1.8.6] – 2025-10-10
### 🧱 Foundations
- Initial working prototype with:
  - User creation
  - Base directory setup
  - Optional symlink generation
- Added detailed logging and error handling.
- Introduced optional automatic inclusion in Administrator group.
- Prepared codebase for modular expansion (FirstLoginSetup, Run script).
- Verified compatibility on Windows 10/11, PowerShell 5.1 and 7.x.

---

## 🔍 Development Notes
- All scripts are designed to run under **PowerShell (x64)** with admin privileges.
- Tested on localized Windows (German/English) setups.
- Compatible with both **NTFS and exFAT** user data drives.
- Follows a strict non-core-modifying policy — all registry edits occur per-user (HKCU only).

---

📦 **Repository**  
👉 [https://github.com/r3dvorak/r3d_create_localuser_relocated](https://github.com/r3dvorak/r3d_create_localuser_relocated)

📄 **License**: MIT  
👤 **Author**: *Richard Dvořák* — R3D Internet Dienstleistungen  
🕓 **Latest Release**: *v1.8.10-stable (2025-10-14)*
