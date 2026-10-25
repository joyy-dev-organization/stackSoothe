========================================================================
  StackSoothe — Local Flutter & Dart Debugging Assistant
  Release Candidate: v0.1.0-challenge (Windows x64)
  Theme: "Slow and Steady" — Open-Source AI Hacktoberfest 2026
========================================================================

QUICK START:
1. Ensure Ollama is running with qwen3:1.7b:
     ollama run qwen3:1.7b
2. Double-click "launch.bat" to start both the local service and desktop app.
3. To cleanly stop both processes, run "stop.bat".

SYSTEM REQUIREMENTS:
- Windows 10 or 11 (64-bit)
- Node.js v24.0.0 or higher in PATH (https://nodejs.org/)
- Ollama v0.40.8 or higher with qwen3:1.7b (https://ollama.com/)
- Minimum 8 GB RAM (16 GB recommended for local model weights)

ARCHITECTURE & PRIVACY:
- StackSoothe is 100% local-first.
- The desktop app connects strictly to loopback (127.0.0.1:11435).
- In private mode, zero telemetry or data is exported to Sentry or cloud.
- Storage is local unencrypted JSON under:
    %LOCALAPPDATA%\StackSoothe\notebook.json
- Model weights remain in local Ollama storage and are never uploaded.

EVALUATION & BENCHMARKS:
- Initial diagnosis: ~45-74s depending on hardware.
- Exact repeat recall: ~1.98ms (0 model calls).
- Redundant calls saved on exact match: 100%.

REPOSITORY & LICENSE:
- Repository: https://github.com/joyy-dev-organization/stackSoothe
- License: MIT License
========================================================================
