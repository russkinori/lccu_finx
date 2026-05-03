# Phase 2 principal RPC migration

This pass removes direct principal-side reads from the Flutter client and moves the remaining sensitive principal reads behind RPCs.

## Flutter changes

`lib/principal_repo.dart` now uses RPCs for:

- principal identity: `current_principal_id`, `current_principal_school_id`, plus the existing `f_me` lookup in `CommonRepository`
- teacher options: `principal_teachers_list`
- student/class options: `principal_students_list`
- school account balance: `principal_school_account_balance`
- student balance checks: `principal_student_balance`
- reconciliation data: `principal_reconcile_week_data`
- teacher deposit history: `principal_teacher_deposit_history`

The previous direct fallback reads against `principal`, `teacher`, `student`, and `school_acc` were removed from `principal_repo.dart`.

## Database migration added

`supabase/migrations/202605020003_principal_read_rpcs.sql` adds or replaces these helper RPCs:

- `principal_school_account_balance`
- `principal_student_balance`
- `principal_reconcile_week_data`
- `principal_teacher_deposit_history`

These functions are scoped by `current_principal_school_id()` unless the caller is an admin.

## Why this matters

Principal screens deal with student balances, school account balances, reconciliation data, and deposit history. Keeping those reads backend-scoped makes the Flutter client less dependent on broad table access and reduces the risk of cross-school data leakage.
