# Phase 3 Principal RPC Compatibility Hotfix

This hotfix aligns the Flutter principal screens with the Phase 2 RPC hardening work.

Apply this migration in Supabase before retesting the principal dashboard:

```text
supabase/migrations/202605020005_principal_rpc_compat_hotfix.sql
```

It creates or replaces:

- `principal_school_account_balance(p_school_id)`
- `principal_student_balance(p_student_id)`
- `principal_reconcile_week_data(p_week_start)`
- `principal_teacher_deposit_history(p_teacher_id, p_limit)`

It also reloads PostgREST schema cache using:

```sql
notify pgrst, 'reload schema';
```

The Flutter client has also been made more tolerant of the existing `principal_school_deposit_history` return shape by accepting either `deposited_amount` or `amount`.
