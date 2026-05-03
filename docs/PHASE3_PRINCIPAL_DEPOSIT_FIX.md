# Phase 3 Principal Deposit/Reconciliation Fix

## Changes

- Principal reconciliation now defaults to the current Sunday-start reconciliation week instead of the previous week.
- The empty state now says "selected week" rather than "this week" to avoid confusion when another week is selected.
- `getSchoolWeeklySummary` now accepts the existing database RPC field `deposited_total` as well as the compatibility alias `total_deposited`.
- School deposit details now sum all returned deposit history rows instead of using only the latest row.

## Why

The existing database RPC `principal_school_deposited_total()` returns `deposited_total`, while the Flutter refactor expected `total_deposited`, causing Deposited Funds to display `$0.00`.

The reconciliation screen previously defaulted to the previous Sunday-start week. If the active collection was in the current week, the screen showed no collections even though Funds On-Site displayed outstanding cash.
