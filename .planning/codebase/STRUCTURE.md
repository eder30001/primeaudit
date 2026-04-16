---
generated: 2026-04-16
focus: structure
---

# Codebase Structure

## Top-Level Layout

```
Projeto Audit/                  # Repository root
├── primeaudit/                 # Flutter application (the entire app lives here)
│   ├── lib/                    # Dart source code
│   │   ├── main.dart           # Entry point, app bootstrap, auth gate
│   │   ├── core/               # App-wide constants and theming
│   │   ├── models/             # Domain models (plain Dart classes)
│   │   ├── screens/            # UI screens (StatefulWidget / StatelessWidget)
│   │   │   ├── admin/          # Admin panel screens (companies, users, perimeters)
│   │   │   └── templates/      # Template management screens
│   │   ├── services/           # Data access and business logic
│   │   └── supabase/           # In-app SQL migration files
│   ├── supabase/               # Supabase project config and migrations
│   │   └── migrations/         # SQL migration files
│   ├── android/                # Android platform code (generated)
│   ├── ios/                    # iOS platform code (generated)
│   ├── macos/                  # macOS platform code (generated)
│   ├── web/                    # Web platform assets
│   ├── test/                   # Flutter test directory (currently empty)
│   └── pubspec.yaml            # Package manifest and dependencies
├── .planning/                  # GSD planning artifacts
│   └── codebase/               # Codebase map documents
└── Audit.MD                    # Project description document
```

## Directory Purposes

**`primeaudit/lib/core/`:**
- Purpose: Shared constants, theming helpers, role definitions, Supabase credentials
- Contains: 4 files — `app_colors.dart`, `app_roles.dart`, `app_theme.dart`, `supabase_config.dart`
- Key files:
  - `primeaudit/lib/core/app_roles.dart` — `AppRole` class with role constants and permission helpers
  - `primeaudit/lib/core/app_theme.dart` — `AppTheme` class with typed color tokens (light/dark)
  - `primeaudit/lib/core/app_colors.dart` — Shared static `Color` constants
  - `primeaudit/lib/core/supabase_config.dart` — Supabase URL and anon key (static constants)

**`primeaudit/lib/models/`:**
- Purpose: Typed domain objects, each mapping to a Supabase table
- Contains: 7 files, one model per domain concept
- Key files:
  - `primeaudit/lib/models/audit.dart` — `Audit` class + `AuditStatus` enum with display helpers
  - `primeaudit/lib/models/audit_template.dart` — `AuditTemplate`, `TemplateSection`, `TemplateItem`
  - `primeaudit/lib/models/audit_type.dart` — `AuditType`
  - `primeaudit/lib/models/app_user.dart` — `AppUser` (maps `profiles` table)
  - `primeaudit/lib/models/company.dart` — `Company`
  - `primeaudit/lib/models/perimeter.dart` — `Perimeter` with `buildTree` static method
  - `primeaudit/lib/models/audit_answer.dart` — `AuditAnswer`

**`primeaudit/lib/services/`:**
- Purpose: All Supabase queries and domain logic; each file wraps one domain concept
- Contains: 8 files
- Key files:
  - `primeaudit/lib/services/auth_service.dart` — Login, signup, signout, active-user guard
  - `primeaudit/lib/services/audit_service.dart` — Audit CRUD + status transitions + finalize
  - `primeaudit/lib/services/audit_template_service.dart` — Types, templates, sections, items CRUD
  - `primeaudit/lib/services/audit_answer_service.dart` — Answer upsert, delete, conformity calculation
  - `primeaudit/lib/services/company_context_service.dart` — Singleton for active company context
  - `primeaudit/lib/services/user_service.dart` — User profile queries
  - `primeaudit/lib/services/company_service.dart` — Company CRUD
  - `primeaudit/lib/services/perimeter_service.dart` — Perimeter queries
  - `primeaudit/lib/services/settings_service.dart` — Settings persistence

**`primeaudit/lib/screens/`:**
- Purpose: All app screens; each file is one screen (or a screen + private sub-widgets)
- Top-level screens: `login_screen.dart`, `register_screen.dart`, `home_screen.dart`, `audits_screen.dart`, `audit_execution_screen.dart`, `profile_screen.dart`, `settings_screen.dart`
- Sub-directories:
  - `primeaudit/lib/screens/admin/` — Admin panel: `admin_screen.dart` (TabBar shell), `companies_tab.dart`, `users_tab.dart`, `company_form.dart`, `perimeters_screen.dart`
  - `primeaudit/lib/screens/templates/` — Template management: `audit_types_screen.dart`, `audit_templates_screen.dart`, `template_builder_screen.dart`

