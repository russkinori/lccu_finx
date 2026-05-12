# LCCU FinX

**Version 1.0.0+2** · Flutter mobile & web app for the Laborie Co-operative Credit Union (LCCU).

The app is a financial ledger for schools taking part in the LCCU Scholthrift programme. It serves six distinct user roles — Admin for user management, Principal for school and student record overview, Teacher for student activity recording, Teller for school activity recording, Student for self activity overview, and Guardian for own child(ren) activity overview — each with a tailored interface. It integrates with [Supabase](https://supabase.com) for authentication, data storage, and real-time updates.

---

## Supported Platforms

| Platform | Status |
|----------|--------|
| Android  | Production (signed APK/AAB via `android/key.properties`) |
| iOS      | Production (Xcode / CocoaPods) |
| Web      | Supported (Chrome, sidebar navigation at ≥ 900 px) |

---

## Quick Start

**Prerequisites:**
- Flutter (stable channel) with Dart SDK **^3.9.2**
- Xcode ≥ 15 for iOS targets
- Android SDK / NDK for Android targets

```bash
flutter pub get
flutter run              # runs on connected device / simulator
flutter run -d chrome    # web
```

---

## Architecture

### Authentication Flow

```
Splash  →  AuthGate  →  role home screen
                     ↳  Login  →  (Forgot Password → OTP → Reset)
                     ↳  Password recovery deep link  →  ResetPasswordPage
```

On first login after authentication, `AuthGate` checks `ConsentService`. If the user has not yet accepted the Privacy Policy and Terms of Use, `ConsentScreen` is shown before routing to the role home screen.

| File | Purpose |
|------|---------|
| `splash.dart` | Clears local auth state, routes to AuthGate |
| `auth_gate.dart` | Listens to `supabase.auth.onAuthStateChange`, detects role, checks consent, routes |
| `login_page.dart` | Email/password login (mobile) |
| `web_login.dart` | Web-optimised login with brute-force lockout (5 failures → 30 s cooldown) |
| `forgot_password.dart` | Triggers password-reset email |
| `verify_otp_password.dart` | OTP verification + new password |
| `reset_password.dart` | Deep-link password recovery handler |
| `password_reset.dart` | Error page shown when a reset link is expired or invalid |
| `consent_screen.dart` | Non-dismissible first-login privacy & terms acknowledgement gate |
| `consent_service.dart` | Persists consent via `SharedPreferences` (`privacy_policy_accepted_v1`); bump key to force re-acceptance |

Supabase auth uses **PKCE flow** (`AuthFlowType.pkce`) — secure for both native and web targets.

### State Management

Custom **ChangeNotifier + InheritedNotifier** pattern (no external state management package).  
Each role has a ViewModel + Scope pair (e.g. `StudentVm` / `StudentScope`) distributed via `BuildContext`.

### Navigation

| Scope | Router | Routes |
|-------|--------|--------|
| Admin | `app_router.dart` | `/admin/home`, `/admin/register`, `/admin/update`, `/admin/report`, `/admin/import` |
| Teller | `teller_router.dart` | `/teller/home`, `/teller/dash`, `/teller/report` |
| Web overlay | `web_router.dart` | Admin routes wrapped in `WebShell` (sidebar) |
| Other roles | `DashboardShell` direct | Single home screen per role |
| All roles | `settings.dart` | Settings / About page accessible from the drawer or app bar |

**Responsive layout:** `adaptive.dart` switches between mobile (`DashboardShell`) and web (`WebShell`) at a **900 px** breakpoint. Text scales between **0.85×–1.40×** based on screen width.

---

## User Roles & Features

### Admin
- Dashboard with live metrics (user counts, balances, schools)
- Create / update users with role assignment
- Bulk CSV import with validation and failure export
- 8 financial report types with CSV export via `share_plus`

### Principal
- School-level deposit reconciliation (`principal_reconcile.dart`) — review weekly teacher collections and submit a deposit batch
- Teacher deposit monitoring by school (`principal_dash.dart`) — per-teacher breakdown with filter dropdowns
- Balance pill and deposit difference card
- Transaction history
- Notifications inbox

### Teacher
- Funds-in-hand summary (weekly deposit total) (`teacher_home.dart`)
- Class & student dropdowns with "ALL" aggregation
- Transaction history dashboard (`teacher_dash.dart`)
- Submit Deposit dialog
- Withdrawal request status per student
- Notifications inbox

### Teller
- Multi-school selection
- School-specific dashboard analytics (`teller_dash.dart`)
- Branch reporting (`teller_report.dart`)
- Drawer navigation
- Notifications inbox

### Student
- Account balance pill
- Transaction history card
- Request Withdrawal popup (amount + reason, `popup_bg.png` background)
- Latest withdrawal request status
- Notifications inbox

### Guardian
- Children summary table (child · balance · pending requests)
- Active withdrawal request approval / decline
- Transaction history per child
- Notifications inbox

---

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.12.4 | Backend – auth, database, storage |
| `intl` | ^0.20.2 | Number & date formatting |
| `file_picker` | ^11.0.2 | CSV file selection for bulk import |
| `csv` | ^8.0.0 | CSV parsing and generation |
| `share_plus` | ^12.0.2 | Share / export reports |
| `url_launcher` | ^6.1.10 | External links |
| `auto_size_text` | ^3.0.0 | Responsive text sizing |
| `text_responsive` | ^1.2.1 | Responsive text scaling utilities |
| `responsive_text_widget` | ^0.0.2 | Responsive text widget helpers |
| `uuid` | ^4.5.1 | Unique ID generation |
| `shared_preferences` | ^2.3.0 | Persist first-login privacy consent acceptance |

---

## UI & Theming

**Material Design 3** with a centralised theme (`app_theme.dart`) and a two-colour palette:

| Role | Colour | Hex |
|------|--------|-----|
| Primary | Blue | `#4899CB` |
| Accent / buttons | Yellow | `#F7B032` / `#F6CF52` |

**Reusable widgets** (`lib/core/widgets/`):
- `GradientButton` – yellow gradient CTA buttons
- `DetailCard` – blue-bordered data cards
- `PillRow` – labelled pill rows
- `PopupDialog` – confirmation / info dialogs
- `WelcomeHeader` – role-aware greeting banner used on every home screen
- `FriendlyError` – standardised user-facing error display widget

**Assets** live under `assets/images/` and are declared in `pubspec.yaml`.  
Key asset: `popup_bg.png` — used as the background for the Withdrawal and Deposit dialogs.

**Constants & theming** are centralised in `lib/app/app_constants.dart` (`AppColors`, `AppDimensions`, `AppAssets`) and `lib/app/app_theme.dart` (`AppTheme.lightTheme`).

**Logging:** `lib/core/utils/app_logger.dart` provides `appLog()` — a thin wrapper that guards debug output with `kDebugMode`.

---

## Testing & Validation

```bash
flutter analyze          # static analysis
flutter test             # unit & widget tests
```

---

## Contributing

1. Branch from `main` using `features/<your-change>`.
2. Run `flutter analyze` before opening a PR — zero issues required.
3. Include screenshots for any UI changes.
4. PRs target `main`.

---

## Windows Platform (C++ Runner)

The Windows runner lives in `windows/runner/` and has been hardened against SonarQube findings.

### SonarQube fixes applied

| File | Issue | Severity | Fix |
|------|-------|----------|-----|
| `macos/Flutter/GeneratedPluginRegistrant.swift` | Naming convention | Low | Renamed `RegisterGeneratedPlugins` → `registerGeneratedPlugins` |
| `win32_window.cpp` | Unsafe `reinterpret_cast` for function pointer | Medium | `SafeFunctionCast` wrapper using `std::memcpy` |
| `win32_window.cpp` | Undiscriminated `union` type punning | **Critical** | Wrapper class with compile-time `static_assert` checks |
| `win32_window.cpp` | C++17 init-statement missing | Low | `FARPROC proc` declared inside `if`-init |
| `win32_window.cpp` | Virtual dispatch ambiguity (`OnDestroy`) | High | Plain `OnDestroy()` call inside `Destroy()` for correct vtable dispatch |

### Cross-platform header compatibility
`win32_window.h` and `win32_window.cpp` use `#ifdef _WIN32` guards. On macOS/Linux the header provides lightweight mock typedefs so IntelliSense can parse the file without errors.

### Build definitions (`CMakeLists.txt`)
`WIN32_LEAN_AND_MEAN` and `_WIN32_WINNT=0x0A00` (Windows 10) are defined for the runner target.

### VS Code IntelliSense (`.vscode/c_cpp_properties.json`)
The `Win32` configuration includes `_WIN32`, `WIN32_LEAN_AND_MEAN`, `_WIN32_WINNT`, and `NOMINMAX` so headers resolve correctly on all developer machines.

