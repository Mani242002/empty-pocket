# Security Policy for EmptyPocket 🔒

EmptyPocket is designed with a defense-in-depth security model to ensure that user financial records and secrets remain strictly protected against unauthorized local access, data leakage, and network exploitation.

---

## 1. Supported Versions

Security updates, dependency patches, and vulnerability remediations are actively maintained on the following branches:

| Version | Supported | Status |
| :--- | :--- | :--- |
| `1.x` (Latest `main`) | :white_check_mark: | Active Security & Feature Maintenance |
| `< 1.0` | :x: | Deprecated |

---

## 2. Security Architecture & Threat Model

### A. Local Sandbox Isolation
- **Application Sandbox**: EmptyPocket's database (`app_database.db`), shared preferences, and JSON backups reside within Android's private app directory (`/data/data/dev.emptypocket.app/`).
- **No World-Readable Files**: All local database files and internal cache stores are instantiated with private mode flags (`MODE_PRIVATE`), preventing access by third-party apps installed on the same device.

### B. SQL Injection Prevention
- **Strict Parameterization**: Every database query, insert, update, and delete executed via `AppDatabase` utilizes parameterized statements (`?` placeholders) or native SQFlite query builders (`db.query()`, `db.insert()`, `db.update()`). Raw string concatenation of user inputs into SQL strings is strictly prohibited across the codebase.

### C. Secrets & API Key Management
- **BYOK (Bring-Your-Own-Key) Isolation**: Private API keys for Google Gemini or Groq are stored in Android private `SharedPreferences` within the app's protected sandbox.
- **Zero Remote Storage**: Keys are never mirrored, synchronized, or stored on remote servers.
- **Header Injection Defense**: Keys are transmitted exclusively via authenticated HTTPS `Authorization` or `x-goog-api-key` headers directly to Google or Groq servers.
- **Zero Git Leakage**: The codebase contains automated tests verifying that no hardcoded test keys or staging tokens are committed to source control.

### D. Android Permissions & Least Privilege
EmptyPocket requests only the minimal set of Android OS permissions strictly necessary for its functionality:

| Permission | Purpose | Justification |
| :--- | :--- | :--- |
| `android.permission.INTERNET` | User-initiated BYOK AI queries | Strictly used for direct client-to-provider HTTPS requests. The app does not ping servers otherwise. |
| `android.permission.SYSTEM_ALERT_WINDOW` | 24/7 Floating Quick-Add Bubble | Enables displaying the quick-entry squircle over payment applications. |
| `android.permission.FOREGROUND_SERVICE` | Floating overlay lifecycle | Keeps the floating bubble responsive across app switches. |
| `android.permission.USE_BIOMETRIC` / `USE_FINGERPRINT` | Optional App Lock | Authenticates device owner before displaying financial ledgers. |
| `android.permission.WAKE_LOCK` | Overlay responsiveness | Prevents UI freezing during floating entry expansion. |

EmptyPocket **NEVER** requests:
- `android.permission.READ_SMS` (No SMS parsing)
- `android.permission.READ_CONTACTS` (No contact harvesting)
- `android.permission.ACCESS_FINE_LOCATION` (No location tracking)
- `android.permission.RECORD_AUDIO` or `CAMERA` (No media surveillance)

### E. Open Source Transparency
- The complete Flutter codebase is 100% open source under the GNU GPL v3.0 license. Anyone can audit the compilation pipeline, dependencies, and network call sites.

---

## 3. Reporting a Vulnerability

We value the contributions of security researchers and community developers to keep EmptyPocket safe.

### Reporting Procedure
1. If you believe you have discovered a security vulnerability (such as a potential data leak, permission bypass, or injection flaw), please **do not open a public GitHub issue**.
2. Email the maintainer directly or submit a **Private Security Advisory** via GitHub Security Advisories:  
   [https://github.com/Mani242002/empty-pocket/security/advisories/new](https://github.com/Mani242002/empty-pocket/security/advisories/new)
3. Please include:
   - A detailed description of the vulnerability.
   - Steps to reproduce or proof-of-concept (PoC) code.
   - Affected device, Android version, and app version.

### Response Timeline
- **Initial Acknowledgment**: Within **48 hours**.
- **Assessment & Triage**: Within **5 business days**.
- **Fix & Disclosure**: A patched release will be published within **14 days** of confirmation, following responsible disclosure practices.
