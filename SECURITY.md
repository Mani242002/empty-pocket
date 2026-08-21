# Security Policy for EmptyPocket

## Core Security Tenets

1. **Local Isolation**: Financial data is contained entirely within the Android app sandbox in SQLite.
2. **Key Security**: BYOK API keys (Gemini / Groq) are stored in private app shared preferences and never hardcoded in source code, committed to git, or sent to any telemetry service.
3. **No Unwanted Permissions**:
   - `INTERNET`: Required solely for optional BYOK AI calls initiated by the user.
   - `SYSTEM_ALERT_WINDOW`: Required solely for the user-controlled floating quick-add bubble.
   - `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE`: Required for floating overlay lifecycle.
4. **Transparent Audits**: 100% open-source Flutter codebase allowing independent security auditing.

## Reporting a Vulnerability

If you discover a security vulnerability in EmptyPocket, please report it privately via GitHub Issues or contact the repository owner.
