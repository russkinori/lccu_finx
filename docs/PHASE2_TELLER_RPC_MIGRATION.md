# Phase 2 teller RPC migration

This pass removes direct Supabase table reads from `lib/teller_repo.dart` and moves teller read flows behind RPCs.

## Flutter changes

`teller_repo.dart` now uses RPCs for:

- `getTellerHomeRows()` -> `teller_home_rows`
- `getSchoolDepositSnapshot()` -> `teller_school_deposit_snapshot`
- `fetchCreditUnionDeposits()` -> `teller_deposit_events_list`
- `fetchSchoolPayouts()` -> `teller_school_payouts_list`
- `getTeachersForSchool()` -> existing `teller_list_teachers_for_school`
- `fetchPendingDepositBatches()` / `getBatchMatch()` -> existing `teller_pending_deposit_batches`

Existing write RPC usage remains in place:

- `submit_dep_batch`
- `teller_post_school_deposit_event`
- `teller_post_school_payout`

## New migration

Added:

```text
supabase/migrations/202605020002_teller_read_rpcs.sql
```

This migration creates these new read RPCs:

- `teller_home_rows(p_week_start, p_week_end)`
- `teller_school_deposit_snapshot(p_school_id, p_week_start, p_week_end)`
- `teller_deposit_events_list(p_from, p_to, p_school_id, p_teacher_id, p_limit)`
- `teller_school_payouts_list(p_from, p_to, p_school_id, p_limit)`

## Security posture

The new RPCs are `SECURITY DEFINER`, use a constrained `search_path`, and return no rows unless the caller has a matching `public.teller` record for `auth.uid()`.

This keeps the existing teller visibility model while reducing direct client dependency on financial tables such as `school_acc`, `cu_dep_event`, and `cu_payout`.

## Remaining direct access outside teller

Direct table access still remains in:

- `admin_repo.dart`
- `principal_repo.dart`
- `teacher_repo.dart`
- `common_repo.dart` for batch user-name resolution

Those should be handled in later Phase 2 passes.
