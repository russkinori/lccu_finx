# Phase 3 Deposit Detail Semantics Fix

This fixes the principal dashboard displaying the school-wide historical deposited total inside the detail cards.

## Correct separation

- **Deposited Funds card**: all posted school deposits, historically/overall.
- **School Deposit Details > Deposited**: amount deposited against the currently outstanding/on-site due amount.
- **Teacher Deposit Details > Deposited**: amount deposited against the selected teacher's currently outstanding/on-site due amount.

For an outstanding $10 collection and $330 historical posted deposits, the expected dashboard is:

- Funds On-Site: `$10.00`
- Deposited Funds: `$330.00`
- School Deposit Details: `$10.00 / $0.00 / $10.00`
- Teacher Deposit Details: `$10.00 / $0.00 / $10.00`

## New RPCs

- `principal_school_outstanding_deposit_detail()`
- `principal_teacher_outstanding_deposit_detail(p_teacher_id uuid)`

The Flutter principal repository calls these RPCs for the detail cards. The existing `principal_school_deposited_total()` remains the source for the top-level Deposited Funds card.
