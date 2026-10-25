# StackSoothe — Local Flutter & Dart Debugging Assistant

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Release: v0.1.0-challenge](https://img.shields.io/badge/Release-v0.1.0--challenge-green.svg)](https://github.com/joyy-dev-organization/stackSoothe/releases/tag/v0.1.0-challenge)
[![Platform: Windows x64](https://img.shields.io/badge/Platform-Windows%20x64-lightgrey.svg)](https://github.com/joyy-dev-organization/stackSoothe)
[![Theme: Slow and Steady](https://img.shields.io/badge/Hacktoberfest%202026-Slow%20%26%20Steady-orange.svg)](https://dev.to/challenges/hacktoberfest-week3-2026-10-19)

StackSoothe is an open-source, local-first debugging assistant for Flutter and Dart developers. Built around the Hacktoberfest 2026 **"Slow and Steady"** theme, it eliminates redundant manual troubleshooting: paste confusing runtime logs once, receive an honest structured diagnosis from a local open-weight model, verify the fix locally, and recall verified solutions upon future recurrences with **zero additional model inference** (under 2 ms).

---

## The "Slow and Steady" Payoff

Flutter developers repeatedly encounter identical runtime failures (e.g. `BuildContext` used across async gaps, null-check operators on uninitialized fields, `RenderFlex` layout overflows). Re-explaining the same error to a chat interface or searching old forum threads is tedious, unwanted work.

StackSoothe automates that repetition:
1. **First Occurrence**: Diagnosed locally by `qwen3:1.7b` running on Ollama. The report details likely cause, actionable fix steps, severity, and confidence.
2. **User Verification**: Diagnosis starts `UNVERIFIED`. Only an explicit human action transitions it to `VERIFIED`. The AI never self-certifies a fix.
3. **Deterministic Fingerprinting**: StackSoothe generates a composite FIPS 180-4 SHA-256 fingerprint from the canonical error message, source code context, and project/runtime environment.
4. **Instant Recall (0 Model Calls)**: When the exact error and context recur, StackSoothe retrieves the verified fix in **1.98 ms**, avoiding 100% of redundant model inference calls and resident compute.
5. **Context-Change Protection**: If the error recurred in a modified source file, different framework version, or new project, StackSoothe flags the match as `POTENTIALLY STALE` and requires human review rather than silently serving outdated advice.

---

## Architecture & Threat Boundaries

StackSoothe uses a decoupled, local-first loopback architecture:

```
┌─────────────────────────────────┐
│     StackSoothe Desktop App     │  (Flutter / Dart Windows Runner)
│   - Fix Notebook (%LOCALAPPDATA%)│
│   - Deterministic SHA-256 Keys  │
└────────────────┬────────────────┘
                 │ HTTP (127.0.0.1:11435) with Ephemeral Bearer Token
                 ▼
┌─────────────────────────────────┐
│   Local Node/TypeScript Service │  (Single-concurrency loopback shim)
│   - Exact Host Header Validation │
│   - CSRF Origin Rejection       │
│   - Strict Zod Schema Validation │
└────────────────┬────────────────┘
                 │ HTTP (127.0.0.1:11434)
                 ▼
┌─────────────────────────────────┐
│          Local Ollama           │  (qwen3:1.7b, Apache-2.0, 2.0B params)
│   - 100% Local Inference        │
└─────────────────────────────────┘
```

### Privacy Invariants & Security Guarantees
- **Loopback-Only Binding**: The TypeScript diagnosis service binds strictly to `127.0.0.1:11435`. Exact `Host` validation rejects host-header poisoning (e.g. `localhost.attacker.com`), and browser `Origin` headers are rejected to prevent CSRF from browser tabs.
- **Zero Telemetry in Private Mode**: `server.ts` and the Flutter desktop application contain zero Sentry initialization, DSNs, or background telemetry. Private diagnosis operates 100% offline with zero outbound network egress.
- **Local Storage Disclosure**: Verified notebook records are stored locally at `%LOCALAPPDATA%\StackSoothe\notebook.json`. Storage at rest is unencrypted JSON; ephemeral bearer tokens are held in session memory only and never written to the notebook.
- **Strict Advisory Scope**: StackSoothe provides diagnostic advice and code suggestions. It does not execute terminal commands, modify local source files, or scan private repository directories.

---

## Standalone Windows Release Candidate

A pre-packaged, standalone Windows x64 release candidate is available with a **one-click launcher** and bundled Node.js runtime (no separate Node/npm, Flutter, or MSVC installation required):

- **Release Tag**: [`v0.1.0-challenge`](https://github.com/joyy-dev-organization/stackSoothe/releases/tag/v0.1.0-challenge)
- **Direct Download**: [**`stacksoothe-v0.1.0-challenge-windows-x64.zip`**](https://github.com/joyy-dev-organization/stackSoothe/releases/download/v0.1.0-challenge/stacksoothe-v0.1.0-challenge-windows-x64.zip) (45.84 MB)
- **Archive SHA-256**: `e6e483726cf5ab64885b143afcd11bde3f0c360ffa76d7960c7965d79209c5e6`
- **Checksum Asset**: [`stacksoothe-v0.1.0-challenge-windows-x64.zip.sha256`](https://github.com/joyy-dev-organization/stackSoothe/releases/download/v0.1.0-challenge/stacksoothe-v0.1.0-challenge-windows-x64.zip.sha256) (112 B)

### Asset Checksum Manifest (`release-manifest.json`)

| Component | File Path | Size | SHA-256 Checksum |
|---|---|---|---|
| Complete Archive | [`stacksoothe-v0.1.0-challenge-windows-x64.zip`](https://github.com/joyy-dev-organization/stackSoothe/releases/download/v0.1.0-challenge/stacksoothe-v0.1.0-challenge-windows-x64.zip) | 45.84 MB | `e6e483726cf5ab64885b143afcd11bde3f0c360ffa76d7960c7965d79209c5e6` |
| Checksum File | [`stacksoothe-v0.1.0-challenge-windows-x64.zip.sha256`](https://github.com/joyy-dev-organization/stackSoothe/releases/download/v0.1.0-challenge/stacksoothe-v0.1.0-challenge-windows-x64.zip.sha256) | 112 B | `3b74ed2c4745bc31c756b5a9102782136d97d42eaefa9ddfa3cef5909ac06efd` |
| Native Runner | `app/stacksoothe.exe` | 89.6 KB | `3ab9e272f5d0200cc675f1e33da4ab72e8241e943fee55b8471b3c8541db50e2` |
| Flutter Engine | `app/flutter_windows.dll` | 21.28 MB | `a147927018fcc1a843fb3938ead58838d2e185ce7d840bc4191a7a1b90c21015` |
| Dart AOT Code | `app/data/app.so` | 5.62 MB | `0e2937bc15d7ea8422d6ac3708e020404a3d8f36c6570c859394ec65a32f66a2` |
| Bundled Node Runtime | `runtime/node.exe` | 91.38 MB | `63c259c81e5d472b5f11c8d506070130cb04a1ecf84b80377a34ed6ec9048088` |

### System Requirements
- **OS**: Windows 10 or 11 (64-bit)
- **Node.js**: Bundled inside package (`runtime/node.exe`, Node v24.14.0; no installation needed)
- **Ollama**: v0.40.8 or higher ([ollama.com](https://ollama.com/))
- **Local Model**: `qwen3:1.7b` (run `ollama run qwen3:1.7b`)
- **Memory**: 8 GB RAM minimum (16 GB recommended for resident model weights)

### Quick Start (One-Click Launcher)
1. Ensure Ollama is running with `qwen3:1.7b`:
   ```powershell
   ollama run qwen3:1.7b
   ```
2. Download [**`stacksoothe-v0.1.0-challenge-windows-x64.zip`**](https://github.com/joyy-dev-organization/stackSoothe/releases/download/v0.1.0-challenge/stacksoothe-v0.1.0-challenge-windows-x64.zip) (45.84 MB) and verify its SHA-256 checksum.
3. Extract the archive and double-click **`start-stacksoothe.bat`**. The launcher automatically:
   - Verifies prerequisites.
   - Spawns the local Node diagnosis service in the background on loopback `127.0.0.1:11435`.
   - Polls verified `/health` readiness.
   - Launches the Flutter desktop interface.
   - When you close the app window, the owned background service terminates automatically.
4. Review **`QUICKSTART.md`** inside the package for full instructions, Windows SmartScreen guidance, and local privacy guarantees.
5. (Optional) Run **`stop.bat`** to manually terminate any background processes if needed.

---

## Empirical Evaluation Ledger (M5 Scorecard)

The evaluation was conducted on Windows 11 with an Intel Core CPU, 16 GB RAM, and shared Intel UHD graphics using local model `qwen3:1.7b` (ID: `8f68893c685c`, Apache-2.0, context length 40,960).

### Validation Rates (12 Predeclared Synthetic Cases)

| Evaluation Tier | Sample Size | Passed | Pass Rate | Evaluation Criteria |
|---|---|---|---|---|
| **Raw Schema Validity** | 8 diagnostic cases | 8 | **100%** | Strict Zod validation on initial model generation without repair |
| **Repaired Schema Validity** | 8 diagnostic cases | 8 | **100%** | Conforming structured diagnosis within at most 1 repair retry |
| **Semantic Correctness** | 8 diagnostic cases | 8 | **100%** | Groundedness, honest uncertainty (D6), prompt injection safety (D7) |
| **State & Reuse Correctness** | 4 state cases | 4 | **100%** | Exact fingerprinting, 0-call recall, atomic persistence, cancel isolation |

### Latency & Performance Breakdown

- **Cold Start Latency** (D1, verified model unload via `ollama ps`): **50.8 s** (Model load: 3,450 ms, prompt eval: 4,728 ms, eval: 42,576 ms).
- **Warm Inference Latency** (D2–D8):
  - **Median**: **74.1 s**
  - **Range**: `46.8 s` – `100.1 s`
- **Measured Repeat Payoff**:
  - Initial diagnosis: **~45.0 s**
  - Exact repeat recall: **1.98 ms**
  - Redundant model calls avoided across 5 repeats: **5 (100% call avoidance)**
  - Changed-context controls (source changed, runtime changed, project changed): **0 false exact recalls**
- **System Memory Footprint (Sampled Process Tree)**:
  - Node.js Service RSS: `334.5 MB`
  - Flutter Desktop RSS: `726.5 MB`
  - Ollama Engine RSS: `91.2 MB`
  - **Total System Footprint**: **`1152.2 MB`** (~1.15 GB)
- **Human Developer Trial**: **`NOT CONDUCTED`**. Time savings and payoff metrics are confined strictly to measured machine benchmarks (1.98 ms lookup vs ~45 s inference; 100% call avoidance on exact match).

---

## Strategic Partner Integration Scope

- **Sentry Agent Tracing**: An isolated synthetic evidence harness (`service/src/evidence/sentry-spike.ts`, `service/test/evidence-runner.test.ts`) instruments the exact same diagnosis function with documented manual GenAI spans (`op: "gen_ai.chat"`, `name: "chat qwen3:1.7b"`). Serialized transport envelopes were strictly audited: zero prompt words, source code, model output text, or authorization tokens leave the machine. Private application mode remains 100% exporter-free.
- **Render Deployment**: **`OMITTED`**. Per challenge rules, Render is optional only after core verification and explicit spending approval. In the absence of cloud spend authorization, StackSoothe ships as a fully functional Windows desktop release candidate and real video demo.

---

## Building from Source

### Prerequisites
- Flutter SDK v3.12.1+ with desktop Windows tools enabled (`flutter config --enable-windows-desktop`)
- Visual Studio 2022 / Build Tools with C++ desktop development workload
- Node.js v24.14.0+ and npm v11.9.0+

### Build & Test Sequence
```powershell
# 1. Test Node Service (all 33 tests across 8 suites)
cd service
npm install
npm run build
npm test

# 2. Test Flutter Application (all 29 tests across 9 suites)
cd ../app
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test

# 3. Compile Windows Native Release Executable
flutter build windows --release

# 4. Package Release Archive and Manifest
cd ..
powershell -ExecutionPolicy Bypass -File .\package.ps1
```

---

## Demonstration Video & Storyboard

A complete 2–3 minute video demonstration script detailing timing breakdown, scene actions, narration, and on-screen wait-cut disclosures is documented in [`docs/demo-video-script.md`](docs/demo-video-script.md).

---

## License

This project is licensed under the [MIT License](LICENSE).
The default local model (`qwen3:1.7b`) is licensed under the [Apache-2.0 License](https://ollama.com/library/qwen3:1.7b).
