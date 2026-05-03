# Phase 2 RPC migration

## Completed in this package

The teacher withdrawal history screen no longer reads `withdrawal_req` directly from Flutter. It now calls:

```sql
public.teacher_withdrawals_list(p_class_id uuid, p_student_id uuid, p_limit integer)
```

The migration is included at:

```text
supabase/migrations/202605020001_teacher_withdrawals_list.sql
```

Deploy this migration before testing the teacher withdrawal history flow.

## Why this change matters

The previous Flutter implementation read withdrawal records directly and applied part of the class filtering client-side. The RPC centralises the teacher-school boundary in the database and returns only teacher-scoped withdrawal rows.

## Next recommended migrations

1. Student home/account/latest withdrawal reads.
2. Teller pending deposits and payout history reads.
3. Principal fallback direct reads.
4. Common repository `user` / `user_role` reads.

## Student/Common RPC pass

The student dashboard now relies on existing deployed RPCs (`student_home`, `student_transaction_history`, and `request_withdrawal`) instead of direct reads from `student`, `student_acc`, and `withdrawal_req`. Common current-user helpers now call `f_me` and `f_me_role` instead of direct current-user `user` / `user_role` reads.

## Teller repository read migration

Added `supabase/migrations/202605020002_teller_read_rpcs.sql` and updated `lib/teller_repo.dart` so teller home, deposit history, payout history, and school deposit snapshot reads go through RPCs instead of direct `.from(...)` queries.

## Principal read hardening

Added `202605020003_principal_read_rpcs.sql` and updated `principal_repo.dart` so principal identity, balance, reconciliation, and teacher/student option reads use scoped RPCs rather than direct table reads. The remaining direct Supabase table access is now concentrated mainly in admin flows, one teacher identity lookup, and one common batch name lookup.

## Admin RPC hardening

Added `supabase/migrations/202605020004_admin_read_role_rpcs.sql` and moved remaining admin repository direct table access behind RPCs. See `docs/PHASE2_ADMIN_RPC_MIGRATION.md`.

## Phase 3 regression coverage

`test/security_hardening_test.dart` now protects the Phase 2 hardening by checking that `lib/` does not reintroduce direct `.from(...)` calls or raw logging outside `app_logger.dart`.


## Compatibility note added in Phase 3

Normal login role resolution now uses the existing `current_user_role_names()` RPC when resolving the currently authenticated user. The new `admin_user_role_names(p_user_id)` RPC is only required for admin screens that inspect another user's roles.

## Phase 3 deposit-detail semantics hotfix

Added:

- `principal_school_outstanding_deposit_detail()`
- `principal_teacher_outstanding_deposit_detail(p_teacher_id uuid)`

These keep the principal dashboard detail cards scoped to the current outstanding/on-site deposit obligation, while the Deposited Funds card continues to show historical posted deposits.
