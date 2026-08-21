# EmptyPocket 💎

> **A fast, private, offline-first personal finance tracker and wealth planner with optional BYOK AI insights.**

[![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Riverpod%202.x-0553B1)](https://riverpod.dev)
[![Database](https://img.shields.io/badge/Database-SQLite%20(100%25%20Offline)-003B57?logo=sqlite&logoColor=white)](https://sqlite.org)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20On--Device-10B981)](PRIVACY.md)
[![Tests](https://img.shields.io/badge/Tests-60%2F60%20Passing-brightgreen)](test/)

---

## 🌟 Key Features

### 1. ⚡ 100% Offline-First Transaction Tracking
- Log income and expenses in milliseconds with category, date, payment method, and notes.
- Works in **Airplane Mode** with zero reliance on cloud servers or remote databases.
- Real-time monthly balance, income, expense, and savings rate calculations.

### 2. 🎯 24/7 Floating Chat Head Quick-Add Bubble
- A subtle floating emerald bubble that docks at the edge of your screen over any app (Paytm, Google Pay, Amazon, PhonePe, Uber).
- Tap the bubble to instantly log a payment in 2 taps without leaving your current app!
- Direct SQLite insertion with automatic collapse.

### 3. 📊 Monthly Budgets & Recurring Subscriptions
- Set custom category spending limits with real-time visual progress bars.
- Dynamic color-coded alerts: *Safe (<80%)*, *Warning (80–100%)*, and *Exceeded (>100%)*.
- Manage subscriptions, rent, and recurring bills with automatic upcoming due date forecasting.

### 4. 🏆 Savings Goals & Emergency Fund Planner
- Set dedicated savings goals with progress tracking, remaining amount, and projected completion date.
- Dedicated Emergency Fund goal with smart 3–6 month living expense recommendations.
- Full contribution ledger with optional auto-transaction logging.

### 5. 💳 Loans, EMIs & Investment Portfolio
- Track debts, auto loans, mortgages, and credit cards with principal amortization and monthly EMI schedules.
- Manage investments across **Stocks, Mutual Funds, ETFs, Gold, Fixed Deposits, Crypto, Real Estate, and Cash**.
- Real-time profit/loss, return on investment (ROI), and asset class weight distribution.

### 6. 🛡️ 4-Pillar Financial Health Score & Net Worth
- Holistic net worth calculation: Total Assets − Total Liabilities.
- Comprehensive 0–100 Financial Health Gauge evaluating Savings Rate, Budget Discipline, Debt-to-Income (DTI), and Emergency Buffer.

### 7. 🤖 Optional BYOK AI Financial Advisor
- Directly integrates with:
  - **Google Gemini** (`gemini-3.7-flash`)
  - **Groq** (`qwen/qwen3.6-27b`)
- **Zero Intermediary**: API calls go directly from your phone to Google/Groq using your private API key.
- **Privacy First**: Transparent Data Preview modal before every request with raw notes redacted.

### 8. 💾 Data Portability & Privacy Lockdown
- **Full Database Backup & Restore (JSON)**: Lossless schema-validated snapshot of all 6 SQLite tables.
- **Spreadsheet-Ready Export (CSV)**: RFC 4180 compliant export with quote escaping.
- **Biometric / PIN App Lock**: Secure app protection.
- **2-Step Factory Wipe**: Confirmation code `"DELETE"` to permanently erase all records.

---

## 🏗️ Architecture & Technology Stack

```
lib/
├── app/
│   ├── app.dart                   # MaterialApp, Routing & Providers
│   └── theme/                     # Emerald Dark & Light Design System
├── core/
│   ├── database/                  # AppDatabase (Local SQLite Engine)
│   ├── domain/entities/           # Immutable Domain Models & Calculations
│   ├── repositories/              # SQLite Repositories & In-Memory Test Mocks
│   └── services/                  # BackupService, AiService, OverlayService
└── features/
    ├── dashboard/                 # Overview, Quick Stats, Financial Health Gauge
    ├── transactions/              # Ledger, Filters, Grouped List, Add/Edit Modals
    ├── budgets/                   # Category Budgets, Recurring Bills
    ├── savings/                   # Goals, Emergency Fund, Contribution History
    ├── debts/                     # Loans, EMI Tracker, Amortization
    ├── investments/               # Portfolio, Asset Allocation, ROI
    ├── reports/                   # 6-Month Trends, MoM Cash Flow, Forecasts
    ├── ai_assistant/              # BYOK Advisor, Gemini/Groq Strategy Routing
    ├── overlay/                   # 24/7 Floating Bubble Quick-Add Overlay
    └── settings/                  # JSON/CSV Backup, App Lock, Danger Zone
```

---

## 🚀 Building & Running Locally

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`^3.13.1` or higher)
- Android SDK (API 21+)
- A connected Android device or emulator

### 1. Clone the Repository
```bash
git clone https://github.com/Mani242002/empty-pocket.git
cd empty-pocket
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Unit & Widget Tests
```bash
flutter test
```

### 4. Run Static Analysis
```bash
flutter analyze
```

### 5. Build Release APK
```bash
flutter build apk --release
```

### 6. Install onto Connected Device
```bash
flutter install
```

---

## 📜 License & Disclaimers

- **License**: MIT / Open Source
- **Financial Disclaimer**: EmptyPocket is a personal budgeting and financial tracking tool. Any AI insights are educational in nature and do not constitute certified financial or tax advice.
