# Phase 3 Admin Deactivate/Reactivate Fix

## Issue

The admin edit screen always showed a `Delete User` button, even when the backend flow was a soft deactivate/reactivate workflow.

## Fix

`lib/admin_update.dart` now renders the action button based on the selected user's `isActive` state:

- Active user: `Deactivate User`
- Inactive user: `Reactivate User`

The confirmation dialog also changes title, warning text, colour, and action label based on the user's current status.

## Backend calls

- Active users call `AdminVm.deactivateUser(...)`, which uses the existing `delete_user` admin Edge Function path with the default soft-deactivate mode.
- Inactive users call `AdminVm.reactivateUser(...)`, which uses the existing `reactivate_user` admin Edge Function path.

After the action completes, the selected user and search results are refreshed so the button swaps state immediately.
