========================================================================
  StackSoothe — Local Flutter & Dart Debugging Assistant
  Release Candidate: v0.1.0-challenge (Windows x64)
  Theme: "Slow and Steady" — Open-Source AI Hacktoberfest 2026
========================================================================

QUICK START (ONE-CLICK LAUNCHER):
1. Ensure Ollama is running with qwen3:1.7b:
     ollama run qwen3:1.7b
2. Double-click "start-stacksoothe.bat" to launch everything in one click!
   - Checks prerequisites automatically.
   - Starts the local diagnosis service in the background.
   - Launches the Flutter desktop interface.
   - When you close the app window, the background service stops automatically!
3. (Optional) Run "stop.bat" to manually terminate any lingering processes.

SYSTEM REQUIREMENTS:
- Windows 10 or 11 (64-bit)
- Bundled Node.js runtime included (no separate Node/npm install needed)
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
