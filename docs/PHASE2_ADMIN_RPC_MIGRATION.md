# Phase 2 Admin RPC Migration

This pass removes the remaining direct Supabase table access from the Flutter client and moves admin read/role flows behind RPCs.

## Flutter changes

Updated `lib/admin_repo.dart` to use RPCs for:

- admin user search and user detail loading
- role lookups, role assignment, and role removal
- school/class/guardian-type/credit-union dropdowns
- school deposit reports
- debug/diagnostic checks
- deactivate/reactivate routing through the existing admin Edge Function flow

Updated `lib/teacher_repo.dart` to remove the final direct `teacher` fallback lookup and use existing current-teacher RPCs instead.

Updated `lib/common_repo.dart` to replace the final batch `user` name lookup with an RPC.

## New migration

Added:

```text
supabase/migrations/202605020004_admin_read_role_rpcs.sql
```

This migration creates or replaces:

- `admin_role_id_by_name`
- `admin_user_role_names`
- `admin_assign_role`
- `admin_remove_role`
- `admin_schools_lookup`
- `admin_classes_for_school`
- `admin_guardian_types_lookup`
- `admin_credit_unions_lookup`
- `admin_user_profiles`
- `admin_school_deposits_report`
- `user_names_by_ids`

## Security note

The admin RPCs use `SECURITY DEFINER` and explicitly require `public.is_admin()` before returning or mutating admin-scoped data. This keeps admin-wide access server-side instead of relying on direct client table access.

## Validation

After applying the migration, run:

```bash
flutter pub get
flutter analyze
flutter test
```

Then smoke-test:

1. Admin dashboard counts
2. Admin user search/filter
3. Admin create/update/deactivate/reactivate user
4. Admin dropdowns for school, class, guardian type, and credit union
5. Admin transaction report
6. Admin school deposits report
