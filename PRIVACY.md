# Privacy Policy for EmptyPocket

**Last Updated: August 2026**

EmptyPocket is built on a fundamental principle: **Your financial data belongs exclusively to you.**

---

## 1. 100% Offline-First Architecture
- All transactions, budgets, recurring bills, savings goals, debts, and investments are stored locally on your device in an encrypted SQLite database.
- EmptyPocket operates fully in Airplane Mode with 0% cloud database dependency.
- There are no user accounts, no tracking cookies, and no telemetry SDKs.

## 2. Zero Background Telemetry
- The app collects **no diagnostic data, crash logs, behavioral analytics, or location info**.
- No background network services communicate with third-party servers.

## 3. Optional AI Insights (BYOK — Bring Your Own Key)
- AI financial analysis is 100% optional and only triggered when you manually request an audit or ask a question in the PocketAI tab.
- You supply your own private API key for **Google Gemini (`gemini-3.7-flash`)** or **Groq (`qwen/qwen3.6-27b`)**.
- API calls go **directly** from your device to the official provider endpoint (Google or Groq) using HTTPS. There is **no intermediate server or proxy**.
- Before any request is sent, a **Data Preview Modal** displays the exact payload for your review and explicit consent.
- Raw transaction notes are redacted by default; only high-level numerical summaries (income, expenses by category, net worth) are transmitted.

## 4. 24/7 Floating Chat Head Quick-Add
- The floating bubble overlay runs as an on-device Android service (`SYSTEM_ALERT_WINDOW`) solely to enable fast 2-tap transaction recording over apps like Paytm or Google Pay.
- It does not inspect other apps' screens or contents; it only opens a local input card when tapped.

## 5. Data Portability & Deletion
- **Export**: You can export your full database as a structured JSON backup or export transactions to standard RFC 4180 CSV at any time.
- **Factory Reset**: You can permanently wipe all local database records in 2 steps from **Settings > Danger Zone > Factory Reset**.
