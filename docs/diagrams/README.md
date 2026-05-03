# LCCU FinX — Architecture & Design Diagrams

This folder contains all architectural diagrams for the **LCCU FinX** Scholthrift school banking application.

## Diagrams Index

| Diagram | File | Description |
|---|---|---|
| **Entity Relationship Diagram** | [ERD.md](ERD.md) | All database entities, their fields, and relationships |
| **User Flow** | [USER_FLOW.md](USER_FLOW.md) | Authentication flow and per-role navigation paths through the app |
| **Sequence Diagrams** | [SEQUENCE_DIAGRAMS.md](SEQUENCE_DIAGRAMS.md) | Step-by-step message flows for all key operations |
| **System Architecture** | [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md) | Client/backend component structure and responsibilities |
| **Use Case Diagram** | [USE_CASE.md](USE_CASE.md) | All actors and their use cases with include/extend relationships |
| **Data Flow Diagram** | [DATA_FLOW.md](DATA_FLOW.md) | Context (L0), process (L1), and cash-flow (L2) data flows |
| **Deployment Diagram** | [DEPLOYMENT.md](DEPLOYMENT.md) | Physical infrastructure, distribution, and network security |

---

## Quick Overview

### App Purpose
LCCU FinX is a multi-role mobile and web app for the **Laborie Co-operative Credit Union Scholthrift programme** — a school banking system where students make weekly cash deposits collected by teachers, batched by principals, and confirmed by tellers into the credit union.

### Roles
| Role | Primary Responsibility |
|---|---|
| **Admin** | User management, reporting |
| **Teacher** | Record student deposits, post withdrawals |
| **Principal** | Review and submit weekly deposit batches |
| **Teller** | Confirm physical deposits at the credit union |
| **Student** | View balance, request withdrawals |
| **Guardian** | Approve/decline child withdrawal requests |

### Technology Stack
- **Frontend:** Flutter (Android, iOS, Web)
- **Backend:** Supabase (PostgreSQL, PostgREST, Auth, Edge Functions)
- **State Management:** Custom `ChangeNotifier` + `InheritedNotifier`
- **Auth:** Supabase PKCE email/password flow

### Cash Flow Summary
```
Student cash → Teacher (weekly collection)
              → Principal (school batch reconciliation)
                → Teller (physical deposit to CU)
                  → Credit Union ledger
```
