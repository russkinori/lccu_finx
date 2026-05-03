# Phase 3 Testing Baseline

This phase starts the move from manual confidence checks to repeatable test gates.

## Added regression tests

`test/security_hardening_test.dart` adds lightweight checks that should run with `flutter test`:

1. `lib/` must not contain direct Supabase `.from(...)` table calls.
2. `lib/` must not use raw `print(...)` or `debugPrint(...)` outside `app_logger.dart`.
3. The Phase 2 migration files must remain present in `supabase/migrations/`.

These tests are intentionally simple, but they protect the hardening work already completed.

## Current intent

The app can still use Supabase from Flutter, but data access should be through:

- existing RPCs,
- new source-controlled RPC migrations,
- Edge Functions for admin/auth-sensitive operations.

## Next tests to add

The next high-value tests should target workflow behaviour with mocked repositories/view-models:

- auth role routing for each role,
- student dashboard and withdrawal request state,
- guardian approval/decline state,
- teacher deposit submission state,
- teller deposit/payout posting state,
- principal reconciliation state,
- admin user lifecycle state.

These can be added without calling the live Supabase project by testing view-model state transitions and screen rendering against fake repositories.
