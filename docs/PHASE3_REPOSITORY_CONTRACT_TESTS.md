# Phase 3 repository contract tests

Added `test/repository_rpc_contract_test.dart`.

The test is intentionally static. It scans repository source files and confirms that sensitive role workflows stay behind their RPC/Edge Function boundaries.

It checks these areas:

- Student repository uses `student_home`, `student_transaction_history`, and `request_withdrawal`.
- Guardian repository uses guardian RPCs rather than direct guardian/student/withdrawal table reads.
- Teacher repository keeps withdrawal, collection, and transaction operations behind teacher RPCs.
- Teller repository keeps school, deposit, and payout reads behind teller RPCs.
- Principal repository keeps school-scoped data access behind principal RPCs.
- Admin repository uses admin RPCs or Edge Functions and does not reintroduce `.from(...)` table calls.

These tests are not a substitute for real role-based integration tests against Supabase, but they protect the Phase 2 hardening work from accidental regression.
