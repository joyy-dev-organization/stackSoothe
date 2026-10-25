# StackSoothe — Quickstart Guide

**Version**: `v0.1.0-challenge` (Windows x64 Standalone Preview)  
**Challenge**: Built for the Hacktoberfest Open-Source AI Challenge 2026 (*Slow and Steady*)  
**Repository**: [github.com/joyy-dev-organization/stackSoothe](https://github.com/joyy-dev-organization/stackSoothe)  
**License**: MIT License  

---

## 1. System Requirements

- **Operating System**: Windows 10 or Windows 11 (64-bit).
- **Node.js**: **Bundled in this package** (`runtime\node.exe`, Node.js v24.14.0). You do **not** need Node.js, npm, or build tools installed on your PC.
- **Ollama**: Local Ollama runtime v0.40.8 or higher ([ollama.com](https://ollama.com/)).
- **Model**: `qwen3:1.7b` (Apache-2.0 open weights).
- **Memory**: Minimum 8 GB RAM (16 GB recommended for resident model weights).

---

## 2. Quickstart (One-Click Launcher)

### Step 1: Ensure Ollama is Running with `qwen3:1.7b`
Open a terminal and start the local model:
```powershell
ollama run qwen3:1.7b
```
*(Leave Ollama running in the background).*

### Step 2: Launch StackSoothe
Double-click **`start-stacksoothe.bat`** at the root of the extracted folder.

The launcher automatically:
1. Verifies that prerequisites are met.
2. Generates an in-memory ephemeral security token (`STACKSOOTHE_TOKEN`).
3. Spawns the local Node.js diagnosis service in the background on loopback `127.0.0.1:11435`.
4. Polls readiness on `http://127.0.0.1:11435/health` until confirmed healthy.
5. Launches the native Flutter desktop interface (`app\stacksoothe.exe`).
6. **Automatic Cleanup**: When you close the StackSoothe application window, the launcher automatically terminates **only** the background service process it started, freeing port 11435 immediately.

*(Optional: If you ever need to manually terminate any lingering background service, double-click **`stop.bat`**).*

---

## 3. Disclosures & Security

### Unsigned Preview Notice
This binary is an open-source challenge preview and is not signed with a commercial EV certificate. When double-clicking `start-stacksoothe.bat` or `stacksoothe.exe` for the first time, Microsoft Defender SmartScreen may display:
> *"Windows protected your PC — Unknown Publisher"*

Click **More info**, then click **Run anyway** to proceed.

### Privacy Invariants (100% Local-First)
- **Zero Cloud Egress**: StackSoothe connects strictly to loopback (`127.0.0.1:11435`) and your local Ollama instance (`127.0.0.1:11434`). Your error logs and source code never leave your machine.
- **Zero Telemetry in Private Mode**: Telemetry is opt-in only and 100% disabled by default (`STACKSOOTHE_SENTRY_ENABLED=0`).
- **Local Fix Notebook**: Verified fixes are stored locally on your machine as unencrypted JSON at:
  ```
  %LOCALAPPDATA%\StackSoothe\notebook.json
  ```
  Ephemeral security tokens are held strictly in process memory and are never written to the notebook.

---

## 4. Verifying Archive Integrity (SHA-256)

To verify the cryptographic integrity of your download before extracting:
```powershell
Get-FileHash -Algorithm SHA256 .\stacksoothe-v0.1.0-challenge-windows-x64.zip
```
Compare the output against the matching `.sha256` file or the checksum published in the release notes.
