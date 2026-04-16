---
generated: 2026-04-16
focus: integrations
---

# External Integrations

## APIs & External Services

**Backend-as-a-Service:**
- **Supabase** — The sole external service. Provides the entire backend stack:
  - SDK: `supabase_flutter ^2.8.4` (resolved `2.12.2`)
  - Project URL: `https://chhodscgwzpixtrvbywm.supabase.co` (defined in `primeaudit/lib/core/supabase_config.dart`)
  - Auth: anon key stored as a compile-time constant (`SupabaseConfig.anonKey`) — this is the public-facing JWT-based key, secured by Row Level Security policies
  - Initialized once at app startup in `primeaudit/lib/main.dart` via `Supabase.initialize()`
  - All service classes access the client via `Supabase.instance.client`

## Data Storage

**Primary Database:**
- **Supabase PostgreSQL** (managed Postgres)
  - Connection: via PostgREST REST API (no direct TCP connection)
  - Client: `postgrest` `2.6.0` Dart client, wrapped by `supabase_flutter`
  - All queries in service classes (`primeaudit/lib/services/`) use the `_client.from(table).select/insert/update/delete` fluent API

**Database Schema (tables accessed by the app):**

| Table | Purpose | Key Service File |
|-------|---------|-----------------|
| `profiles` | User accounts, roles, company assignment, active flag | `primeaudit/lib/services/auth_service.dart`, `primeaudit/lib/services/user_service.dart` |
| `companies` | Organizations; `requires_perimeter` flag | `primeaudit/lib/services/company_service.dart` |
| `perimeters` | Hierarchical locations within a company | `primeaudit/lib/services/perimeter_service.dart` |
| `audit_types` | Categories of audits (global or per-company) | `primeaudit/lib/services/audit_template_service.dart` |
| `audit_templates` | Reusable audit forms (global or per-company) | `primeaudit/lib/services/audit_template_service.dart` |
| `template_sections` | Sections within a template | `primeaudit/lib/services/audit_template_service.dart` |
| `template_items` | Individual questions within a template | `primeaudit/lib/services/audit_template_service.dart` |
| `audits` | Audit instances with status lifecycle | `primeaudit/lib/services/audit_service.dart` |
| `audit_answers` | Auditor responses to template items | `primeaudit/lib/services/audit_answer_service.dart` |

**Local Storage:**
- **SharedPreferences** (`shared_preferences ^2.3.3`, resolved `2.5.5`)
  - Used for: theme preference (`settings_theme`), notification preferences, audit defaults, and active company context (`ctx_company_id`, `ctx_company_name`) for superuser/dev roles
  - Implementation: `primeaudit/lib/services/settings_service.dart`, `primeaudit/lib/services/company_context_service.dart`

**File Storage:**
- Supabase Storage client (`storage_client 2.5.1`) is included as a transitive dependency but no app code accesses it directly. No file upload/download features exist.

**Caching:**
- None — all data fetched fresh from Supabase on each screen load.

## Authentication & Identity

**Auth Provider:**
- **Supabase Auth** (GoTrue service, `gotrue 2.19.0`)
  - Mechanism: Email + password (`signInWithPassword`)
  - Registration: `signUp` with `data: {'full_name': name}` metadata
  - Session management: JWT tokens managed automatically by the SDK; session persisted across restarts
  - Auth state stream: `Supabase.instance.client.auth.onAuthStateChange` drives `_AuthGate` in `primeaudit/lib/main.dart`
  - Password change: `_client.auth.updateUser(UserAttributes(password: newPassword))` in `primeaudit/lib/services/auth_service.dart`
  - Custom check: after sign-in, `profiles.active` is verified; inactive users are immediately signed out

**Authorization:**
- **Role-Based Access Control (RBAC)** with 5 roles: `superuser`, `dev`, `adm`, `auditor`, `anonymous`
  - Roles defined in `primeaudit/lib/core/app_roles.dart`
  - Enforced at two layers:
    1. **Flutter UI**: role checked via `AppRole.canAccessAdmin()`, `AppRole.isSuperOrDev()` to show/hide screens and features
    2. **Database RLS**: PostgreSQL Row Level Security policies on every table, enforced via `get_my_role()` and `get_my_company_id()` Postgres functions (defined in `primeaudit/supabase/migrations/20260406_create_audits.sql`)

## Database Events & Automation

**PostgreSQL Triggers:**
- `trg_set_completed_at` on `audits` — automatically sets `completed_at` when status transitions to `concluida` (defined in `primeaudit/supabase/migrations/20260406_create_audits.sql`)
- `mark_overdue_audits()` function — marks `em_andamento` audits past their deadline as `atrasada`; intended for scheduling via **pg_cron** (commented-out `cron.schedule` call in migration file; not yet active)

**Realtime:**
- `realtime_client 2.7.1` is included as a transitive dependency but no app code sets up Supabase Realtime channel subscriptions. The app uses one-time fetches only.

## Monitoring & Observability

**Error Tracking:**
- None — no Sentry, Crashlytics, or similar SDK integrated.

**Logging:**
- Standard Dart `print()` / `debugPrint()` only; no structured logging library.

## CI/CD & Deployment

**Hosting:**
- Not configured — no deployment config files present in the repository (no `firebase.json`, no `fastlane/`, no GitHub Actions workflows).

**CI Pipeline:**
- None detected.

## Webhooks & Callbacks

**Incoming:**
- None.

**Outgoing:**
- None. The `app_links` package (deep link handler) is present as a transitive dependency of `supabase_flutter` to support OAuth redirect URIs, but no OAuth providers beyond email/password are configured.

## Edge Functions

- `functions_client 2.5.0` is included as a transitive Supabase dependency. No Edge Function calls exist in the app code (`primeaudit/lib/services/`).

---

*Integration audit: 2026-04-16*
