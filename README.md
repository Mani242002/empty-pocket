# EmptyPocket 💎

> **A private, offline-first personal finance tracker, wealth planner, and ledger engine with deep multi-account linking, shared roommate expense tracking, and optional BYOK AI insights.**

[![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20Riverpod%202.x-0553B1)](https://riverpod.dev)
[![Database](https://img.shields.io/badge/Database-SQLite%20(Schema%20v10)-003B57?logo=sqlite&logoColor=white)](https://sqlite.org)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20On--Device-10B981)](PRIVACY.md)
[![Tests](https://img.shields.io/badge/Tests-140%2F140%20Passing-brightgreen)](test/)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%2012%20--%2016+-3DDC84?logo=android&logoColor=white)](android/)

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
  - [1. 100% Offline-First Transaction Engine](#1--100-offline-first-transaction-engine)
  - [2. 👥 Shared Expenses & Roommate Reimbursements](#2--shared-expenses--roommate-reimbursements)
  - [3. 🏦 Bank Account Purpose Linking & Smart Allocations](#3--bank-account-purpose-linking--smart-allocations)
  - [4. ⚡ Category-Based Smart Default Account Routing](#4--category-based-smart-default-account-routing)
  - [5. 🧾 Read-Only Receipt Modal First](#5--read-only-receipt-modal-first)
  - [6. 📊 4-Tab Budgets & Goals Hub](#6--4-tab-budgets--goals-hub)
  - [7. 💳 Deep Debt, EMI & Portfolio Investment Tracking](#7--deep-debt-emi--portfolio-investment-tracking)
  - [8. 📈 Advanced Reports & Analytics](#8--advanced-reports--analytics)
  - [9. 🔘 24/7 Floating Bubble Quick-Add Overlay](#9--247-floating-bubble-quick-add-overlay)
  - [10. 🛡️ 4-Pillar Financial Health Score & Net Worth](#10-️-4-pillar-financial-health-score--net-worth)
  - [11. 🤖 Optional BYOK AI Financial Advisor](#11--optional-byok-ai-financial-advisor)
  - [12. 💾 Enterprise Data Portability & Security](#12--enterprise-data-portability--security)
- [Architecture & Technology Stack](#️-architecture--technology-stack)
- [Database Schema (Version 10)](#-database-schema-version-10)
- [Getting Started & Local Setup](#-getting-started--local-setup)
- [Running Automated Tests](#-running-automated-tests)
- [Security & Privacy](#-security--privacy)
- [Contributing](#-contributing)
- [License & Disclaimers](#-license--disclaimers)

---

## 💡 Overview

**EmptyPocket** is engineered for individuals who want complete control over their financial reality without sacrificing data sovereignty. Unlike cloud-dependent budgeting apps that scrape SMS messages or upload sensitive statements to third-party servers, EmptyPocket executes **100% locally on-device**. 

From high-precision double-entry style ledger adjustments to complex roommate dinner bill splits, recurring subscriptions, and SIP allocations across specific bank accounts, EmptyPocket brings enterprise-grade financial precision directly into your pocket.

---

## 🌟 Key Features

### 1. ⚡ 100% Offline-First Transaction Engine
- **Instantaneous Record Creation**: Log expenses, incomes, and internal transfers in under 2 seconds.
- **True Transfer Isolation**: Internal fund transfers between your bank accounts or card repayments are tracked cleanly without inflating gross monthly expenses or earned income.
- **Smart Category Matcher**: Integrated longest-keyword predictor automatically categorizes titles like *"Sent money to mom"*, *"Zerodha SIP"*, *"Netflix"*, or *"Star Health renewal"* with zero latency.
- **Airplane-Mode Ready**: Completely independent of cloud connections or remote APIs.

### 2. 👥 Shared Expenses & Roommate Reimbursements
- **True Personal Expense Math**: When paying a ₹4,000 dinner bill for friends with your share being ₹1,000:
  - **Gross Outflow**: ₹4,000 disbursed from your payment source.
  - **True Net Expense**: ₹1,000 factored into your monthly budget and savings rate so your budgets never trigger false alarms.
  - **Pending Reimbursements**: ₹3,000 tracked on your dashboard and Dedicated Splits tab.
- **Non-Taxable Repayment Inflows**: Roommate paybacks received into your bank account are classified as *Shared Expense Reimbursement* and excluded from earned salary income calculations.
- **Credit Card Bill Earmarking**: If the original expense was charged to a Credit Card, friend repayments deposited into your bank account are marked as **Earmarked for Credit Card Bill** so funds are safeguarded until payment time.
- **Quick Split Presets**: 1-tap presets for 50/50, 1/3, 1/4, or 100% for friends.

### 3. 🏦 Bank Account Purpose Linking & Smart Allocations
Tailored specifically for modern real-world multi-bank setups:
- **Dedicated Purpose Mapping**:
  - `ICICI Bank`: Salary & Income Hub / Recurring Bills & EMIs
  - `IDFC FIRST Bank`: Emergency Fund Vault
  - `Kotak Bank`: Daily Spending & Out-of-Pocket Expenses
  - `AU Small Finance Bank`: Short-Term Goals (Split percentage allocations)
  - `SBI`: Investments & Insurance (Multi-purpose Inflows)
- **Single-Goal Account Sync (e.g., IDFC → Emergency Fund)**:
  - Enable *Auto-Sync with Account Balance* to have the goal's progress mirror the live account balance automatically.
- **Multi-Goal Account Split (e.g., AU Bank → Vacation 60%, Gadgets 40%)**:
  - Configure allocation percentages per goal with visual indicators showing allocated balance vs unallocated idle buffer ("sits quiet").
- **Smart Inflow Distribution for Multi-Purpose Accounts (SBI)**:
  - When transferring money from Salary into SBI, launch the **Smart Inflow Distribution Sheet** with quick presets:
    - `60/30/10`: 60% Investments & SIP, 30% Insurance Premiums, 10% Idle Buffer.
    - `70/20/10`: Aggressive Wealth Accumulation.
    - `50/40/10`: High Insurance & Protection.
    - `50/50`: Balanced Allocation.

### 4. ⚡ Category-Based Smart Default Account Routing
- Intelligently pre-selects the appropriate payment source based on the chosen category:
  - `Food`, `Groceries`, `Shopping`, `Transport`, `Cafe` ➔ Auto-selects **Kotak (Daily Spending)**.
  - `Investments & SIP`, `Mutual Funds`, `Gold ETF` ➔ Auto-selects **SBI (Investments & Insurance)**.
  - `Insurance Premiums` (Health, Term Life, Motor) ➔ Auto-selects **SBI (Investments & Insurance)**.
  - `Bills & Utilities`, `Subscriptions`, `EMIs`, `House Rent` ➔ Auto-selects **ICICI (Bills & EMIs / Salary Hub)**.
  - `Salary` income ➔ Auto-selects **ICICI (Salary Hub)**.
- Visual chip confirmation: `⚡ Smart auto-selected: Kotak (Daily Spending)`.

### 5. 🧾 Read-Only Receipt Modal First
- Tapping any transaction in the ledger or dashboard opens a rich receipt modal rather than forcing an editable form:
  - Full financial metadata, category badge, timestamp, and account/card details.
  - Shared expense breakdown card displaying total bill, personal share, collected funds, and pending reimbursement.
  - Top-right action suite:
    - 📋 **Duplicate**: 1-tap transaction clone with automatic balance synchronization.
    - ✏️ **Edit**: Seamlessly transitions to editable form.
    - 🗑️ **Delete**: Confirmation dialog with automatic balance rollback.
    - ✕ **Close**.

### 6. 📊 4-Tab Budgets & Goals Hub
- **Horizontally Scrollable TabBar**: No truncated headers across screen sizes.
- **Tab 1: Monthly Budgets**: Category limits with color-coded alerts (*Safe*, *Warning 80–100%*, *Exceeded >100%*).
- **Tab 2: Savings & Goals**: Target amount tracking, completion projections, and account balance linking.
- **Tab 3: Recurring & Bills**: Subscriptions and bills with **Standardized Two-Tier Payment Selection** (Payment Mode Chips + Dynamic Live Balance Dropdown).
- **Tab 4: Shared & Splits**: Active roommate splits, repayment progress bars, and 1-tap settlement actions.

### 7. 💳 Deep Debt, EMI & Portfolio Investment Tracking
- **Loans & EMIs**: Principal amortization, remaining balances, and interest vs principal breakdown. Direct bank balance deduction toggle on EMI payments.
- **Multi-Asset Portfolio**: Real-time tracking across **Mutual Funds, Equity Stocks, Gold/ETFs, Fixed Deposits, Crypto, Real Estate, and Cash**.
- **Portfolio Funding Toggle**: Enable "Fund from Bank Account" for new purchases while leaving historical holdings intact.

### 8. 📈 Advanced Reports & Analytics
- **Account-Wise Outflow Breakdown**: Real-time spending bars per bank account and credit card.
- **Wealth Building & Capital Allocation Gauge**: Distinguishes wealth-building transfers (SIPs, Goal deposits, Debt Principal reduction) from pure consumption.
- **True Personal Spend vs Shared Reimbursements**: Reconciles gross bill spending against friend repayments.
- **Month-over-Month Category Spending Shifts**: Color-coded delta chips indicating spending increases or reductions.
- **3-Month Forward Cash Flow Forecast**: Offline projections combining salary schedules, recurring bills, and active debt EMIs.

### 9. 🔘 24/7 Floating Bubble Quick-Add Overlay
- **Docked Squircle Bubble**: Stays anchored to the edge of your screen over any app (Google Pay, PhonePe, Paytm, Amazon).
- **Inline Split Toggle**: Log roommate-split expenses directly while paying at merchant checkout counters.
- **Keyboard & Status Bar Resilience**: Fullcover modal with `SafeArea` and `resizeToAvoidBottomInset` ensures seamless typing and zero notch clipping.
- **Instant SQLite Persistence**: Records commit directly to on-device database before bubble collapses.

### 10. 🛡️ 4-Pillar Financial Health Score & Net Worth
- **Holistic Net Worth**: Real-time calculation of Total Assets (Bank balances + Investments + Cash) − Total Liabilities (Credit Card Dues + Debt Principal).
- **0–100 Health Score**: Evaluates Savings Rate (30%), Budget Discipline (30%), Debt-to-Income Ratio (20%), and Emergency Buffer (20%).

### 11. 🤖 Optional BYOK AI Financial Advisor
- Directly integrates with **Google Gemini (`gemini-3.7-flash`)** and **Groq (`qwen/qwen3.6-27b`)**.
- **Zero Intermediary**: API calls travel directly from your device to Google/Groq over HTTPS.
- **Transparent Data Preview**: Inspect the exact JSON payload before sending. Raw transaction notes and sensitive identifiers are redacted by default.

### 12. 💾 Enterprise Data Portability & Security
- **JSON Full-State Backup**: Lossless schema-validated snapshot across all 6 SQLite tables.
- **RFC 4180 CSV Export**: Standard spreadsheet export with full escape compliance.
- **Biometric / PIN App Lock**: Protect financial data using fingerprint or device credentials.
- **2-Step Factory Reset**: Requires typing confirmation code `"DELETE"` to permanently erase all records.

---

## 🏗️ Architecture & Technology Stack

EmptyPocket follows **Clean Architecture** principles structured by feature modules:

```
lib/
├── app/
│   ├── app.dart                   # MaterialApp, Route Configuration & Riverpod Scope
│   └── theme/                     # Emerald Dark & Light Theme System
├── core/
│   ├── database/                  # AppDatabase (Local SQLite Engine, Version 10 Migration)
│   ├── domain/entities/           # Immutable Domain Models (Transactions, Accounts, Goals, etc.)
│   ├── repositories/              # Abstract Repositories & In-Memory Test Doubles
│   ├── calculation/               # Pure Math Engines (FinancialCalculator, ReportsCalculator)
│   ├── services/                  # BackupService, AiService, OverlayService
│   └── utilities/                 # CategoryMatcher, CurrencyFormatter, AppHaptics
└── features/
    ├── dashboard/                 # Overview, Balance Cards, Pending Shared Card
    ├── transactions/              # Ledger, TransactionDetailSheet, AddEditTransactionSheet
    ├── accounts/                  # BankAccounts, CreditCards, SmartInflowDistributionSheet
    ├── budgets/                   # Monthly Budgets, AddRecurringSheet, Shared & Splits Tab
    ├── savings/                   # Savings Goals, AddContributionSheet, Allocation Sliders
    ├── debts/                     # Loans, EMI Tracker, RecordDebtPaymentSheet
    ├── investments/               # Portfolio Tracking, Asset Allocation, AddEditInvestmentSheet
    ├── reports/                   # ReportsAnalyticsScreen, MoM Trends, Wealth Gauge
    ├── ai_assistant/              # BYOK Advisor, Gemini & Groq Providers
    ├── overlay/                   # FloatingBubbleOverlay (24/7 Quick-Add Bubble)
    └── settings/                  # JSON/CSV Backup, Biometrics, Factory Reset
```

---

## 🗄️ Database Schema (Version 10)

EmptyPocket stores all financial data inside an encrypted local SQLite database:

| Table Name | Key Columns | Purpose |
| :--- | :--- | :--- |
| `transactions` | `id`, `title`, `amount`, `type`, `category`, `date`, `account_id`, `credit_card_id`, `is_shared`, `my_share_amount`, `reimbursed_amount`, `is_settled`, `shared_with`, `linked_entity_id` | Core offline ledger entries & split tracking |
| `bank_accounts` | `id`, `account_name`, `bank_name`, `account_type`, `used_for`, `current_balance`, `is_default` | Bank accounts, cash stashes & purpose tags |
| `credit_cards` | `id`, `card_name`, `bank_name`, `credit_limit`, `used_amount`, `billing_day`, `due_day`, `card_network` | Credit cards, utilization ratios & RuPay UPI |
| `budgets` | `id`, `category`, `amount`, `month` | Monthly category spending caps |
| `savings_goals` | `id`, `title`, `target_amount`, `current_amount`, `target_date`, `linked_account_id`, `allocation_percentage`, `auto_sync_account` | Savings milestones & account balance sync |
| `goal_contributions` | `id`, `goal_id`, `amount`, `date`, `source_account_id` | Historical goal deposits & balance audit |
| `debts` | `id`, `title`, `total_amount`, `remaining_amount`, `interest_rate`, `monthly_emi`, `linked_account_id` | Loans, debts, and EMI repayment plans |
| `debt_payments` | `id`, `debt_id`, `amount`, `principal_portion`, `interest_portion`, `date`, `source_account_id` | EMI payment audit log |
| `investments` | `id`, `name`, `asset_class`, `invested_amount`, `current_value`, `source_account_id` | Portfolio holdings across 8 asset classes |
| `recurring_expenses` | `id`, `title`, `amount`, `category`, `frequency`, `account_id`, `credit_card_id`, `next_due_date` | Subscriptions & recurring bills |

---

## 🚀 Getting Started & Local Setup

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`^3.13.1` or higher)
- Android SDK (API 21+)
- Connected Android device or emulator with USB debugging enabled

### 1. Clone the Repository
```bash
git clone https://github.com/Mani242002/empty-pocket.git
cd empty-pocket
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Static Code Analysis
```bash
flutter analyze
```

### 4. Execute Full Automated Test Suite
```bash
flutter test
```

### 5. Build Release APK
```bash
flutter build apk --release
```
The compiled production binary will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### 6. Install to Connected Android Device
```bash
flutter install
```

---

## 🧪 Running Automated Tests

EmptyPocket features a comprehensive automated testing suite covering unit, domain, repository, financial math, and integration flows:

```bash
# Run all 140 tests across all 22 test suites
flutter test

# Run specific financial calculator tests
flutter test test/shared_expenses_and_deep_linking_test.dart
flutter test test/bank_purpose_and_reports_test.dart

# Run widget flow integration test
flutter test test/widget_test.dart
```

---

## 🔒 Security & Privacy

For detailed information on our threat model, local isolation, and data governance:
- Read our [Privacy Policy](PRIVACY.md).
- Read our [Security Policy](SECURITY.md).

---

## 🤝 Contributing

We welcome community contributions, bug reports, and feature proposals! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for code style guidelines and PR processes.

---

## 📜 License & Disclaimers

- **License**: [GNU General Public License v3.0](LICENSE).
- **Financial Disclaimer**: EmptyPocket is an independent personal budgeting and financial tracking tool. It does not provide certified investment, legal, or tax advice.
