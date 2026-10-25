# StackSoothe — Local Flutter & Dart Debugging Assistant

StackSoothe helps Flutter and Dart developers quickly diagnose confusing runtime errors, verify fixes locally, and recall verified solutions upon repeat recurrence with **zero additional model inference**.

## Architecture & Privacy Model

StackSoothe is built local-first for strict developer privacy:
- **Desktop Application**: Flutter Windows desktop app (`app/`).
- **Local Diagnosis Service**: Minimal TypeScript/Node service (`service/`) binding strictly to `127.0.0.1:11435`.
- **Local AI Engine**: Local Ollama instance (`127.0.0.1:11434`) running open-weight models (`qwen2.5-coder:3b` or `qwen3:1.7b`).

### Privacy Invariants & Threat Boundaries
1. **Loopback-Only Enforcement**: In private mode, all HTTP communication is restricted to `127.0.0.1`. Remote non-loopback URLs are strictly rejected at both UI and service levels.
2. **Zero Telemetry in Private Mode**: Sentry is never initialized in `server.ts` or the Flutter desktop app. External WAN access is not required for diagnosis after local models are downloaded.
3. **Local Storage**: Fix Notebook entries and non-secret user settings are stored locally under `%LOCALAPPDATA%\StackSoothe`.
   - *Limitation*: Storage at rest is unencrypted JSON.
   - *Security Rule*: Ephemeral bearer tokens are kept in session memory only and never written to the notebook store.
4. **Advisory Scope**: StackSoothe provides diagnostic advice and code suggestions. It does not execute shell commands, auto-modify source files, or scan entire local repositories. No universal NDA or device-compromise immunity is claimed.

## Request States & Cancellation

- **In-Flight Editing**: Input fields remain fully editable while diagnosis is running. Late responses are mapped to the immutable snapshot taken at execution time; if active inputs have changed, the editor text is preserved and not overwritten.
- **Honest Cancellation**: In-flight requests feature a **"Stop waiting — model may continue"** action. This terminates client waiting and closes the connection without dishonestly claiming the local model was forcibly terminated.
- **Single-Concurrency**: The service handles one diagnosis at a time. Concurrent calls receive HTTP 429 (`BUSY`), and the UI surfaces a calm retry advisory.
- **Demo Mode**: Built-in sample rules are explicitly labeled `RULE-BASED EXAMPLE (NOT AI INFERENCE)`.