**`primeaudit/supabase/migrations/`:**
- Purpose: SQL migration files for the Supabase project
- Contains: `20260406_create_audits.sql` (currently one migration file)
- Generated: No — manually authored SQL
- Committed: Yes

**`primeaudit/lib/supabase/migrations/`:**
- Purpose: Duplicate/reference SQL files stored inside the lib tree (same intent as `supabase/migrations/`)
- Note: Two separate migration directories exist; the canonical one is `primeaudit/supabase/migrations/`

## Key Files

**Entry point:**
- `primeaudit/lib/main.dart` — Supabase init, theme restore, `PrimeAuditApp`, `_AuthGate`

**Configuration:**
- `primeaudit/pubspec.yaml` — Dependencies: `supabase_flutter ^2.8.4`, `shared_preferences ^2.3.3`
- `primeaudit/lib/core/supabase_config.dart` — Hardcoded Supabase URL and anon key

**RBAC:**
- `primeaudit/lib/core/app_roles.dart` — Role constants, permission predicate methods

**Theming:**
- `primeaudit/lib/core/app_theme.dart` — `AppTheme.of(context)` for typed semantic colors

**Audit lifecycle:**
- `primeaudit/lib/screens/audits_screen.dart` — List, filter, create (multi-step sheet), duplicate, close
- `primeaudit/lib/screens/audit_execution_screen.dart` — Execution UI, answer widgets per response type, finalize/cancel

## Naming Conventions

**Files:**
- All lowercase with underscores: `audit_execution_screen.dart`, `company_context_service.dart`
- Screens end in `_screen.dart`; tab components end in `_tab.dart`; forms end in `_form.dart`
- Services end in `_service.dart`
- Models named after the domain entity: `audit.dart`, `perimeter.dart`

**Dart classes:**
- Public classes: `PascalCase` — `AuditService`, `TemplateBuilderScreen`
- Private sub-widgets (scoped to a file): underscore-prefixed `PascalCase` — `_AuditCard`, `_SectionBlock`, `_ItemCard`
- Private state classes: `_ScreenNameState` pattern

**Directories:**
- Lowercase, no underscores for feature groupings: `admin/`, `templates/`, `core/`

## Where to Add New Code

**New screen:**
- Place in `primeaudit/lib/screens/`
- Name: `<feature>_screen.dart`
- If it belongs to a domain cluster (admin, templates): place in the relevant subdirectory
- Register navigation in `home_screen.dart` `_buildDrawer()` or from its parent screen

**New admin sub-screen:**
- Place in `primeaudit/lib/screens/admin/`
- Add as a tab in `admin_screen.dart` or navigate via `Navigator.push` from existing tabs

**New template management screen:**
- Place in `primeaudit/lib/screens/templates/`

**New domain model:**
- Place in `primeaudit/lib/models/<entity>.dart`
- Implement `fromMap(Map<String, dynamic>)` factory
- Add display helpers (`label`, `color`, `icon`) as getters on the class or associated enum

**New service:**
- Place in `primeaudit/lib/services/<domain>_service.dart`
- Hold a local `final _client = Supabase.instance.client;` field
- All methods are `async`, return typed model objects or `void`

**New shared constant or color:**
- Static constants → `primeaudit/lib/core/app_colors.dart`
- Permission logic → `primeaudit/lib/core/app_roles.dart`
- Semantic color tokens → `primeaudit/lib/core/app_theme.dart`

**New Supabase migration:**
- Add `.sql` file to `primeaudit/supabase/migrations/` with timestamp prefix: `YYYYMMDD_<description>.sql`

## Special Directories

**`primeaudit/android/`, `primeaudit/ios/`, `primeaudit/macos/`:**
- Purpose: Platform-specific Flutter boilerplate
- Generated: Partially (by `flutter create`); manually edited only for config
- Committed: Yes

**`primeaudit/build/`:**
- Purpose: Flutter build output
- Generated: Yes
- Committed: No (in `.gitignore`)

**`primeaudit/.dart_tool/`:**
- Purpose: Dart toolchain cache
- Generated: Yes
- Committed: No

**`primeaudit/test/`:**
- Purpose: Flutter unit and widget tests
- Current state: Directory exists but contains no test files
