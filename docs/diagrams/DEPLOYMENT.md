# Deployment Diagram — LCCU FinX

```mermaid
graph TB
    subgraph CLIENTS["Client Devices"]
        ANDROID["Android Device\n─────────────\nFlutter App (APK/AAB)\nDart runtime\nFlutter Engine"]
        IOS["iOS Device\n─────────────\nFlutter App (IPA)\nDart runtime\nFlutter Engine"]
        WEB["Web Browser\n─────────────\nFlutter Web (WASM/JS)\nCanvasKit renderer\nDart compiled to WASM"]
    end

    subgraph STORES["Distribution"]
        PLAYSTORE["Google Play Store\n(Android APK/AAB)"]
        APPSTORE["Apple App Store\n(iOS IPA)"]
        WEBHOST["Web Hosting\n(Static HTML/JS/WASM)"]
    end

    subgraph SUPABASE_CLOUD["Supabase Cloud (Hosted)"]
        subgraph SUPABASE_AUTH_SVC["Auth Service"]
            GOTRUE["GoTrue Auth Server\n─────────────\nPKCE Email/Password\nJWT generation\nOTP Email Reset"]
        end

        subgraph SUPABASE_API["API Gateway"]
            POSTGREST["PostgREST\n─────────────\nAuto-generated REST API\nRPC endpoint exposure\nJWT validation"]
        end

        subgraph SUPABASE_EDGE["Edge Functions (Deno)"]
            USERADMIN_FN["user-admin\n─────────────\nDeno runtime\nservice_role key\nUser CRUD operations"]
        end

        subgraph SUPABASE_DB["Database Cluster"]
            POSTGRES_DB["PostgreSQL\n─────────────\nCore tables\nRPC stored procedures\nRow Level Security\nTriggers & constraints"]
            PGBOUNCER["PgBouncer\n(connection pooling)"]
        end

        subgraph SUPABASE_STORAGE["Realtime & Infra"]
            REALTIME["Realtime Server\n(WebSocket)"]
        end
    end

    subgraph CI_CD["CI/CD (Optional)"]
        GITHUB["GitHub Repository\n─────────────\nSource code\nGitHub Actions"]
        FASTLANE["Fastlane / Shorebird\n(Mobile delivery)"]
    end

    %% Distribution links
    PLAYSTORE --> ANDROID
    APPSTORE --> IOS
    WEBHOST --> WEB

    %% Client to Supabase
    ANDROID -- "HTTPS REST\n(PostgREST)" --> POSTGREST
    ANDROID -- "HTTPS REST\n(Auth)" --> GOTRUE
    ANDROID -- "HTTPS REST\n(Edge Fn)" --> USERADMIN_FN
    IOS -- "HTTPS REST\n(PostgREST)" --> POSTGREST
    IOS -- "HTTPS REST\n(Auth)" --> GOTRUE
    IOS -- "HTTPS REST\n(Edge Fn)" --> USERADMIN_FN
    WEB -- "HTTPS REST\n(PostgREST)" --> POSTGREST
    WEB -- "HTTPS REST\n(Auth)" --> GOTRUE
    WEB -- "HTTPS REST\n(Edge Fn)" --> USERADMIN_FN

    %% Supabase internal
    POSTGREST -- "SQL" --> PGBOUNCER
    PGBOUNCER --> POSTGRES_DB
    USERADMIN_FN -- "Admin SQL" --> POSTGRES_DB
    USERADMIN_FN -- "Admin API" --> GOTRUE
    GOTRUE -- "JWT validation" --> POSTGREST

    %% CI/CD
    GITHUB -- "build & sign" --> FASTLANE
    FASTLANE -- "upload" --> PLAYSTORE
    FASTLANE -- "upload" --> APPSTORE
    GITHUB -- "deploy static" --> WEBHOST

    %% Styling
    classDef device fill:#e3f2fd,stroke:#1565c0
    classDef store fill:#e8f5e9,stroke:#2e7d32
    classDef supabase fill:#fff3e0,stroke:#e65100
    classDef cicd fill:#f3e5f5,stroke:#6a1b9a

    class ANDROID,IOS,WEB device
    class PLAYSTORE,APPSTORE,WEBHOST store
    class GOTRUE,POSTGREST,USERADMIN_FN,POSTGRES_DB,PGBOUNCER,REALTIME supabase
    class GITHUB,FASTLANE cicd
```

## Deployment Environments

| Environment | Host | URL |
|---|---|---|
| **Production DB** | Supabase Cloud | `https://juzpizqbhxkncxfpdlxd.supabase.co` |
| **Edge Functions** | Supabase Deno (same project) | `/functions/v1/user-admin` |
| **Android App** | Google Play Store / Direct APK | — |
| **iOS App** | Apple App Store | — |
| **Web App** | Static hosting (e.g., Vercel / Netlify / Firebase Hosting) | — |

## Network Security

| Concern | Mitigation |
|---|---|
| **Transport** | All communication over HTTPS/TLS |
| **Auth** | PKCE flow; JWTs expire; refresh tokens rotated |
| **Privilege escalation** | `service_role` key only in Edge Functions (server-side), never in client |
| **Data isolation** | PostgreSQL Row Level Security enforces per-role data access |
| **Admin operations** | Only executed via authenticated Edge Function, never direct DB from client |

## Infrastructure Notes

- **No dedicated app server** — Supabase acts as the full backend (BaaS)
- **Edge Functions** run on Deno at the Supabase edge (CDN-adjacent)
- **Database** is managed PostgreSQL with automatic backups on Supabase's infrastructure
- **Realtime** WebSocket connections available but not currently used (polling via RPC instead)
