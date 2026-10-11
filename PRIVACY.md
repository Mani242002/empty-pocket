# Privacy Policy for EmptyPocket 🛡️

**Last Updated: September 2026**  
**Effective Date: September 2026**

EmptyPocket is engineered upon an uncompromising principle: **Your financial life belongs solely to you.**  
We believe personal financial management should never require surrendering your personal data to remote servers, advertisers, or automated scrapers.

---

## 1. Zero-Knowledge, 100% Offline-First Architecture

- **Local-Only Database**: All ledger entries, transaction histories, bank accounts, credit cards, recurring templates, savings milestones, debt amortizations, and investment portfolios are stored exclusively on your device inside an isolated SQLite database (`app_database.db`, Schema Version 10).
- **Airplane-Mode Operability**: The core application has zero runtime dependencies on cloud infrastructure or remote databases. EmptyPocket functions fully without an internet connection.
- **No User Profiles or Accounts**: EmptyPocket does not require creating an account, email registration, phone number verification, or password setup.

---

## 2. Bank Accounts & Financial Information Privacy

- **No SMS Scraping**: Unlike conventional finance applications, EmptyPocket **never requests or utilizes `READ_SMS` permissions**. We do not read, intercept, or parse your private text messages or OTPs.
- **No Banking Credentials**: EmptyPocket never requests your net-banking passwords, UPI PINs, CVVs, or bank login tokens. Account entries and balances are strictly self-managed or manually configured by you.
- **Masked Data**: Bank account numbers and card details can be stored as nicknames or last 4 digits only. Full numbers are never demanded.

---

## 3. Shared Expenses & Roommate Splits Privacy

- **No Contact Book Harvesting**: EmptyPocket does not request the `READ_CONTACTS` permission. Roommate names, split notes, and settlement entries are typed manually by you and remain strictly isolated within your device's local database.
- **No External Splitwise/Peer Sync**: Split transactions and repayment logs are not shared over any network. Only you have visibility into who owes what.

---

## 4. Zero Telemetry, Analytics, or Tracking

- **No Behavioral Telemetry**: EmptyPocket contains **zero analytics SDKs** (such as Google Analytics, Firebase Analytics, Mixpanel, or Amplitude).
- **No Advertising Networks**: The application is 100% ad-free and contains no advertising SDKs or tracking cookies.
- **No Crash Log Leaks**: No automated crash-reporting libraries transmit stack traces containing your financial parameters to remote endpoints.

---

## 5. 24/7 Floating Bubble Quick-Add Overlay

- The optional floating bubble runs as an on-device Android service utilizing the `SYSTEM_ALERT_WINDOW` permission.
- **Zero Screen Recording**: The floating service does **not** inspect, read, capture, or record the contents of other apps running on your device (e.g. Google Pay, PhonePe, Paytm).
- It functions purely as an edge-docked launcher that opens a local Flutter input card for rapid 2-tap transaction recording.

---

## 6. Optional BYOK AI Financial Advisor (Bring-Your-Own-Key)

EmptyPocket features an optional AI insights engine designed with complete privacy transparency:

- **100% User-Initiated**: No background or automated AI requests are ever executed. An AI request occurs only when you manually initiate a financial audit or ask a question in the PocketAI tab.
- **Direct Connection**: Cloud AI calls use the provider selected in Settings. Custom endpoints can use HTTPS, or HTTP for local/private hosts. EmptyPocket does not relay requests through an app server.
- **Transparent Data Preview**: Before any payload leaves your device, EmptyPocket presents an interactive **Data Preview Modal** displaying the exact JSON string to be sent. You have full discretion to inspect or cancel the transmission.
- **Redaction of Raw Notes**: Granular notes, merchant specifics, and personal labels are redacted by default; only aggregate numerical metrics (monthly income, category spending totals, savings rates) are provided to the model.
- **Secure Local Key Storage**: API keys are stored using the platform secure-storage facility. A key is sent only with a request to the configured provider or custom endpoint.

---

## 7. Data Portability, Backups & Deletion

- **JSON Backup**: Export supported financial, account, chat, and report data to a schema-validated JSON file. The exported file is not encrypted by EmptyPocket.
- **RFC 4180 CSV Export**: Export your complete transaction ledger to a standard spreadsheet-ready CSV file with quotation and delimiter escaping.
- **2-Step Factory Wipe**: Permanently erase local database records, app preferences, and stored API credentials from **Settings > Danger Zone > Factory Reset** by typing the confirmation code `"DELETE"`.

---

## 8. Compliance & Jurisdiction

Local storage and optional user-initiated AI requests do not by themselves certify compliance with a legal or industry privacy standard. Users remain responsible for protecting exported backup files and reviewing the privacy terms of any AI provider or custom endpoint they choose.

---

## 9. Contact & Inquiries

If you have questions, concerns, or feedback regarding our privacy practices, please reach out via GitHub Issues:  
[https://github.com/Mani242002/empty-pocket/issues](https://github.com/Mani242002/empty-pocket/issues)
