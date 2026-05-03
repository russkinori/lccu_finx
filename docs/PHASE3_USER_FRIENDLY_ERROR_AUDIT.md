# Phase 3 user-friendly error audit

This pass reviewed user-facing error paths across auth, admin, student, guardian, teacher, teller, principal, import/export and settings screens.

## Changes made

- Added `lib/friendly_error.dart`.
- Replaced raw exception display such as `PostgrestException(...)`, `StateError(...)`, and `$e` in snackbars and dashboard error banners.
- Added friendly handling for common Supabase/Auth/PostgREST/network cases:
  - missing RPC/schema cache
  - timeout/network failure
  - invalid login credentials
  - expired sessions/tokens
  - permission/RLS failures
  - duplicate records
  - incomplete role/profile setup
  - invalid CSV/template issues
  - file download/export failures
- Kept technical error logging in development through `appLog`/`appLogError`, while showing short user-safe messages in the UI.

## Remaining intentional technical handling

Some `e.toString()` usages remain inside internal parsing, diagnostics, CSV escaping, or debug-only logging. These are not displayed directly to end users.

## Recommended QA checks

Trigger these manually and verify the UI shows friendly wording:

1. Invalid login password.
2. Expired/invalid reset token.
3. Missing/disabled network connection.
4. CSV with missing required columns.
5. Admin creates a duplicate user.
6. Non-admin attempts an admin-only action.
7. Missing RPC in staging, if safely reproducible.
8. Withdrawal approve/decline failure.
9. Principal deposit submission failure.
10. Report export/download failure.
