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
11. [Reference Data Setup (First-Time / New Environment)](#11-reference-data-setup-first-time--new-environment)  
12. [Common Administrative Tasks](#12-common-administrative-tasks)  
13. [Troubleshooting](#13-troubleshooting)  

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

On phones the app uses a **hamburger menu** (top-left). The same five sections are accessible via the drawer.

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
| `guardian_type required when linking guardian` | Add a `guardian_type` column value (e.g. "Mother", "Father") for every student row that references an existing guardian |

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
2. **Supabase Dashboard → Table Editor → school**
3. Insert a new row: `school_id` (UUID, auto-generated), `name`, and optionally `Level` (level UUID for class filtering).
4. Add a `school_acc` row to link the school to its credit union branch account.
5. The new school will appear in the app's school dropdowns immediately.

### Adding a New Credit Union Branch

1. **Supabase Dashboard → Table Editor → cu_branch**
2. Insert: `branch_id` (UUID, auto-generated), `branch` (branch name).
3. The branch will appear in the Teller credit union dropdown immediately.

### Adding Guardian Types

1. **Supabase Dashboard → Table Editor → guardian_type**
2. Insert: `type_id` (UUID, auto-generated), `name` (e.g. "Mother", "Father", "Legal Guardian").
3. New types appear in the Guardian type dropdowns immediately.

---

## 11. Reference Data Setup (First-Time / New Environment)

Before creating any users through the app, several lookup tables and reference tables must be populated in the correct order. Without this data in place:

- User creation will fail with `Role "X" not found in public.role`
- Class and school dropdowns will be empty
- Teller credit union dropdown will be empty
- Transaction processing will raise `tx_type "DEPOSIT" not found`

Run each block in **Supabase Dashboard → SQL Editor**.

### Step 1 — Seed Lookup Tables _(system-level, done once)_

```sql
-- 1a. Roles — must match these names exactly (app matches case-insensitively)
INSERT INTO public.role (role_name, description) VALUES
  ('Admin',     'System administrator'),
  ('Teacher',   'School teacher'),
  ('Principal', 'School principal'),
  ('Guardian',  'Student guardian'),
  ('Student',   'Enrolled student'),
  ('Teller',    'Credit union teller')
ON CONFLICT (role_name) DO NOTHING;

-- 1b. Transaction types (RPC functions raise an exception if these are missing)
INSERT INTO public.tx_type (name) VALUES
  ('DEPOSIT'),
  ('WITHDRAWAL')
ON CONFLICT (name) DO NOTHING;

-- 1c. Transaction statuses
INSERT INTO public.tx_stat (name) VALUES
  ('PENDING'),
  ('POSTED'),
  ('APPROVED'),
  ('FLAGGED')
ON CONFLICT (name) DO NOTHING;

-- 1d. Genders
INSERT INTO public.gender (name) VALUES
  ('Male'),
  ('Female')
ON CONFLICT (name) DO NOTHING;

-- 1e. Titles
-- Note: public.title has no unique constraint on "option".
-- Check for existing rows first: SELECT * FROM public.title;
INSERT INTO public.title (option) VALUES
  ('Mr'),
  ('Mrs'),
  ('Ms'),
  ('Dr'),
  ('Rev');

-- 1f. Guardian types
INSERT INTO public.guardian_type (name) VALUES
  ('Mother'),
  ('Father'),
  ('Legal Guardian'),
  ('Grandparent'),
  ('Other')
ON CONFLICT (name) DO NOTHING;
```

### Step 2 — Create Classes _(shared pool)_

Classes are stored in a shared pool and filtered to a school by the school's `Level` column. If a school has no level assigned, all classes appear for that school.

```sql
-- Optional: create levels first if you want per-school class filtering
INSERT INTO public.level (level) VALUES
  ('Primary'),
  ('Secondary')
ON CONFLICT DO NOTHING;

-- Create the class pool
-- Adjust names and levels to match the institution's grade structure.
INSERT INTO public.class (name, level_id) VALUES
  ('Grade 1', (SELECT level_id FROM public.level WHERE level = 'Primary'   LIMIT 1)),
  ('Grade 2', (SELECT level_id FROM public.level WHERE level = 'Primary'   LIMIT 1)),
  ('Grade 3', (SELECT level_id FROM public.level WHERE level = 'Primary'   LIMIT 1)),
  ('Grade 4', (SELECT level_id FROM public.level WHERE level = 'Primary'   LIMIT 1)),
  ('Grade 5', (SELECT level_id FROM public.level WHERE level = 'Primary'   LIMIT 1)),
  ('Grade 6', (SELECT level_id FROM public.level WHERE level = 'Primary'   LIMIT 1)),
  ('Form 1',  (SELECT level_id FROM public.level WHERE level = 'Secondary' LIMIT 1)),
  ('Form 2',  (SELECT level_id FROM public.level WHERE level = 'Secondary' LIMIT 1)),
  ('Form 3',  (SELECT level_id FROM public.level WHERE level = 'Secondary' LIMIT 1)),
  ('Form 4',  (SELECT level_id FROM public.level WHERE level = 'Secondary' LIMIT 1)),
  ('Form 5',  (SELECT level_id FROM public.level WHERE level = 'Secondary' LIMIT 1));
```

### Step 3 — Create Credit Union Branches

Required before any teller account can be created.

```sql
INSERT INTO public.cu_branch (branch) VALUES
  ('Laborie Branch');
-- Repeat for each physical branch.
-- address_id is optional; insert into public.address first if a full address is required.
```

### Step 4 — Create Schools

Required before teacher, principal, or student accounts can be created.

```sql
-- Note: the column is "Level" (capital L) in the schema.
INSERT INTO public.school (name, "Level") VALUES
  (
    'Laborie Primary',
    (SELECT level_id FROM public.level WHERE level = 'Primary' LIMIT 1)
  );
-- Set "Level" to NULL if you are not using level-based class filtering.
-- Repeat for each school.
```

### Step 5 — Create School Accounts

Each school must have an account linked to a credit union branch before balance and deposit tracking will work.

```sql
INSERT INTO public.school_acc (account_number, school_id, branch_id, opening_bal, status)
VALUES (
  'SCH-001',
  (SELECT school_id FROM public.school    WHERE name   = 'Laborie Primary' LIMIT 1),
  (SELECT branch_id FROM public.cu_branch WHERE branch = 'Laborie Branch'  LIMIT 1),
  0.00,
  'ACTIVE'
);
-- Use the actual account number assigned by the credit union.
```

### Step 6 — (Optional) Set School Withdrawal Policies

Controls whether all guardians must approve a withdrawal and the threshold above which requests are routed through the credit union.

```sql
INSERT INTO public.withdrawal_pol
  (school_id, require_all_guardians, cash_threshold, cu_over_threshold)
VALUES (
  (SELECT school_id FROM public.school WHERE name = 'Laborie Primary' LIMIT 1),
  false,   -- true = every linked guardian must approve; false = any one guardian
  100,     -- TTD amount above which requests require credit union processing
  true     -- true = route amounts over threshold through the credit union
);
```

### First-Time Setup Checklist

Before creating the first user through the app, confirm all of the following:

- [ ] `public.role` has all 6 roles: Admin, Teacher, Principal, Guardian, Student, Teller
- [ ] `public.tx_type` has at least `DEPOSIT` and `WITHDRAWAL`
- [ ] `public.tx_stat` has at least `PENDING`, `POSTED`, `APPROVED`, and `FLAGGED`
- [ ] `public.gender` is seeded
- [ ] `public.title` is seeded (no duplicate rows)
- [ ] `public.guardian_type` is seeded
- [ ] At least one `public.cu_branch` row exists (required before teller creation)
- [ ] At least one `public.school` row exists (required before teacher / principal / student creation)
- [ ] At least one `public.class` row exists and is visible for the school's level
- [ ] A `public.school_acc` row links the school to its credit union branch
- [ ] A `public.withdrawal_pol` row exists for each school (if withdrawal approval rules apply)

---

## 12. Common Administrative Tasks

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

## 13. Troubleshooting

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

## Appendix C — Student Data Privacy Guidelines for Administrators

As an LCCU FinX administrator you are a **data controller** for student account information. The following obligations apply:

### Data Minimisation
- Collect only the fields the system requires. Fields not listed in the CSV template (e.g. date of birth, national ID, biometrics) must **not** be added to imports or the database without a formal review.
- Do not store sensitive PII in free-text notes fields.

### Parental / Guardian Consent
- Before creating a student account, confirm with the school administration that parental or guardian consent for the savings programme has been obtained and documented.
- When registering student accounts individually, verify the linked guardian is the legal parent or guardian of that student.

### Principle of Least Privilege
- Create accounts with the minimum role required. Do not assign admin or teller roles to school staff unless explicitly needed.
- Disable accounts promptly when staff leave or students graduate.

### Bulk Import Privacy Checklist
Before running a CSV import containing student data:
- [ ] Confirm the source of the data is an authorised school list
- [ ] Confirm parental consent documentation is held by the school
- [ ] Verify the CSV does not contain columns beyond those in the template (no DOB, national ID, etc.)
- [ ] Delete the CSV file from your local machine after a successful import
- [ ] Do not email or share CSV files containing student data via unencrypted channels

### Data Subject Requests
When a parent, guardian, or student submits a data request (access, correction, deletion):
1. Verify the requestor's identity and their relationship to the student.
2. For access requests: export the relevant account data and transaction history from Reports.
3. For correction requests: update via the Update screen.
4. For deletion requests: deactivate the account and escalate to the Supabase database administrator for full data removal, subject to the 7-year financial record retention requirement.
5. Log all data subject requests and responses for audit purposes.

### Incident Reporting
If you suspect a data breach (e.g. CSV file shared with wrong recipient, unauthorised access to admin account):
1. Change affected credentials immediately.
2. Notify the LCCU Privacy Officer (privacy@lccufinx.com) within 24 hours.
3. Document the incident: what data, how many individuals, when discovered, steps taken.

---

*Last updated: May 7, 2026*  
*LCCU FinX is built by the Laborie Co-operative Credit Union Ltd development team.*
