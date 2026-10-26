---
title: I Got Tired of Fixing the Same Flutter Error Twice — So I Built StackSoothe
published: false
description: An open-source, local-first debugging assistant that diagnoses Flutter runtime errors with local AI, verifies fixes with humans, and recalls verified fixes in 1.98ms with zero model calls.
tags: devchallenge, hf26challenge, flutter, ai
cover_image: 
canonical_url: 
---

*This is a submission for the [Hacktoberfest Open-Source AI Challenge: Slow and Steady](https://dev.to/challenges/hacktoberfest-week3-2026-10-19).*

---

## What I Built

If you develop with Flutter, you know the feeling of meeting the exact same runtime error you spent forty minutes debugging three months ago:

- A `BuildContext` accessed across an asynchronous gap (`use_build_context_synchronously`).
- A `LateInitializationError: Field 'controller' has not been initialized`.
- A `RenderFlex` overflow of 18 pixels at the bottom of a keyboard-adjacent form.

Every time it happens, the routine is the same: copy the stack trace, open a chat interface, re-paste your source snippet, wait for a generic explanation, sift through hallucinations, and re-discover the fix. It is tedious, unwanted repetition.

**StackSoothe** is an open-source, local-first debugging workspace built around the **"Slow and Steady"** philosophy: **solve a hard problem once, verify the fix with human judgment, and never spend local compute or mental effort diagnosing that exact failure again.**

```
┌─────────────────────────────────┐
│     StackSoothe Desktop App     │  (Flutter 3.24 Windows Runner)
│   - Fix Notebook (%LOCALAPPDATA%)│
│   - Deterministic SHA-256 Keys  │
└────────────────┬────────────────┘
                 │ Loopback HTTP (127.0.0.1:11435) with Ephemeral Bearer Token
                 ▼
┌─────────────────────────────────┐
│   Local Node/TypeScript Service │  (Single-concurrency loopback shim)
│   - Exact Host Header Validation │
│   - CSRF Origin Rejection       │
│   - Strict Zod Schema Validation │
└────────────────┬────────────────┘
                 │ Loopback HTTP (127.0.0.1:11434)
                 ▼
┌─────────────────────────────────┐
│          Local Ollama           │  (qwen3:1.7b, Apache-2.0, 2.0B params)
│   - 100% Local Inference        │
└─────────────────────────────────┘
```

### The "Slow and Steady" Flow

1. **First Occurrence (Local AI Diagnosis)**: Paste your runtime exception log and source snippet. StackSoothe queries a local open-weight model (`qwen3:1.7b` running on Ollama) via an authenticated loopback service. It produces an honest, structured diagnosis detailing the root cause, actionable fix steps, severity, and confidence.
2. **Human Verification Gate**: The diagnosis is marked **`UNVERIFIED`** by default. StackSoothe operates on a strict rule: **the AI never self-certifies a fix**. Only an explicit action by the developer marks the solution **`VERIFIED`**.
3. **Deterministic Fingerprinting**: Upon verification, StackSoothe computes a composite FIPS 180-4 SHA-256 fingerprint combining the canonicalized error pattern, source context AST shape, and runtime environment.
4. **Instant Repeat Recall (0 Model Calls)**: When the exact same error and context recur in your workspace, StackSoothe bypasses the LLM entirely, retrieving your verified solution from local storage in **1.98 milliseconds** — saving **100% of redundant model inference calls**.
5. **Context-Change Protection**: If the same error occurs in a modified file, a different project, or a newer Flutter SDK, StackSoothe refuses to blindly apply stale advice. Instead, it prominently warns:  
   `SIMILAR PAST ERROR FOUND — CONTEXT CHANGED (POTENTIALLY STALE)`  
   and requires human confirmation.

---

## Demo

### Video Demonstration
*(Insert 2–3 minute video demo link below: YouTube / Vimeo / Loom / GitHub Asset)*

<!-- VIDEO LINK PLACEHOLDER -->
**Demo Video**: [Watch the 2-Minute StackSoothe Walkthrough](https://github.com/joyy-dev-organization/stackSoothe/releases/tag/v0.1.0-challenge)  
*(Wait-cut disclosures: inference duration visibly compressed from actual 45.2s Intel UHD CPU execution, as detailed in our storyboard).*

### Standalone Windows Release Candidate (One-Click Launcher)

You do **not** need Flutter, Dart, Node.js, or MSVC build tools installed to run StackSoothe. A complete standalone Windows x64 preview is packaged with a bundled Node runtime:

- **Release Page**: [StackSoothe Windows Preview v0.1.0-challenge](https://github.com/joyy-dev-organization/stackSoothe/releases/tag/v0.1.0-challenge)
- **Direct Download**: [**`stacksoothe-v0.1.0-challenge-windows-x64.zip`**](https://github.com/joyy-dev-organization/stackSoothe/releases/download/v0.1.0-challenge/stacksoothe-v0.1.0-challenge-windows-x64.zip) (45.84 MB)
- **Cryptographic Checksum Asset**: [`stacksoothe-v0.1.0-challenge-windows-x64.zip.sha256`](https://github.com/joyy-dev-organization/stackSoothe/releases/download/v0.1.0-challenge/stacksoothe-v0.1.0-challenge-windows-x64.zip.sha256)  
  `e6e483726cf5ab64885b143afcd11bde3f0c360ffa76d7960c7965d79209c5e6`

#### Quickstart:
1. Ensure Ollama is running with `qwen3:1.7b`:
   ```powershell
   ollama run qwen3:1.7b
   ```
2. Download and extract `stacksoothe-v0.1.0-challenge-windows-x64.zip`.
3. Double-click **`start-stacksoothe.bat`**. The launcher automatically starts the local backend service, verifies loopback health, opens the desktop UI, and cleans up background processes on window closure!

---

## Code & In-Window Provenance

- **GitHub Repository**: [https://github.com/joyy-dev-organization/stackSoothe](https://github.com/joyy-dev-organization/stackSoothe)
- **Release Tag**: [`v0.1.0-challenge`](https://github.com/joyy-dev-organization/stackSoothe/releases/tag/v0.1.0-challenge) (Commit `f6940c8` / `2587678`)
- **License**: MIT License

### Provenance Disclosure
In compliance with the contest rules regarding fresh development:
- The initial UI prototype was authored on **20 October 2026**, strictly within the official Hacktoberfest Week 3 contest window (19 Oct 2026 09:00 PDT – 25 Oct 2026 23:59 PDT).
- The standalone TypeScript loopback service, strict Zod schema validation, Sentry tracing harness, automated one-click launcher, and M5 evaluation suite were developed from scratch during Week 3.

---

## How I Built It

### Architecture & Threat Boundaries

StackSoothe is built with a decoupled, defense-in-depth architecture:
- **Frontend**: Flutter Desktop for Windows (Dart 3.5), implementing Material 3 calm dark-mode styling with zero telemetry and unencrypted local JSON storage at `%LOCALAPPDATA%\StackSoothe\notebook.json`.
- **Backend Service**: Single-concurrency Node.js/TypeScript daemon binding strictly to loopback `127.0.0.1:11435`.
  - Rejects foreign host headers (`isLoopbackHost` defense).
  - Rejects browser `Origin` headers to protect against web-tab CSRF.
  - Requires an ephemeral Bearer token passed in memory by the launcher (`STACKSOOTHE_TOKEN`).
- **Local Model**: `qwen3:1.7b` (Apache-2.0 open weights, 2.0B parameters) served locally via Ollama (`127.0.0.1:11434`).

### Real Defect, Sentry Tracing & The Fix

During Milestone 3 (Tracing & Hardening), instrumenting our diagnosis engine revealed a critical edge-case defect:

1. **The Bug (Conflated Timeouts & Dropped Tokens)**:
   When an in-flight diagnosis timed out or when a model generated invalid JSON, `AbortSignal.timeout` threw an `AbortError` identical to a user manual cancellation (`USER_CANCELLED`). Furthermore, when schema parsing failed, the raw response token counts and converted Ollama microsecond timings were discarded, leaving zero visibility in monitoring.
2. **The Reproducer (`defect-reproducer.test.ts`)**:
   We wrote an automated regression test reproducing both failure modes: verifying that an operation timeout produces `OLLAMA_TIMEOUT` and span error type `TIMEOUT`, and that schema failures preserve token usage metrics.
3. **The Fix**:
   We refactored signal composition in `diagnosis.ts` using `AbortSignal.any()`, clearly distinguishing client disconnects from model execution timeouts, and updated the schema validation branch to retain full timing metadata.
4. **Sentry Agent Tracing Harness**:
   To observe and verify this behavior, we built a dedicated synthetic evidence harness (`service/src/evidence/sentry-spike.ts`). It instruments the **exact same diagnosis function** used in production with OpenTelemetry-compliant manual GenAI chat spans:
   - `op: "gen_ai.chat"`
   - `name: "chat qwen3:1.7b"`
   - Low-cardinality attributes: `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `ollama.timing.total_ms`, and `gen_ai.duration_ms`.
   - **Strict Privacy Invariant**: An automated payload-inspection test (`service/test/evidence-runner.test.ts`) proves that **zero prompt text, source code snippets, model response text, or authorization tokens are ever serialized into Sentry envelopes**.
   - **Private Mode Exporter-Free Guarantee**: The production desktop app and normal backend service run 100% exporter-free with zero Sentry DSNs or background telemetry.

---

## Why Does Open Innovation Matter?

Open-source AI and local inference fundamentally change the privacy and economics of developer tools:

1. **Absolute Data Sovereignty**: When an unhandled exception strikes in proprietary enterprise code or client projects, pasting that code into a cloud AI assistant risks violating NDAs and leaking credentials. StackSoothe keeps all source code, stack traces, and local fix records on loopback `127.0.0.1`.
2. **Inspectable Contracts vs. Black Boxes**: Proprietary cloud APIs change prompts, degrade model versions, and alter formatting silently. With open-weight models (`qwen3:1.7b`) and open schemas (Zod + Dart models), developers control the system prompt, context bounds, and validation schemas.
3. **Honest Open-Model Trade-Offs**:
   - **Inference Speed**: On a standard Windows laptop with an Intel UHD GPU and 16 GB shared RAM, cold CPU inference takes **45–74 seconds**. Cloud APIs might respond in 3 seconds, but they require internet egress and continuous per-token billing.
   - **Memory Footprint**: Running the local stack consumes **1152.2 MB total RAM** (Flutter UI: ~142 MB, Node service: ~58 MB, Ollama + weights: ~952 MB).
   - **Local Storage Limitations**: The Fix Notebook is stored locally at `%LOCALAPPDATA%\StackSoothe\notebook.json` as unencrypted JSON. It is protected by OS-level file permissions, not encryption-at-rest.

---

## My Agent Session

Developing StackSoothe involved continuous human-agent pair programming with Google Antigravity across seven distinct milestones (M0 through M6). 

*(Session transcripts were captured and verified locally via DevRelay. Agent sessions are retained privately for owner review; inspectable public slices may be published following manual verification).*

<!-- Optional embed placeholder: {% agent_session <id> %} -->

Key architectural pivots recorded during our sessions:
- Rejecting complex multi-agent orchestrators in favor of a minimal, robust loopback TypeScript shim (Decision D-8).
- Rejecting cloud fallback in favor of an honest offline-first loopback architecture.
- Designing space-safe Windows launcher batch scripts (`start-stacksoothe.bat`) and bundled Node runtime distribution.

---

## The Lazy Payoff

We conducted an empirical 12-case evaluation benchmark (`projects/stacksoothe/service/fixtures/m5-evaluation-report.md`) across Flutter runtime errors to quantify the effort saved:

| Metric | Measured Result | Evaluation Caveat |
|---|---|---|
| **Initial Cold Diagnosis Latency** | **45.2 s – 74.1 s** | Measured on Intel UHD CPU; hardware-dependent |
| **Exact Repeat Recall Latency** | **1.98 ms** | Deterministic SHA-256 fingerprint match |
| **Model Inference Calls Saved** | **5 / 5 (100% Avoidance)** | Exactly 0 model calls on repeat errors |
| **Context-Change Protection** | **0 False Recalls (100% Safe)** | Safely flags modified code/runtime shifts |
| **Schema Conformance** | **12 / 12 (100% Valid JSON)** | Zod schema validation pass rate |
| **External Human User Trial** | *NOT CONDUCTED* | Claims limited to verified machine benchmarks |

**The Lazy Bottom Line**: By waiting 45 seconds once and verifying the fix, every future occurrence is resolved in under 2 milliseconds without re-explaining the problem, opening a browser, or burning another cycle of model compute.

---

## Prize Categories

### Sentry Agent Tracing (Partner Category)
StackSoothe enters the **Sentry Agent Tracing** partner category based on genuine technical integration:
- Manual OpenTelemetry GenAI chat spans (`gen_ai.chat`) with documented timing attributes and token usage metrics.
- A real discovered defect in abort signal timeout handling reproduced with automated tests and resolved.
- Strict payload serialization tests ensuring zero private code or prompt text leaves the machine.

*(Note on other categories: Render, Entire, Mastra, and Temporal were evaluated during planning but are explicitly omitted as they were not genuinely deployed in the final build).*
