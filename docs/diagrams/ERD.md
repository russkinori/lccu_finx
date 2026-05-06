# Entity Relationship Diagram — LCCU FinX

```mermaid
erDiagram
    CREDIT_UNION {
        uuid id PK
        string name
        string address
    }

    SCHOOL {
        uuid id PK
        uuid credit_union_id FK
        string name
        string address
    }

    CLASS {
        uuid id PK
        uuid school_id FK
        string name
    }

    APP_USER {
        uuid id PK
        uuid auth_user_id FK
        string first_name
        string last_name
        string email
        string mobile
        string gender
        string title
        string address
        bool is_active
        timestamp created_at
        timestamp last_sign_in_at
    }

    USER_ROLE {
        uuid id PK
        uuid user_id FK
        string role
    }

    TEACHER {
        uuid id PK
        uuid user_id FK
        uuid school_id FK
    }

    PRINCIPAL {
        uuid id PK
        uuid user_id FK
        uuid school_id FK
    }

    TELLER {
        uuid id PK
        uuid user_id FK
        uuid credit_union_id FK
    }

    STUDENT {
        uuid id PK
        uuid user_id FK
        uuid school_id FK
        uuid class_id FK
    }

    GUARDIAN {
        uuid id PK
        uuid user_id FK
        string guardian_type_id
    }

    GUARDIAN_STUDENT_LINK {
        uuid id PK
        uuid guardian_id FK
        uuid student_id FK
        bool is_primary
    }

    STUDENT_ACCOUNT {
        uuid id PK
        uuid student_id FK
        string acc_number
        decimal balance
        decimal opening_balance
        timestamp created_at
    }

    TRANSACTION {
        uuid id PK
        uuid account_id FK
        uuid teacher_id FK
        string tx_type
        decimal amount
        timestamp created_at
        string note
    }

    WITHDRAWAL_REQUEST {
        uuid id PK
        uuid account_id FK
        uuid student_id FK
        decimal amount
        string status
        string note
        timestamp requested_at
        timestamp resolved_at
    }

    DEPOSIT_BATCH {
        uuid id PK
        uuid school_id FK
        uuid principal_id FK
        date week_start
        date week_end
        decimal expected_amount
        decimal deposited_amount
        string status
        timestamp submitted_at
    }

    DEPOSIT_BATCH_LINE {
        uuid id PK
        uuid batch_id FK
        uuid teacher_id FK
        decimal amount
    }

    CU_DEPOSIT_EVENT {
        uuid id PK
        uuid school_id FK
        uuid teacher_id FK
        uuid teller_id FK
        decimal amount
        decimal discrepancy
        string status
        string notes
        timestamp posted_at
    }

    CU_PAYOUT_EVENT {
        uuid id PK
        uuid school_id FK
        uuid teller_id FK
        uuid request_id FK
        decimal amount
        string note
        timestamp posted_at
    }

    CREDIT_UNION ||--o{ SCHOOL : "has"
    CREDIT_UNION ||--o{ TELLER : "employs"
    SCHOOL ||--o{ CLASS : "has"
    SCHOOL ||--o{ TEACHER : "employs"
    SCHOOL ||--o{ PRINCIPAL : "has"
    SCHOOL ||--o{ STUDENT : "enrolls"
    CLASS ||--o{ STUDENT : "contains"
    APP_USER ||--|| USER_ROLE : "has"
    APP_USER ||--o| TEACHER : "is"
    APP_USER ||--o| PRINCIPAL : "is"
    APP_USER ||--o| TELLER : "is"
    APP_USER ||--o| STUDENT : "is"
    APP_USER ||--o| GUARDIAN : "is"
    STUDENT ||--|| STUDENT_ACCOUNT : "owns"
    STUDENT ||--o{ GUARDIAN_STUDENT_LINK : "linked via"
    GUARDIAN ||--o{ GUARDIAN_STUDENT_LINK : "linked via"
    STUDENT_ACCOUNT ||--o{ TRANSACTION : "records"
    STUDENT_ACCOUNT ||--o{ WITHDRAWAL_REQUEST : "has"
    TEACHER ||--o{ TRANSACTION : "creates"
    SCHOOL ||--o{ DEPOSIT_BATCH : "has"
    PRINCIPAL ||--o{ DEPOSIT_BATCH : "submits"
    DEPOSIT_BATCH ||--o{ DEPOSIT_BATCH_LINE : "contains"
    TEACHER ||--o{ DEPOSIT_BATCH_LINE : "included in"
    SCHOOL ||--o{ CU_DEPOSIT_EVENT : "triggers"
    TELLER ||--o{ CU_DEPOSIT_EVENT : "posts"
    SCHOOL ||--o{ CU_PAYOUT_EVENT : "triggers"
    TELLER ||--o{ CU_PAYOUT_EVENT : "posts"
    WITHDRAWAL_REQUEST ||--o| CU_PAYOUT_EVENT : "fulfilled by"
```
