# Contributing to EmptyPocket 🤝

Thank you for your interest in contributing to EmptyPocket! We welcome contributions from developers of all backgrounds. This guide provides standards and best practices to ensure seamless collaboration.

---

## 1. Code of Conduct

We are committed to providing a welcoming, inclusive, and harassment-free environment. Please treat all contributors with respect and professionalism.

---

## 2. Development Setup

### Prerequisites
- **Flutter SDK**: `^3.13.1` or higher (`flutter --version`)
- **Dart SDK**: `^3.1.0` or higher
- **Android SDK**: API level 21 to 34+
- **IDE**: Android Studio, VS Code, or Antigravity IDE with Flutter & Dart extensions

### Step-by-Step Setup
1. **Fork & Clone**:
   ```bash
   git clone https://github.com/Mani242002/empty-pocket.git
   cd empty-pocket
   ```
2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Verify Baseline**:
   ```bash
   flutter analyze
   flutter test
   ```
   Ensure `flutter analyze` reports **0 issues** and all tests pass before making changes.

---

## 3. Branching & Commit Guidelines

### Branch Naming
- Features: `feat/feature-name`
- Bug Fixes: `fix/issue-description`
- Refactoring / Tests: `refactor/scope` or `test/scope`
- Documentation: `docs/topic`

### Conventional Commits Format
We strictly follow the Conventional Commits specification:
```
<type>(<scope>): <short description in present tense>

[optional body explaining rationale]
```

**Allowed Types**:
- `feat`: A new user-facing feature or enhancement.
- `fix`: A bug fix or edge case remediation.
- `refactor`: Code restructuring without changing external behavior.
- `test`: Adding or updating test cases.
- `docs`: Documentation updates.
- `perf`: Performance optimizations.
- `chore`: Dependency updates, build configs, or tooling changes.

*Example*:
```
feat(accounts): add smart inflow distribution presets for multi-purpose accounts
```

---

## 4. Architectural Standards & Best Practices

### A. Clean Architecture & Feature Separation
- Place UI and presentation state inside `lib/features/<feature_name>/`.
- Place pure business logic, calculations, and domain models inside `lib/core/`.
- Never import UI components or Flutter widgets into `lib/core/calculation/` or `lib/core/domain/`.

### B. Pure Financial Math Isolation
- All mathematical operations involving money must use `FinancialCalculator.roundMoney(value)` to avoid floating-point inaccuracies.
- Calculations must be side-effect-free pure functions.
- Every new financial formula or metric must be accompanied by dedicated unit tests in `test/`.

### C. Immutability & Entities
- Entities must be immutable (`final` fields) and include:
  - `copyWith()`
  - `toMap()` and `fromMap()`
  - Overridden `operator ==` and `hashCode`

### D. Safe Database Migrations
- Never alter existing database tables destructively.
- Increment `_databaseVersion` in `AppDatabase` and provide safe `ALTER TABLE ... ADD COLUMN` statements inside `_onUpgrade`.

---

## 5. Quality Assurance & Testing

Before submitting any Pull Request:

1. **Format Code**:
   ```bash
   dart format lib/ test/
   ```
2. **Run Linter**:
   ```bash
   flutter analyze
   ```
   PRs with analyzer warnings will not be merged.
3. **Run Test Suite**:
   ```bash
   flutter test
   ```
   All tests must pass (100% pass rate). If you introduce new features, add corresponding tests in `test/`.

---

## 6. Submitting a Pull Request

1. Push your branch to your fork.
2. Open a Pull Request against the `main` branch of `Mani242002/empty-pocket`.
3. Provide a clear summary:
   - What changed and why?
   - Any manual or automated verification performed.
   - Screenshots or video recordings for UI changes.
4. Maintainers will review your PR and provide constructive feedback.
