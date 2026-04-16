---
generated: 2026-04-16
focus: architecture
---

# Architecture

## Pattern Overview

**Overall:** Layered Service Architecture (informal Clean Architecture without strict separation)

The app follows a three-layer pattern — screens (presentation), services (application/data), and models (domain) — but does not enforce strict dependency inversion. Screens instantiate services directly via local variables (e.g., `final _auditService = AuditService()`), which means there is no dependency injection container.

**Key Characteristics:**
- Screens own local service instances; no shared DI / provider
- All remote data access goes through dedicated service classes that wrap `Supabase.instance.client`
- Models are plain Dart classes with `fromMap` factory constructors (no code generation)
- State management is local `setState`; no BLoC, Riverpod, or Provider
- RBAC is enforced in the UI layer via `AppRole` helpers; backend enforcement relies on Supabase RLS policies

## Layers

**Presentation (screens):**
- Purpose: UI rendering, local ephemeral state, user interaction
- Location: `primeaudit/lib/screens/`
- Contains: `StatefulWidget` screens, private sub-widgets (underscore-prefixed classes defined in the same file)
- Depends on: services, models, `core/`
- Used by: navigation calls from other screens

**Application / Data (services):**
- Purpose: Supabase CRUD operations, business logic helpers (conformity calculation, auth checks)
- Location: `primeaudit/lib/services/`
- Contains: plain Dart classes, each wrapping one domain concept; no base class
- Depends on: `supabase_flutter`, models
- Used by: screens

**Domain (models):**
- Purpose: Typed representations of database rows; value parsing; domain enums
- Location: `primeaudit/lib/models/`
- Contains: immutable data classes, `fromMap` factories, domain enums with display helpers
- Depends on: nothing (pure Dart + Flutter `material.dart` for `Color`/`IconData`)
- Used by: services, screens

**Core (shared infrastructure):**
- Purpose: App-wide constants, theming, role definitions
- Location: `primeaudit/lib/core/`
- Contains: `AppColors`, `AppTheme`, `AppRole`, `SupabaseConfig`
- Depends on: nothing except Flutter
- Used by: all other layers

## Data Flow

**Authentication flow:**

1. `main.dart` initializes `Supabase` with credentials from `SupabaseConfig`
2. `_AuthGate` (in `main.dart`) subscribes to `Supabase.instance.client.auth.onAuthStateChange` stream
3. On session present → `HomeScreen`; on null → `LoginScreen`
4. `HomeScreen.initState` calls `UserService.getById` then initializes `CompanyContextService.instance`
5. `AuthService.signIn` performs login then validates `profiles.active == true`; deactivated users are signed out immediately

**Audit execution flow:**

1. `AuditsScreen` loads audits via `AuditService.getAudits(companyId: ...)` where `companyId` comes from `CompanyContextService.instance.activeCompanyId`
2. User opens "Nova auditoria" → `_NewAuditSheet` modal (4-step wizard): type → template → perimeter → deadline
3. `AuditService.createAudit` inserts a row with `status: 'em_andamento'`; returns populated `Audit` via SQL join
4. Navigation pushes `AuditExecutionScreen(audit: audit)`
5. `AuditExecutionScreen` loads sections + items + existing answers in parallel via `Future.wait`
6. Each answer is auto-saved on change via `AuditAnswerService.upsertAnswer` (fire-and-forget, silent failure)
7. On finalize: `AuditAnswerService.calculateConformity` computes weighted score; `AuditService.finalizeAudit` sets `status: 'concluida'` and stores `conformity_percent`

**State Management:**

All state is managed with Flutter's built-in `setState` inside `StatefulWidget` classes. There is no global state management library. Cross-screen state is passed as constructor arguments or via `CompanyContextService` (a manually-implemented in-memory singleton with `SharedPreferences` persistence).

