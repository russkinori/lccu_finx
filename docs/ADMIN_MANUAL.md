# LCCU FinX — Administrator Manual

**App:** LCCU FinX  
**Provided by:** Laborie Co-operative Credit Union Ltd  
**Role:** Admin

---

## Overview

This manual covers the full administration of the LCCU FinX application.  
As an administrator you are responsible for:

- Creating and maintaining user accounts across all roles
- Managing school, class, and credit union reference data
- Running system-wide reports
- Monitoring application health via the dashboard
- Managing the underlying Supabase database

---

## Table of Contents

1. [Signing In](#1-signing-in)  
2. [Admin Dashboard — Overview](#2-admin-dashboard--overview)  
3. [Navigation (Web & Mobile)](#3-navigation-web--mobile)  
4. [Registering New Users](#4-registering-new-users)  
5. [Bulk User Import via CSV](#5-bulk-user-import-via-csv)  
6. [Updating Existing Users](#6-updating-existing-users)  
7. [Deactivating and Reactivating Users](#7-deactivating-and-reactivating-users)  
8. [Reports](#8-reports)  
9. [Settings](#9-settings)  
10. [Database Management (Supabase)](#10-database-management-supabase)  
11. [Common Administrative Tasks](#11-common-administrative-tasks)  
12. [Troubleshooting](#12-troubleshooting)  

---

## 1. Signing In

1. Open the LCCU FinX app (web or mobile).
2. Enter your admin **email address** and **password**.
3. Tap / click **Sign In**.

The app will detect your admin role and route you directly to the **Administration Overview** screen.

### Password Reset (Admin)

1. Tap **Forgot Password** on the sign-in screen.
2. Enter your email and tap **Send Code**.
3. Enter the verification code sent to your inbox.
4. Set a new password — must be strong (minimum 8 characters, mixed case recommended).

> **Security note:** Admin accounts have elevated privileges. Use a strong, unique password and do not share it.

---

## 2. Admin Dashboard — Overview

After signing in you land on the **Administration Overview** dashboard showing live system metrics:

| Metric | Description |
|---|---|
| **Active Users** | Total number of active accounts across all roles |
| **Schools** | Number of schools registered in the system |
| **Credit Union Branches** | Number of credit union branches |
| **Student Accounts** | Total student saving accounts |
| **Total Student Account Value** | Sum of all student account balances |
| **Total School Account Value** | Sum of all school account balances |

Tap / click the **Refresh** button (top-right of the header) to reload metrics from the database.

---

## 3. Navigation (Web & Mobile)

### Web Layout

On wide screens the app uses a **side navigation drawer** (WebShell) with links:

- **Home** — Administration Overview
- **Register** — Register New Users
- **Update** — Find and Update Users
- **Reports** — System Reports
- **Settings** — Account and app information

### Mobile Layout

On phones the app uses a **hamburger menu** (top-left). The same four sections are accessible via the drawer.

---

## 4. Registering New Users

Navigate to **Register** (or `/admin/register`) to create individual user accounts.

### Required Fields (all roles)

| Field | Notes |
|---|---|
| First Name | |
| Last Name | |
| Email | Must be unique in the system |
| Password | Minimum 8 characters; user should change on first login |
| Role | Select from the dropdown — see Role-Specific Requirements below |

### Role-Specific Requirements

| Role | Additional Required Fields |
|---|---|
| **Student** | School, Class, Opening Balance, Account Number, Guardian (linked existing guardian or create new) |
| **Teacher** | School, Title |
| **Principal** | School, Title |
| **Guardian** | Title, Gender (optional), Address, Mobile |
| **Teller** | Credit Union branch, Title |
| **Admin** | Title |

### Steps

1. Fill in First Name, Last Name, Email, Password.
2. Select the **Role**.
3. Depending on role, additional fields appear — fill them all in.
4. For **Student** role:
   - Select a **School** first; the Class dropdown populates.
   - Select a **Class**.
   - Enter **Account Number** and **Opening Balance**.
   - Link a **Guardian**: search the list. If the guardian is not yet registered, register the guardian account first, then come back and link.
5. Tap **Create User**.

A success or error message appears at the bottom of the form.

> **Note:** Email addresses must be unique across all roles. You cannot create two users with the same email.

---

## 5. Bulk User Import via CSV

Navigate to **Register** → tap **Import from CSV** to import multiple users at once.

### CSV File Format

The CSV must have these **required column headers** (case-insensitive):

| Column | Required | Notes |
|---|---|---|
| `email` | Yes | Unique email for each user |
| `first_name` | Yes | |
| `last_name` | Yes | |
| `role` | Yes | `student`, `teacher`, `principal`, `guardian`, `teller`, or `admin` |
| `password` | No | If omitted, a secure password is auto-generated |
| `title` | No | Required for teacher/principal/teller/guardian/admin |
| `gender` | No | `male`, `female` or blank |
| `mobile` | No | Guardians |
| `address` | No | Guardians |
| `school` or `school_id` | Conditional | Required for student/teacher/principal |
| `class` or `class_id` | Conditional | Required for students |
| `account_number` | Conditional | Students |
| `opening_balance` | Conditional | Students (numeric) |
| `guardian_user_email` | Conditional | Students — email of the linked guardian |
| `guardian_first_name` | No | If guardian does not exist yet, these fields let the importer create the guardian account automatically |
| `guardian_last_name` | No | See above |
| `guardian_mobile` | No | See above |
| `guardian_address` | No | See above |
| `guardian_type` or `guardian_type_id` | No | e.g. "Mother", "Father" |
| `credit_union` or `credit_union_id` | Conditional | Required for teller role |

You may use human-readable names in `school`, `class`, `guardian_type`, and `credit_union` columns — the importer will resolve them to database IDs automatically.

### Import Procedure

1. Prepare the CSV file as described above.
2. Navigate to **Register** → **Import from CSV**.
3. Tap **Pick File** and select your `.csv` file.
4. The app parses and shows a preview row count.
5. Tap **Start Import**.
6. The progress bar shows row-by-row processing.
7. When complete, each row shows ✓ **Success** or ✗ **Failed: [reason]**.
8. If any rows failed, tap **Export Failures** to download a CSV of only the failed rows with the error reason appended. Fix and re-import those rows.

### Common Import Errors

| Error | Fix |
|---|---|
| `Missing required "email"` | Ensure every data row has an email |
| `Invalid role "X"` | Use exactly: `student`, `teacher`, `principal`, `guardian`, `teller`, `admin` |
| `Unknown school "X"` | Check exact school name spelling in the database |
| `Unknown class "X"` | Confirm class name for that specific school |
| `No guardian user found...` | Either provide guardian details for auto-creation, or register the guardian first |

---

## 6. Updating Existing Users

Navigate to **Update** (or `/admin/update`) to search, edit, or manage existing accounts.

### Searching for a User

1. Type a name or email into the search bar.
2. Results appear in real time with a debounce delay.
3. Tap a result row to load that user's details.

### Editable Fields

| Field | Notes |
|---|---|
| First Name | |
| Last Name | |
| Email | Changing email requires the user to log in with the new address |
| Mobile | |
| Address | |
| Role | See role-specific fields below |
| School / Class | Students, teachers, principals |
| Guardian | Students |
| Credit Union | Tellers |
| Title / Gender | Where applicable |

### Saving Changes

1. Modify the desired fields.
2. Tap **Update**.
3. A success or error message confirms the outcome.

> Changes to email, school, or class assignment take effect immediately at next login.

---

## 7. Deactivating and Reactivating Users

Deactivating a user prevents them from logging in without deleting their account history.

### Deactivating

1. Search for the user on the **Update** screen.
2. Select the user.
3. Tap **Deactivate** (shown when the user is currently active).
4. Confirm the action.

The user's `is_active` flag is set to `false`. They will be unable to sign in and will receive an access denied message.

### Reactivating

1. Search for the user (inactive users still appear in search).
2. Select the user.
3. Tap **Reactivate**.
4. Confirm the action.

> The user may need to reset their password after reactivation if their token has expired.

---

## 8. Reports

Navigate to **Reports** (or `/admin/report`) for system-wide financial reporting.

### Report Types

| Type | Description |
|---|---|
| **All Transactions** | Every deposit and withdrawal across all schools for the period |
| **All Schools Summary** | Per-school balance, deposit, and withdrawal totals |
| **All Students Activity** | Deposits and withdrawals per student |
| **School Deposits** | Deposit-only view per school |
| **Teacher Activity** | Deposits grouped by teacher |
| **Student Activity** | Filter to a single student's full history |
| **Class Summary** | Aggregated totals for a specific class |
| **Custom Report** | Full filter control: school, class, student, teacher, transaction type, date range |

### Generating a Report

1. Select a **Report Type** from the dropdown.
2. Set a **From** date and **To** date.
3. For scoped reports (Teacher Activity, Student Activity, Class Summary) use the additional dropdowns to narrow scope.
4. For **Custom Report** select transaction type (All / Deposits / Withdrawals / Count).
5. Tap **Preview** to load the first 20 rows.
6. Use **Next** / **Previous** to page through results.

### Exporting a Report

- Tap **Export CSV** (or **Share** on mobile) to download the full report.
- The CSV contains all records (not limited to the preview page).
- On mobile, the Share sheet allows saving to Files, emailing, or printing.

### Transaction Types

| Type ID | Label |
|---|---|
| `all` | All Transactions |
| `deposit` | Deposits only |
| `withdrawal` | Withdrawals only |
| `count` | Transaction count (no amounts) |

---

## 9. Settings

Accessible via the **Settings** icon (top-right on any screen).

| Section | Contents |
|---|---|
| **About LCCU FinX** | Version number (admin-only), credit union name |
| **Account Information** | Logged-in email, role (ADMIN) |
| **Legal** | Privacy Policy, Terms of Use links |
| **Support** | Contact / help links |
| **Sign Out** | Ends the session |

---

## 10. Database Management (Supabase)

LCCU FinX uses **Supabase** as its backend (PostgreSQL + PostgREST + Supabase Auth).

**Project URL:** `https://juzpizqbhxkncxfpdlxd.supabase.co`

Access the Supabase dashboard at: `https://app.supabase.com`

> Only the designated database administrator should access Supabase directly. Incorrect changes can break the application or expose sensitive data.

### Key Database Tables

| Table | Description |
|---|---|
| `public.users` | Core user profile: user_id (= auth UID), first_name, last_name, gender, title, is_active |
| `public.user_emails` | Email addresses (normalised, allows future multi-email) |
| `public.roles` | Role assignments per user (`student`, `teacher`, `principal`, `guardian`, `teller`, `admin`) |
| `public.schools` | School registry: school_id, school_name |
| `public.classes` | Classes per school |
| `public.student_accounts` | account_number, opening balance, school_id, class_id, guardian links |
| `public.guardian_links` | Student ↔ Guardian relationships with guardian_type (Primary, Secondary, etc.) |
| `public.teachers` | Teacher assignment: user_id, school_id, title |
| `public.principals` | Principal assignment: user_id, school_id, title |
| `public.tellers` | Teller assignment: user_id, credit_union_id (branch) |
| `public.credit_unions` | Credit union branches |
| `public.deposits` | All deposit transactions: school_id, teacher_id, teller_id, amount, discrepancy, status, notes |
| `public.deposit_batches` | Weekly batch summaries: week_start, week_end, expected, deposited, remaining |
| `public.withdrawal_requests` | Student withdrawal requests and their approval status |
| `public.payouts` | Teller-confirmed payouts |

### Supabase Auth

Users are created in **Supabase Auth** (the `auth.users` table) automatically when an admin registers a user through the app. Direct manipulation of `auth.users` is discouraged; always use the app's Register or Update screens.

If you need to:

| Task | Method |
|---|---|
| **Reset a user's password** | Supabase Dashboard → Authentication → Users → find user → Send password reset |
| **Disable a user at auth level** | Supabase Dashboard → Authentication → Users → find user → Disable |
| **Delete a user entirely** | Supabase Dashboard → Authentication → Users → find user → Delete (also remove from `public.users`) |

### Row Level Security (RLS)

All tables have RLS policies. Users can only access data permitted by their role. Do not disable RLS on any table.

### RPC Functions

The app uses Supabase RPC (PostgreSQL functions) for complex queries. Key functions include:

| Function | Used By | Description |
|---|---|---|
| `admin_home_metrics` | Admin | Returns active user count, school count, CU count, student accounts |
| `get_student_snapshot` | Student | Returns balance and transaction history |
| `get_guardian_children` | Guardian | Returns linked children with balances and pending requests |
| `get_teacher_snapshot` | Teacher | Returns funds in hand, class/student options, balance totals |
| `get_principal_home` | Principal | Returns school balance, deposited funds, funds on site |
| `get_teller_schools` | Teller | Returns school list with account balance, pending deposit, disparity |
| `confirm_deposit` | Teller | Records funds received, updates balance, stores discrepancy |
| `get_teller_report_all_schools` | Teller | Report data across all schools for a date range |
| `get_teller_report_single_school` | Teller | Report data for one school for a date range |

To inspect or modify these functions: **Supabase Dashboard → Database → Functions**.

### Adding a New School

1. In the app: currently schools must be added directly in the database.
2. **Supabase Dashboard → Table Editor → schools**
3. Insert a new row: `school_id` (UUID, auto-generated), `school_name`.
4. Add classes for the school in the `classes` table referencing the new `school_id`.
5. The new school will appear in the app's school dropdowns immediately.

### Adding a New Credit Union Branch

1. **Supabase Dashboard → Table Editor → credit_unions**
2. Insert: `branch_id` (UUID), `branch_name`, any other required fields.
3. The branch will appear in the Teller credit union dropdown immediately.

### Adding Guardian Types

1. **Supabase Dashboard → Table Editor → guardian_types**
2. Insert: `id` (UUID), `name` (e.g. "Mother", "Father", "Legal Guardian").
3. New types appear in the Guardian type dropdowns immediately.

---

## 11. Common Administrative Tasks

### New School Year / Student Roll-Over

1. Register new students via the **Register** screen or **CSV Import**.
2. Update returning students' class assignments via the **Update** screen.
3. Verify opening balances are correct.

### Bulk Registration at School Start

1. Prepare a CSV with all students, including:
   - their guardian's email (guardian must be registered first, or include `guardian_first_name` etc. for auto-creation)
   - their school and class names
   - opening balances
2. Import via **Register → Import from CSV**.
3. Review the failure export and fix any errors.
4. Repeat for teachers and principals.

### Staff Change (Teacher Leaves)

1. Open **Update** → search for the teacher.
2. Tap **Deactivate**.
3. Register the replacement teacher.
4. The replaced teacher's transactions remain in the database for audit purposes.

### Auditing a School's Transactions

1. Open **Reports** → select **School Deposits** or **Custom Report**.
2. Set the school, date range, and transaction type.
3. Preview and **Export CSV**.
4. Share the CSV with the credit union's finance team.

### Forgotten Admin Password

1. Contact another system administrator, or
2. Use the Supabase Dashboard → Authentication → Users → find your account → Send password reset email.

---

## 12. Troubleshooting

| Symptom | Likely Cause | Resolution |
|---|---|---|
| User cannot sign in | Account deactivated | Check `is_active` in Update screen; reactivate if appropriate |
| User cannot sign in | Wrong password | Use Supabase Dashboard to send password reset, or use the app's Forgot Password flow |
| Balance appears incorrect | Pending deposit not yet confirmed by teller | Ask the teller to confirm; or inspect `deposits` table in Supabase |
| Dashboard metrics not loading | Supabase RPC error | Check Supabase Dashboard → Logs for function errors |
| CSV import row fails with "Unknown school" | School name mismatch | Verify exact name in `schools` table; update CSV |
| Report shows no data | Date range or filter too narrow | Widen the date range; clear school/class filters |
| Report export not downloading | Browser pop-up blocker | Allow pop-ups for the app domain; on mobile use Share instead |
| App shows "Not authorized" | User token type mismatch | Ensure the Supabase service role key (not anon key) is used for admin operations |

---

## Appendix A — Role Summary

| Role | Capabilities |
|---|---|
| **Student** | View own balance; view transaction history; submit withdrawal requests |
| **Guardian** | View children's balances; approve/decline withdrawal requests; view transaction history |
| **Teacher** | Collect savings; submit deposits; manage approved withdrawal requests; view/export transactions |
| **Principal** | View school totals; reconcile weekly collections; submit deposit batches to teller |
| **Teller** | Confirm deposit batches; record payouts; generate and export audit reports |
| **Admin** | All of the above plus: user management, bulk import, system reports, database oversight |

---

## Appendix B — CSV Import Template

```csv
email,first_name,last_name,role,password,title,gender,mobile,address,school,class,account_number,opening_balance,guardian_user_email,guardian_type,guardian_first_name,guardian_last_name,guardian_mobile,credit_union
jane.doe@example.com,Jane,Doe,student,Pass1234!,,,,,Laborie Primary,Grade 3,ACC001,0.00,mary.doe@example.com,Mother,Mary,Doe,+17581234567,
mary.doe@example.com,Mary,Doe,guardian,Pass1234!,Mrs,,+17581234567,15 Main St,,,,,,,,,,,
mr.smith@example.com,John,Smith,teacher,Pass1234!,Mr,male,,,Laborie Primary,,,,,,,,,
```

**Notes:**
- Leave non-applicable cells blank (do not write "N/A").
- `opening_balance` must be a plain number: `0.00` or `250.00`.
- Guardian auto-creation requires `guardian_first_name`, `guardian_last_name`, and either `guardian_mobile` or the guardian's email not already existing in the system.
- `password` is optional — if blank, a secure random password is generated; the user must then use Forgot Password to set their own.

---

*Last updated: see git history for version.*  
*LCCU FinX is built by the Laborie Co-operative Credit Union Ltd development team.*
