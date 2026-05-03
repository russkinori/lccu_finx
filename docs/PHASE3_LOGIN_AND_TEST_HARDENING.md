# Phase 3 login and test hardening

This pass follows the Phase 3 login role-resolution fix.

## Why it was needed

A student login attempted to resolve roles through the new admin-only RPC `admin_user_role_names`. That RPC is valid for admin screens, but normal user login should not depend on Phase 2 admin migrations.

The login path now uses the existing database RPC `current_user_role_names()` for the currently signed-in user and reserves `admin_user_role_names(p_user_id)` for admin views that inspect another user.

## Additional protections

- `test/security_hardening_test.dart` now includes a regression check to ensure current-user role resolution keeps using `current_user_role_names()`.
- `lib/app_logger.dart` now has a test-only toggle so unit tests can silence development logs without reintroducing raw `print` or `debugPrint` calls.
- `test/auth_vm_test.dart` disables app logging during AuthVm tests to keep test output clean.

## Reminder

The Phase 2 migration files are still required before using the hardened admin, teller, principal, and teacher RPC-backed screens. Normal login for existing roles should not require the new admin RPC migration.