The only global reactive state is `appThemeMode` — a `ValueNotifier<ThemeMode>` declared at the top of `main.dart` and consumed via `ValueListenableBuilder`.

## Key Abstractions

**AppRole (`primeaudit/lib/core/app_roles.dart`):**
- Purpose: Centralized role constants and permission checks
- Roles: `superuser`, `dev`, `adm`, `auditor`, `anonymous`
- Key methods: `canAccessAdmin(role)`, `isSuperOrDev(role)`, `canAccessDev(role)`
- Used in: `HomeScreen` (drawer item visibility), `CompanyContextService` (company switching), `UsersTab` (role assignment)

**CompanyContextService (`primeaudit/lib/services/company_context_service.dart`):**
- Purpose: Singleton tracking the active company context for data-scoped queries
- `superuser`/`dev` roles may switch companies; other roles are locked to their `profile.company_id`
- Persisted via `SharedPreferences` keys `ctx_company_id` / `ctx_company_name`
- Consumed by: `AuditsScreen`, `_NewAuditSheet`, any screen needing scoped company queries

**AuditTemplate hierarchy:**
- `AuditType` → `AuditTemplate` → `TemplateSection` → `TemplateItem`
- Managed by `AuditTemplateService` (`primeaudit/lib/services/audit_template_service.dart`)
- Templates can be global (`company_id IS NULL`) or company-specific; queries always include both via `.or('company_id.is.null,company_id.eq.$companyId')`

**AppTheme (`primeaudit/lib/core/app_theme.dart`):**
- Purpose: Typed color token object resolved at build time from `BuildContext`
- Usage: `final t = AppTheme.of(context);` then `t.background`, `t.surface`, `t.textPrimary`, etc.
- Does not replace Flutter's `ThemeData`; supplements it with semantic tokens

## Entry Points

**App entry:**
- Location: `primeaudit/lib/main.dart`
- Triggers: Flutter engine startup
- Responsibilities: Supabase init, theme restore from `SharedPreferences`, run `PrimeAuditApp`

**Auth gate:**
- Location: `_AuthGate` class in `primeaudit/lib/main.dart`
- Triggers: Supabase auth state stream
- Responsibilities: Route to `HomeScreen` or `LoginScreen` based on session

**Home screen (shell):**
- Location: `primeaudit/lib/screens/home_screen.dart`
- Triggers: Successful authentication
- Responsibilities: Load user profile, init `CompanyContextService`, render drawer navigation, dashboard placeholders

## Error Handling

**Strategy:** Catch-and-display pattern; no global error boundary

**Patterns:**
- Service calls wrapped in `try/catch` inside async methods; errors surfaced via `setState(() => _error = '...')` or `ScaffoldMessenger.showSnackBar`
- Loading states tracked with boolean flags (`_isLoading`, `_loading`, `_finalizing`) toggled around async calls
- Auth deactivation throws `AuthException` from `AuthService.signIn`; caller handles it in the login form
- Answer auto-save (`_saveAnswer` in `AuditExecutionScreen`) fails silently — catch block is empty — to avoid disrupting the UI mid-audit

## Cross-Cutting Concerns

**Theming:** `AppTheme.of(context)` pattern used in every screen; dark/light toggled via `appThemeMode` `ValueNotifier` in `main.dart`; setting persisted as string in `SharedPreferences` under key `settings_theme`

**Authorization:** UI-layer checks via `AppRole.canAccessAdmin(_role)` before rendering admin menu items and FABs; backend enforcement via Supabase RLS (not visible in Flutter code)

**Company scoping:** All list queries pass `CompanyContextService.instance.activeCompanyId` as a filter; `null` means "all companies" (superuser/dev only)

**Conformity calculation:** Lives in `AuditAnswerService.calculateConformity` — weighted scoring: `ok`/`yes` = full weight; `scale_1_5` = (value/5) × weight; `percentage` = (value/100) × weight; `text`/`selection` = full weight if non-empty
