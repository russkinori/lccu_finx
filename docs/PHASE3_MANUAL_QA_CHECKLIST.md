# Phase 3 manual QA checklist

Use this checklist after `flutter analyze` and `flutter test` pass. It is designed for a Supabase staging project with known test users for each role.

## Pre-flight

- Apply all SQL migrations in `supabase/migrations/` to staging.
- Confirm the app is pointing to staging through `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`.
- Confirm each role has one known test account: admin, principal, teacher, teller, student, guardian.
- Confirm the student is linked to the guardian and enrolled in the school/class used by the teacher/principal.
- Confirm the teller account has access to the branch used by the school account.

## Student flow

1. Log in as the student.
2. Confirm the student dashboard loads without an RPC/function error.
3. Confirm the displayed student name, balance, latest withdrawal, and transaction list are correct.
4. Submit a small withdrawal request.
5. Log out and back in; confirm the latest withdrawal appears with the expected pending/approval status.
6. Confirm the student cannot navigate into admin, teacher, principal, teller, or guardian screens.

## Guardian flow

1. Log in as the guardian.
2. Confirm only linked children are visible.
3. Confirm the highlighted withdrawal matches the student withdrawal submitted above.
4. Approve the withdrawal with a note.
5. Confirm the request no longer appears as pending if the business workflow expects it to move forward.
6. Attempt to open or act on an unrelated request, if a test route/action exists; it should fail cleanly.

## Teacher flow

1. Log in as the teacher.
2. Confirm teacher dashboard metrics load.
3. Confirm only students/classes from the teacher's school are visible.
4. Record a student deposit/collection using a low-value test amount.
5. Confirm the transaction appears in teacher history.
6. Confirm teacher cannot see another school's students or collections.

## Principal flow

1. Log in as the principal.
2. Confirm only the principal's school data appears.
3. Review student/account balances and teacher collections.
4. Open the reconciliation view for the current week.
5. Submit or flag a reconciliation item depending on the test scenario.
6. Confirm another school's data is not visible in dropdowns, reports, or history.

## Teller flow

1. Log in as the teller.
2. Confirm school/deposit snapshots load through the teller screens.
3. Review pending deposit batches.
4. Post a school deposit against a test pending batch.
5. Confirm the posted deposit appears in deposit history.
6. Post a payout only for an approved request.
7. Confirm invalid/mismatched deposits or payouts are rejected with a clear message.

## Admin flow

1. Log in as admin.
2. Confirm dashboard metrics load.
3. Search for users by name/email/role.
4. Open user details for each role.
5. Create a temporary test user.
6. Update that user, then deactivate/reactivate it.
7. Confirm admin cannot deactivate or delete their own account.
8. Confirm dropdowns for school, class, guardian type, and credit union load correctly.

## Regression checks after manual QA

Run these again after any fixes:

```bash
flutter analyze
flutter test
```

Record any failed route, RPC error, incorrect data visibility, or unclear user-facing error message before moving to release preparation.
