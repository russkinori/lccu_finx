# LCCU FinX — Teller User Guide

**App:** LCCU FinX  
**Provided by:** Laborie Co-operative Credit Union Ltd  
**Role:** Teller (Credit Union)

---

## What is LCCU FinX?

LCCU FinX gives credit union tellers a real-time view of all school accounts, pending deposits submitted by school principals, and the tools to confirm received funds, record discrepancies, process payouts, and generate full audit reports.

---

## Signing In

1. Open the LCCU FinX app.
2. Enter your registered **email address** and **password**.
3. Tap **Sign In**.

> Your account is issued by the System administrator.

### Forgot Your Password

1. Tap **Forgot Password** on the sign-in screen.
2. Enter your email and tap **Send Code**.
3. Follow the on-screen instructions to set a new password.

---

## Navigation

The teller interface uses a **drawer menu** accessible via the hamburger icon at the top-left on mobile. Menu items:

| Menu Item | Description |
|---|---|
| **Home** | School overview list |
| **Dashboard** | Deposit confirmation and payout screen for the selected school |
| **Reports** | Transaction and audit reports |

---

## Home Screen — School Overview

The home screen lists every school with four columns:

| Column | Description |
|---|---|
| **School** | School name |
| **Account Balance** | Current confirmed balance |
| **Pending Deposit** | Cash batch submitted by the principal awaiting your confirmation |
| **Disparity** | Difference between what was expected and what was submitted |

> Any non-zero **Disparity** should be investigated before confirming.

Tap any school name to open that school's **Dashboard**.

---

## Dashboard — Confirming a Deposit

When a principal submits a deposit batch it appears as a **Pending Deposit** on the school's dashboard.

### Steps to Confirm

1. Tap the school on the Home screen.
2. The **Teller Dashboard** opens showing:
   - School name and current account balance
   - The pending deposit amount
   - A **Depositor** drop-dowwn menu
   - A **Funds Received** input field
   - A **Notes** input field
   - A **Batch** selector (links to a specific week's collection)
3. Count the physical cash received.
4. Enter the exact amount in **Funds Received**.
   - If it matches the pending amount the **Discrepancy** will be **$0.00**.
   - If there is a shortfall or excess, the discrepancy is calculated automatically.
5. Select the correct **Batch** from the dropdown.
6. Add any relevant **notes** (e.g. "Received $255.00, envelope slightly short — spoke to Principal").
7. Tap **Confirm Deposit**.
8. Clarify the amount in the pop up window.
9. Tap confirm.

The school's account balance is updated immediately and the principal's Deposited Funds figure reflects the confirmation.

### Discrepancy Recording

If the funds received differ from the pending amount:
- The discrepancy is stored against the deposit record.
- It appears in the Reports screen for audit purposes.
- A non-zero discrepancy does **not** block the confirmation — you may always add an explanatory note.

---

## Dashboard — Processing a Payout (Withdrawal)

When a school's approved withdrawal request is made by the school's representative, you will record the cash disbursement the school's **Withdrawal** section.

1. Review the payout request details (amount, requestor, requesting role).
2. Count and set aside the cash amount.
3. Enter the **Payout Amount** and an optional **note**.
4. Tap **Record Withdrawal**.
5. Clarify the amount in the pop up window.
6. Tap confirm. 

The payout is logged against the school's account and reduces the balance accordingly.

---

## Reports Screen

Open **Reports** from the drawer menu to generate transaction reports and full audit data.

### Report Scope

| Option | Description |
|---|---|
| **All Schools** | Aggregate view across every school |
| **Single School** | Detailed view for one selected school |

### Date Range Filter

Set a **From** and **To** date to scope the report to a specific period.

### All-Schools Report

The all-schools report shows a table with:

| Column | Description |
|---|---|
| School | School name |
| Balance | Account balance at end of period |
| Deposits | Total deposited in period |
| Withdrawals | Total withdrawn in period |
| Net | Deposits minus Withdrawals |
| Discrepancy | Total discrepancy amount across all confirmed deposits |
| Top Depositor | Teacher with the highest deposit activity |

Below the main table a **Discrepancy Summary** card (shown in amber when applicable) highlights the number and total value of discrepant deposits.

A **Transaction Log** section lists every individual transaction in the period with:
Date | School | Type | Submitted By | Amount | Discrepancy | Status | Notes

### Single-School Report

The single-school report shows:
- A summary card with Balance, Deposits, Withdrawals, Net, and Discrepancy figures
- A **Staff Activity** table broken down by teller/teacher
- A **Transaction Log** for that school only (without the School column)

### Exporting Reports

Tap **Export CSV** on any report screen to download the full report including the transaction log. The CSV can be opened in Excel, Google Sheets, or any spreadsheet application.

The export contains:
- Summary rows with all numeric totals
- A "Transaction Log" section appended below the summary with every individual transaction

---

## Settings

Tap **Settings** (top-right) to view your account details on mobile, read legal documents, or sign out.

---

## Signing Out

**Sign Out** or **Drawer menu** → **Log out**, or **Settings** → **Sign Out**.

---

## Daily Workflow Summary

| Step | Action |
|---|---|
| 1 | Review Home screen for any new Pending Deposits |
| 2 | Count physical cash received from each school's principal |
| 3 | Open the school dashboard and confirm each deposit |
| 4 | Record any discrepancy with a note |
| 5 | Process any pending payout requests |
| 6 | At end of period, run Reports → Export CSV for audit file |

---

## Getting Help

| Issue | Contact |
|---|---|
| School balance appears incorrect | Check pending deposits; run a report for the period |
| Principal's submission missing | Ask the principal to check their Reconciliation screen |
| Discrepancy concerns | Escalate to System management with the CSV audit export |
| App access issues | System administrator |
