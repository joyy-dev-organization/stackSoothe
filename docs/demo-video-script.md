# StackSoothe — Demonstration Video Script & Storyboard

**Format**: 2–3 Minute Screen Recording with Narration  
**Platform Target**: Windows 11 Desktop (1280×720 or 1920×1080)  
**Theme**: "Slow and Steady" — Open-Source AI Hacktoberfest 2026  
**Local Model**: `qwen3:1.7b` running on Ollama  

---

## Latency Compression & Disclosure Policy

Per challenge rules (`docs/challenge/w3/05-release-and-submission.md`), model inference wait times in this video are edited for viewer pacing. All accelerated cuts **must prominently display the measured original wait duration on-screen**.

| Scene | Action | Video Duration | Actual Measured Latency | On-Screen Disclosure Label |
|---|---|---|---|---|
| Scene 2 | Live diagnosis on non-canned error | ~10 seconds | **45.2 seconds** | `[Inference time compressed: actual wait was 45.2s on Intel UHD CPU]` |
| Scene 5 | Repeat recall from Fix Notebook | ~3 seconds | **1.98 milliseconds** | `[Instant retrieval: 1.98ms — 0 model calls incurred]` |

---

## Scene Breakdown & Storyboard

### Scene 1: The Recurring Problem (0:00 – 0:15)
- **Visual**: Developer looking at a common Flutter terminal error:
  ```
  LateInitializationError: Field '_userProfile' has not been initialized
  ```
- **Narration**:
  > *"Every Flutter developer has been here: your app crashes on a late initialization or BuildContext error you've already debugged three times this month. Re-explaining the same error to a chatbot wastes time and compute. That's why I built StackSoothe."*

---

### Scene 2: Real Local Model Diagnosis (0:15 – 0:50)
- **Visual**:
  - Open StackSoothe desktop app.
  - Paste the error log and `ProfileScreen` widget source code.
  - Select model: `qwen3:1.7b`.
  - Click **Diagnose Error**.
  - Show in-flight state: fields remain editable; button displays *"Stop waiting — model may continue"*.
  - Jump cut with on-screen disclosure card:  
    `[Inference time compressed: actual wait was 45.2s on Intel UHD CPU]`
  - Structured result arrives: clean markdown explanation, actionable checklist, and code example.
- **Narration**:
  > *"StackSoothe runs entirely on your machine. When you click Diagnose, our local Node service coordinates with an Ollama instance running qwen3:1.7b. Inputs remain fully editable while inference runs. In about 45 seconds on standard hardware, StackSoothe validates the model output against a strict Zod schema, providing structured guidance without any cloud calls."*

---

### Scene 3: Human Verification & Notebook Save (0:50 – 1:15)
- **Visual**:
  - The diagnosis result displays an amber badge: `STATUS: UNVERIFIED`.
  - Developer tests the proposed `initState` fix in their editor.
  - In StackSoothe, click **Mark Verified**.
  - Enter optional verification note: `"Confirmed: initialized in initState before build"`.
  - Click **Save to Fix Notebook**.
- **Narration**:
  > *"Here is the 'Slow and Steady' principle: AI advice is only a suggestion until a human tests it. Diagnoses start UNVERIFIED. The AI cannot self-certify. Once I confirm the fix in my code, I mark it Verified and save it to my local Fix Notebook."*

---

### Scene 4: Instant Repeat Recall — 0 Model Calls (1:15 – 1:40)
- **Visual**:
  - Clear the input workspace.
  - Re-paste the identical error and `ProfileScreen` source code.
  - Click **Diagnose Error**.
  - Instantly (<2 ms), a bright green banner appears:  
    `RECALLED FROM NOTEBOOK (EXACT MATCH — 0 MODEL CALLS)`
  - Show the verified report and note instantly loaded.
  - Quick glance at the service terminal: `diagnosis_request_count` did not increment!
- **Narration**:
  > *"Now for the lazy payoff. When the exact same error recurs next week, StackSoothe computes a deterministic SHA-256 fingerprint of the error, source context, and runtime. It finds the verified entry in under 2 milliseconds. Zero model inference, zero waiting, zero battery drain. That is 100% of redundant calls saved."*

---

### Scene 5: Changed Context Protection (1:40 – 2:05)
- **Visual**:
  - Paste the same error, but slightly modify the widget code (e.g. change method from `build` to `initState` or alter the class name).
  - Click **Diagnose Error**.
  - A cautionary yellow gate appears:  
    `SIMILAR PAST ERROR FOUND — CONTEXT CHANGED (POTENTIALLY STALE)`
  - The UI presents both options: "Review Past Solution" or "Run Fresh Diagnosis".
- **Narration**:
  > *"What if the error looks similar but occurred in a different file or Dart version? StackSoothe never silently serves stale advice. It detects context shifts and warns you that past fixes might not apply, giving you the choice to review or re-diagnose."*

---

### Scene 6: Architecture, Privacy Boundary & Defect Lesson (2:05 – 2:35)
- **Visual**:
  - Split screen: Architecture diagram showing loopback boundaries (`127.0.0.1:11435` and `11434`).
  - Terminal showing `npm test` passing the Sentry allowlist tests and private mode isolation.
  - Highlight the M3 defect fix: showing the timeout abort fix and token preservation.
- **Narration**:
  > *"Under the hood, StackSoothe binds strictly to loopback 127.0.0.1. In private mode, it has zero external telemetry. For developer tracing evidence, we built a separate synthetic-only test harness that emits Sentry GenAI spans. In testing, we discovered that abort timeouts were conflated as network failures; we fixed this defect, ensuring token counts and timings are preserved even on schema failure."*

---

### Scene 7: Limitations & Release Candidate (2:35 – 2:55)
- **Visual**:
  - Show GitHub repository and release page: `https://github.com/joyy-dev-organization/stackSoothe`.
  - Show `release-manifest.json` and standalone ZIP: `stacksoothe-v0.1.0-challenge-windows-x64.zip`.
  - Final card with SHA-256 checksum and MIT license.
- **Narration**:
  > *"StackSoothe is honest about limits: local LLMs take ~45 to 75 seconds on CPU, and local storage is unencrypted JSON. But for developer privacy and avoiding repeat work, it's a huge win. You can download the Windows x64 release candidate or build from source on GitHub. Thanks for watching!"*

---

## Production Checklist for Recording
- [ ] Ensure Ollama is running: `ollama run qwen3:1.7b`
- [ ] Launch via `launch.bat` in release directory or canonical dev build.
- [ ] Set display resolution to 1080p with 100% DPI scaling for crisp text.
- [ ] Include on-screen text overlays for wait cuts (Scene 2).
- [ ] Confirm audio levels are clear and balanced.
