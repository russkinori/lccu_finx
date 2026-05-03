# Phase 2 - Student/Common RPC Migration

## Summary

This pass continues the data-access hardening started in Phase 2. It assumes the RTF database exports represent the currently deployed Supabase backend.

## App-side changes

### Student repository

`lib/student_repo.dart` no longer directly reads:

- `student`
- `student_acc`
- `withdrawal_req`

The student home flow now uses the existing deployed `student_home` RPC for:

- current student id
- active account id
- balance
- latest withdrawal request details

It continues to use the existing deployed `student_transaction_history` RPC for transaction history and the existing deployed `request_withdrawal` RPC for withdrawal creation.

### Common repository

`lib/common_repo.dart` now uses existing deployed RPCs for current-user lookups:

- `f_me`
- `f_me_role`

This avoids direct `user` and `user_role` reads for the common current-user and role paths.

`getUserNamesByIds()` still performs a direct `user` table lookup because it is used for batch name resolution in staff-facing flows. That should be considered in a later principal/admin-specific hardening pass.

## Backend migrations

No new migration was required for the student/common changes because the required RPCs already exist in the current database exports:

- `student_home`
- `student_transaction_history`
- `request_withdrawal`
- `f_me`
- `f_me_role`

## Next recommended targets

1. Teller dashboard reads: replace direct `school`, `school_acc`, `cu_dep_event`, `teacher`, `teacher_coll`, and `cu_payout` table reads with teller-scoped RPCs.
2. Principal fallback reads: replace direct `principal`, `teacher`, `student`, and `school_acc` fallback queries where possible.
3. Admin direct reads: decide which admin tables are acceptable as direct reads and which should be Edge Function/RPC only.
