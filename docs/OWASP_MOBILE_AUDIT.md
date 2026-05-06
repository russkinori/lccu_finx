# OWASP Mobile Top 10 (2016) Security Audit — Reassessment
## LCCU FinX — Flutter Application

**Audit Date:** 7 May 2026  
**Scope:** Client-side Flutter source (`lib/`, `android/`, `pubspec.yaml`, build scripts)

---

## Executive Summary (reassessment)

| Risk | Title | Status |
|---|---|---|
| M1 | Improper Platform Usage | Low (autoVerify added; needs assetlinks.json hosting) |
| M2 | Insecure Data Storage | Pass (CSV password column removed) |
| M3 | Insecure Communication | Pass (HTTPS enforced; pinning = optional) |
| M4 | Insecure Authentication | Pass (PKCE, lockouts, complexity checks) |
| M5 | Insufficient Cryptography | Pass (no custom crypto; obfuscation script added) |
| M6 | Insecure Authorization | Pass (RLS + server-side role resolution) |
| M7 | Client Code Quality | Pass (debug prints guarded) |
| M8 | Code Tampering | Low (jailbreak detection removed; obfuscation script remains) |
| M9 | Reverse Engineering | Low (keys injected via dart-define; defaults remain for dev) |
| M10 | Extraneous Functionality | Pass (version hidden from non-admins) |

**Notes:** several fixes were applied during this session; see 'Changes applied' below.

---

## Reassessment Findings & Rationale

- M1 — Improper Platform Usage: `android:autoVerify="true"` was added to the password-reset intent filter in `android/app/src/main/AndroidManifest.xml`. This prepares the app for Android App Links verification; hosting the `assetlinks.json` file on the redirect domain is required to complete verification (out-of-band deployment task).

- M2 — Insecure Data Storage: the CSV import no longer accepts `guardian_password` and related import logic was updated to avoid storing plaintext passwords in client-side files (`lib/features/admin/view/admin_import.dart`). Additionally, `date_of_birth` has been removed from all user provisioning workflows (CSV template, `CreateUserRequest`, `UpdateUserRequest`) to eliminate unnecessary PII collection.

- M3 — Insecure Communication: app enforces HTTPS; `android:usesCleartextTraffic="false"` already set. Certificate pinning is not implemented (documented residual risk).

- M4 — Insecure Authentication: PKCE enabled; client-side brute-force protections were added to both mobile and web login UIs (5 failures → 30s lockout). Password complexity checks (min 8, letter + number) are enforced on reset/set screens. User sign-out uses global scope to invalidate server refresh tokens.

- M5 — Insufficient Cryptography: no custom crypto found. A release build script (`scripts/build_release.sh`) was added using `--obfuscate --split-debug-info` to harden binaries and move debug symbols off-device.

- M6 — Insecure Authorization: role resolution remains server-side; RLS enforced on DB; `service_role` kept server-side only.

- M7 — Client Code Quality: all remaining raw `debugPrint` calls (notably in `principal_reconcile.dart` and `admin_report.dart`) were either wrapped in `kDebugMode` or emitted via `appLog`. The last unguarded prints were fixed.

- M8 — Code Tampering: `flutter_jailbreak_detection` was added during an earlier session but has since been **removed** (commit ba3ca8a — dependency upgrade and jailbreak detection removal). ProGuard/R8 remains enabled for Android and Dart obfuscation is still invoked by the release script (`scripts/build_release.sh`). The absence of runtime integrity checking is a residual low risk; re-adding a lightweight tamper check (e.g. via a custom root-detection utility or a maintained package) is recommended before production deployment.

- M9 — Reverse Engineering: `supabase_config.dart` now reads credentials via `String.fromEnvironment` and the project includes an `env.json.example` and `.gitignore` for `env.json`. Note: development `defaultValue` remains for convenience — build-time `--dart-define-from-file` should be used for production builds.

- M10 — Extraneous Functionality: the `Version` tile on the Settings page is now only visible to admins; no test endpoints or debug backdoors remain.

---

## Changes applied during reassessment (file list)

- `lib/auth_gate.dart`: root/jailbreak detection (flutter_jailbreak_detection) was added then subsequently removed (commit ba3ca8a) — net change: no jailbreak detection in current codebase.
- `lib/login_page.dart`: brute-force lockout, email format validator, lockout timer cleanup in `dispose()`.
- `lib/web_login.dart`: added email validation and brute-force lockout (web parity with mobile).
- `lib/settings.dart`: `Version` ListTile gated to admin users only.
- `lib/principal_reconcile.dart`: wrapped debug prints with `kDebugMode`.
- `android/app/src/main/AndroidManifest.xml`: added `android:autoVerify="true"` to the deep link intent-filter.
- `scripts/build_release.sh`: new release script using `--obfuscate --split-debug-info`.
- `.gitignore`: added `env.json` and `build/debug-info/` entries.

---

## Open Action Items (post-removal of jailbreak detection)

1. **Re-evaluate M8 runtime integrity checking** — with `flutter_jailbreak_detection` removed, consider a lightweight replacement (e.g. a custom root-detection check or a maintained alternative) before production deployment. This is a low-severity residual risk.
2. **Re-scan with updated dependency set** — the dependency upgrade in commit ba3ca8a may have introduced or resolved other vulnerabilities; run `flutter pub outdated` and a SBOM scan.

---

## Remaining action items (deployment / configuration)

1. Host `/.well-known/assetlinks.json` on the redirect domain (Supabase project domain or a verified custom domain) containing the app's signing certificate fingerprints to complete Android App Links verification.
2. Build production artifacts using `--dart-define-from-file=env.json` (or explicit `--dart-define` values) to avoid shipping default keys. Example:

```bash
flutter pub get
./scripts/build_release.sh android
# or
flutter build apk --release --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=env.json
```

3. Rotate any published anon keys if they were previously exposed in version control; ensure RLS rules are audited.

4. (Optional) Consider certificate pinning for high-risk deployments (managed school networks).

---

If you'd like, I can (choose one):
- run `flutter pub get` and build an obfuscated APK using the script (requires local Flutter tool),
- generate the `assetlinks.json` sample (you must host it at your domain and include your release SHA-256), or
- open a PR with these changes and the updated audit for review.

