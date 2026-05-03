# Sequence Diagrams — LCCU FinX

## 1. Authentication & Role Resolution

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant AuthGate
    participant Supabase as Supabase Auth
    participant DB as Supabase DB (RPC)

    User->>App: Launch app
    App->>App: SplashScreen: clear local sign-in state
    App->>Supabase: Check existing session
    Supabase-->>App: No session → show LoginPage

    User->>App: Enter email + password
    App->>Supabase: signInWithPassword(email, password)
    Supabase-->>App: AuthSession (access token)

    App->>AuthGate: onAuthStateChange event
    AuthGate->>DB: RPC f_me_role(userId)
    DB-->>AuthGate: [AppRole]
    AuthGate->>App: Route to role-specific home screen

    Note over App,DB: Timeout = 8 seconds; on timeout → LoginPage
```

---

## 2. Teacher Records a Student Deposit

```mermaid
sequenceDiagram
    actor Teacher
    participant UI as Teacher UI
    participant VM as TeacherVM
    participant Repo as TeacherRepo
    participant DB as Supabase DB

    Teacher->>UI: Select class → select student → enter amount
    Teacher->>UI: Tap "Record Deposit"
    UI->>VM: createDeposit(studentId, amount)
    VM->>Repo: createDeposit(studentId, amount)
    Repo->>DB: RPC post_deposit(studentId, amount, teacherId)
    DB-->>Repo: transaction_id
    DB->>DB: UPDATE student_account balance
    Repo-->>VM: success
    VM->>VM: refresh teacher_home_metrics()
    VM-->>UI: Update funds-in-hand balance
    UI-->>Teacher: Show success + updated balance
```

---

## 3. Student Requests a Withdrawal

```mermaid
sequenceDiagram
    actor Student
    participant UI as Student UI
    participant VM as StudentVM
    participant Repo as StudentRepo
    participant DB as Supabase DB

    Student->>UI: Tap "Request Withdrawal"
    Student->>UI: Enter amount + reason
    Student->>UI: Confirm
    UI->>VM: requestWithdrawal(accountId, studentId, amount, reason)
    VM->>Repo: requestWithdrawal(...)
    Repo->>DB: RPC request_withdrawal(accountId, studentId, amount, note)
    DB-->>Repo: withdrawal_request_id (status=Pending)
    Repo-->>VM: success
    VM->>VM: refresh student_home()
    VM-->>UI: Show "Pending" withdrawal status
    UI-->>Student: Withdrawal request submitted
```

---

## 4. Guardian Approves/Declines Withdrawal

```mermaid
sequenceDiagram
    actor Guardian
    participant UI as Guardian UI
    participant VM as GuardianVM
    participant Repo as GuardianRepo
    participant DB as Supabase DB

    Guardian->>UI: View child's pending withdrawal
    Guardian->>UI: Tap Approve / Decline
    UI->>VM: decideWithdrawal(requestId, approve)
    VM->>Repo: decideWithdrawal(requestId, approved)
    Repo->>DB: RPC guardian_decide_withdrawal(requestId, approved)
    DB-->>Repo: updated status
    Repo-->>VM: success
    VM->>VM: refresh guardian_children_list()
    VM-->>UI: Updated withdrawal status
    UI-->>Guardian: Show Approved / Declined status
```

---

## 5. Principal Submits Deposit Batch to Teller

```mermaid
sequenceDiagram
    actor Principal
    participant UI as Principal UI
    participant VM as PrincipalVM
    participant Repo as PrincipalRepo
    participant DB as Supabase DB

    Principal->>UI: Open Reconcile Screen
    UI->>VM: loadDepositSnapshot(schoolId, weekStart)
    VM->>Repo: getTeacherCollections(schoolId, weekStart)
    Repo->>DB: RPC principal_home_summary(schoolId, weekStart)
    DB-->>Repo: TeacherCollectionItem[]
    Repo-->>VM: collections
    VM-->>UI: Display batch totals per teacher

    Principal->>UI: Review totals → tap "Submit to Teller"
    UI->>VM: submitDepositBatch(schoolId, weekStart)
    VM->>Repo: submitDepositBatch(schoolId, weekStart)
    Repo->>DB: RPC submit_deposit_batch(schoolId, weekStart, totalAmount)
    DB-->>Repo: batch_id (status=Pending)
    Repo-->>VM: success
    VM-->>UI: Batch submitted confirmation
    UI-->>Principal: "Batch submitted — awaiting teller confirmation"
```

---

## 6. Teller Confirms Deposit from Principal Batch

```mermaid
sequenceDiagram
    actor Teller
    participant UI as Teller UI
    participant VM as TellerVM
    participant Repo as TellerRepo
    participant DB as Supabase DB

    Teller->>UI: Open Teller Home → select school
    UI->>VM: loadSchoolDeposit(schoolId)
    VM->>Repo: getSchoolDepositSnapshot(schoolId)
    Repo->>DB: RPC teller_school_deposit_snapshot(schoolId)
    DB-->>Repo: DepositBatchRow[]
    Repo-->>VM: batches with expectedAmount
    VM-->>UI: Show expected deposit amount

    Teller->>UI: Select teacher → enter actual cash amount
    Teller->>UI: Note any discrepancy → tap "Confirm Deposit"
    UI->>VM: confirmDeposit(schoolId, teacherId, amount, discrepancy, batchIds)
    VM->>Repo: confirmDeposit(...)
    Repo->>DB: RPC confirm_deposit(...) → INSERT cu_dep_event
    DB-->>Repo: deposit_event_id
    Repo-->>VM: success
    VM->>VM: refresh teller_home_rows()
    VM-->>UI: Updated school balance
    UI-->>Teller: Deposit confirmed
```

---

## 7. Admin Creates a New User

```mermaid
sequenceDiagram
    actor Admin
    participant UI as Admin UI
    participant VM as AdminVM
    participant Repo as AdminRepo
    participant Edge as Supabase Edge Fn (user-admin)
    participant Auth as Supabase Auth
    participant DB as Supabase DB

    Admin->>UI: Fill registration form (role, school, class, etc.)
    Admin->>UI: Tap "Register"
    UI->>VM: createUser(CreateUserRequest)
    VM->>Repo: createUser(request)
    Repo->>Edge: POST /functions/v1/user-admin {action:create_user, ...payload}
    Edge->>Auth: admin.createUser(email, password)
    Auth-->>Edge: auth_user_id
    Edge->>DB: INSERT app_user, user_role, teacher/student/etc row
    DB-->>Edge: userId
    Edge-->>Repo: {success, userId}
    Repo-->>VM: AdminUser
    VM-->>UI: User created confirmation
    UI-->>Admin: Show new user details
```
