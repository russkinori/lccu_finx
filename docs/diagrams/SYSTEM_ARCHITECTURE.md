# System Architecture Diagram — LCCU FinX

```mermaid
graph TB
    subgraph CLIENT["Client Layer — Flutter App"]
        direction TB
        subgraph SCREENS["UI Screens (per role)"]
            S1[Admin Screens]
            S2[Teacher Screens]
            S3[Principal Screens]
            S4[Teller Screens]
            S5[Student Screens]
            S6[Guardian Screens]
        end

        subgraph STATE["State Management"]
            AUTH[AuthScope\nAuthVM]
            SCOPES[Role Scopes\nTeacherScope / StudentScope\nPrincipalScope / GuardianScope\nTellerScope / AdminScope]
        end

        subgraph REPOS["Repository Layer"]
            ADMINREPO[AdminRepo]
            TEACHERREPO[TeacherRepo]
            PRINREPO[PrincipalRepo]
            TELLERREPO[TellerRepo]
            STUDENTREPO[StudentRepo]
            GUARDREPO[GuardianRepo]
            COMMONREPO[CommonRepo]
        end

        subgraph CLIENTS["API Clients"]
            RPCCLIENT[RpcClient\nRPC wrapper]
            ADMINCLIENT[AdminClient\nEdge Fn invoker]
        end

        subgraph NAVIGATION["Navigation"]
            AUTHGATE[AuthGate]
            APPROUTER[AppRouter\nAdmin routes]
            TELLERROUTER[TellerRouter\nTeller routes]
            DASHNAV[DashboardShell\nMobile drawer]
            WEBNAV[WebShell\nSidebar ≥900px]
        end
    end

    subgraph SUPABASE["Backend — Supabase (BaaS)"]
        direction TB
        subgraph SAUTH["Supabase Auth"]
            PKCE[PKCE Flow\nEmail + Password]
            SESSIONMGR[Session Manager\nJWT tokens]
        end

        subgraph EDGEFN["Edge Functions (Deno)"]
            USERADMIN[user-admin\ncreate / update / delete\ndeactivate / reset password]
        end

        subgraph POSTGRES["PostgreSQL Database"]
            direction LR
            subgraph TABLES["Core Tables"]
                T1[app_user]
                T2[user_role]
                T3[teacher / principal\nteller / student / guardian]
                T4[student_account]
                T5[transaction]
                T6[withdrawal_request]
                T7[deposit_batch]
                T8[cu_dep_event]
                T9[cu_payout_event]
                T10[school / class\ncredit_union]
            end

            subgraph RPCFNS["RPC Functions (PostgreSQL)"]
                R1[f_me / f_me_role]
                R2[student_home\nstudent_transaction_history\nrequest_withdrawal]
                R3[teacher_home_metrics\nteacher_transaction_history\nteacher_withdrawal_list]
                R4[principal_home_summary\nsubmit_deposit_batch]
                R5[teller_home_rows\nconfirm_deposit\nteller_deposit_events_list]
                R6[guardian_children_list\nguardian_decide_withdrawal]
            end

            RLS[Row Level Security\nPolicies per role]
        end
    end

    %% Connections
    SCREENS --> STATE
    STATE --> REPOS
    REPOS --> RPCCLIENT
    REPOS --> ADMINCLIENT
    RPCCLIENT -->|HTTPS / REST| RPCFNS
    ADMINCLIENT -->|HTTPS / REST| USERADMIN
    USERADMIN -->|Admin API| SAUTH
    USERADMIN -->|SQL| TABLES
    RPCFNS --> TABLES
    TABLES --> RLS
    AUTHGATE -->|onAuthStateChange| PKCE
    PKCE --> SESSIONMGR
    SESSIONMGR -->|JWT| RPCCLIENT

    subgraph EXTERNAL["External Packages"]
        EP1[share_plus\nCSV export]
        EP2[file_picker\nCSV import]
        EP3[url_launcher\nPolicy links]
    end

    SCREENS --> EXTERNAL
```

## Component Responsibilities

| Component | Responsibility |
|---|---|
| **AuthScope / AuthVM** | Listens to Supabase auth state changes; resolves user role; provides auth context to entire widget tree |
| **Role Scopes** | `InheritedNotifier` wrappers that provide role-specific `ChangeNotifier` ViewModels to the widget subtree |
| **Repository Layer** | All Supabase data access; maps raw JSON to typed Dart models; no UI logic |
| **RpcClient** | Thin wrapper around `supabase.rpc()` with typed list/single helpers |
| **AdminClient** | Invokes the `user-admin` Edge Function for privileged user management |
| **AppRouter / TellerRouter** | `Navigator` stacks with named routes for admin and teller flows |
| **DashboardShell / WebShell** | Responsive layout: hamburger drawer (mobile) vs. sidebar (web ≥ 900 px) |
| **Supabase Auth (PKCE)** | Passwordless-safe OAuth-style flow; email/password login; OTP password reset |
| **Edge Function: user-admin** | Server-side privileged admin operations requiring `service_role` key (never exposed to client) |
| **RPC Functions** | PostgreSQL stored procedures enforcing business logic and row-level security |
| **Row Level Security** | Supabase RLS policies ensure users can only access data belonging to their role/school/class |
