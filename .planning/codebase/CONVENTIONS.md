---
generated: 2026-04-16
focus: conventions
---

# Coding Conventions

## Linting and Static Analysis

**Config file:** `primeaudit/analysis_options.yaml`

- Extends `package:flutter_lints/flutter.yaml` (the standard Flutter recommended ruleset)
- No custom rules are enabled or disabled — the file uses the default configuration with commented-out examples
- No `prefer_single_quotes` rule is enforced (commented out), so the codebase uses double quotes throughout
- No `avoid_print` override — the Flutter lints default applies

## Naming Conventions

**Files:**
- `snake_case` for all Dart files: `audit_execution_screen.dart`, `company_context_service.dart`, `app_theme.dart`
- Screens are suffixed `_screen.dart`; services are suffixed `_service.dart`; models have no suffix
- Admin screens live in a subdirectory and still follow the same pattern: `screens/admin/companies_tab.dart`

**Classes:**
- `PascalCase` for all public classes: `AuditService`, `AppUser`, `TemplateSection`
- Private widget helpers within a file use `_PascalCase`: `_AuditCard`, `_InfoGrid`, `_NewAuditSheet`, `_PerimeterTreeStep`
- State classes follow Flutter convention: `_LoginScreenState` (private, appending `State` to the widget name)

**Methods and functions:**
- `camelCase` for all methods: `getAudits()`, `upsertAnswer()`, `calculateConformity()`
- Private methods prefix with `_`: `_load()`, `_buildHeader()`, `_confirmEncerrar()`, `_snack()`
- Builder methods are prefixed `_build`: `_buildBody()`, `_buildSearchAndFilters()`, `_buildStepContent()`
- Loader methods are named `_load()` or `_loadX()`: `_loadProfile()`, `_loadSheetData()`, `_loadTemplates()`

**Variables:**
- `camelCase` for all locals and fields
- Private state fields prefixed with `_`: `_isLoading`, `_audits`, `_formKey`
- Controller fields are `_xCtrl` or `_xController`: `_emailController`, `_searchCtrl`
- Service instances in widgets: `final _auditService = AuditService()`
- Constants use `_keyX` pattern for SharedPreferences keys: `static const _keyEmail = 'saved_email'`

**Enums:**
- `PascalCase` for enum types: `AuditStatus`, `_AuditFilter`
- Enum values use `camelCase` (Dart 2.17+ enhanced enums): `emAndamento`, `concluida`, `atrasada`
- Private screen-local enums prefix with `_`: `_AuditFilter`

## Code Organization Within Files

Files are organized in a consistent top-to-bottom order:

1. **Imports** — dart/flutter, then package imports, then relative local imports
2. **Top-level helpers** — standalone functions or constants used by the file (e.g., `_auditTypePrefix()`, `_buildAuditId()` in `audits_screen.dart`)
3. **Enums and extensions** — local enums with their extensions immediately after
4. **Main widget or class** — the public-facing class
5. **Private sub-widgets** — helper `StatelessWidget` / `StatefulWidget` classes defined after the main class, separated by comment banners

Section comment banners are used consistently to delineate logical blocks:
```dart
// ---------------------------------------------------------------------------
// Card de auditoria
// ---------------------------------------------------------------------------
```

## State Management Pattern

**No state management library is used.** The app relies entirely on:

- `StatefulWidget` + `setState()` for local screen state (loading, error, data lists, form fields)
- `ValueNotifier<ThemeMode>` for global theme state — declared at top level in `lib/main.dart`:
  ```dart
  final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  ```
  Consumed via `ValueListenableBuilder` in `PrimeAuditApp.build()`
- `StreamBuilder<AuthState>` in `_AuthGate` to react to Supabase auth changes
- `CompanyContextService` singleton for cross-screen company context (not a proper reactive solution — screens call `CompanyContextService.instance.activeCompanyId` imperatively)

Every screen instantiates its own service objects directly in the state class:
```dart
final _auditService = AuditService();
final _templateService = AuditTemplateService();
```

## Services Layer

Services are plain Dart classes (no base class, no interface). Each service:
- Holds a `final _client = Supabase.instance.client` reference
- Exposes `Future<T>` methods for CRUD operations
- Handles Supabase queries using the `supabase_flutter` fluent API
- Does not handle exceptions internally — callers are responsible for try/catch

Service method naming pattern:
- `getX()` / `getXById()` — read operations
- `createX()` — insert
- `updateX()` — update
- `deleteX()` — delete
- `upsertX()` — upsert (used in `AuditAnswerService`)
- `calculateX()` — pure computation (e.g., `calculateConformity()` in `AuditAnswerService`)

## Model Pattern

All models are plain Dart classes (no base class). Each model:
- Has a `const` or regular constructor with required/optional named parameters
- Implements `factory XModel.fromMap(Map<String, dynamic> map)` for deserialization from Supabase rows
- Does NOT implement `toMap()` (serialization is done inline in service methods)
- May carry computed getters (e.g., `Audit.isOverdue`, `AppUser.canAccessAdmin`, `AuditTemplate.isGlobal`)
- May carry display getters returning `String`, `Color`, or `IconData` (e.g., `AuditStatus.label`, `AuditStatus.color`, `AuditStatus.icon`)

Example pattern from `lib/models/audit.dart`:
```dart
class Audit {
  final String id;
  // ... fields

  const Audit({ required this.id, ... });

  factory Audit.fromMap(Map<String, dynamic> map) { ... }

  bool get isOverdue => ...;
}
```

## Theming Pattern

Two complementary theme abstractions exist side by side:

**`AppColors`** (`lib/core/app_colors.dart`) — static constants, used for fixed brand colors that don't change between light/dark:
```dart
AppColors.primary   // #1E3A5F corporate blue
AppColors.accent    // #2196F3 action blue
AppColors.error     // #E53935 red
```

**`AppTheme`** (`lib/core/app_theme.dart`) — a custom class with light/dark variants, accessed via `AppTheme.of(context)`:
```dart
final t = AppTheme.of(context);
Container(color: t.background)
Text('...', style: TextStyle(color: t.textPrimary))
```

The convention in every screen is to obtain `final t = AppTheme.of(context)` at the top of `build()` and use `t.X` for dynamic colors, and `AppColors.X` for fixed brand colors.

Material 3 is enabled (`useMaterial3: true`). Font family is `Roboto`.

## Error Handling Pattern

Services throw exceptions unhandled; screens catch them in `try/catch/finally` blocks:

```dart
Future<void> _load() async {
  setState(() { _isLoading = true; _error = null; });
  try {
    final data = await _service.getX(...);
    if (mounted) setState(() => _items = data);
  } catch (e) {
    if (mounted) setState(() => _error = 'Erro ao carregar.\n$e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

The `mounted` guard before every `setState()` after an `await` is applied consistently.

Specific Supabase `AuthException` is caught separately from generic `Exception` in auth flows:
```dart
} on AuthException catch (e) {
  _showError(e.message);
} catch (e) {
  _showError('Erro inesperado. Tente novamente.');
}
```

Errors are surfaced to the user via:
- `ScaffoldMessenger.of(context).showSnackBar(...)` with `SnackBarBehavior.floating` — short messages
- Inline error widget in the body with a retry button — for list/load failures

## UI Patterns

**Loading states:** `CircularProgressIndicator(color: AppColors.primary)` centered in a `Scaffold` body or wrapped in `SizedBox(height: N, child: Center(...))`.

**Empty states:** A `Column` with an `Icon`, title `Text`, subtitle `Text`, and optionally a CTA button. Applied consistently in `audits_screen.dart`, `_buildBody()`.

**Forms:** `Form` widget with `GlobalKey<FormState>`, `TextFormField` with `validator` callbacks returning `String?` error messages. Submit guarded by `_formKey.currentState!.validate()`.

**Navigation:** Imperative `Navigator.of(context).push(MaterialPageRoute(...))` — no named routes. `pushReplacement` used for auth transitions.

**Modals:** `showModalBottomSheet` with `isScrollControlled: true` for multi-step flows. `showDialog<bool>` for confirmation dialogs.

**Button disable pattern:** Loading state disables the button via `onPressed: _isLoading ? null : _handler` and replaces the label with a `CircularProgressIndicator`.

## Singleton Pattern

`CompanyContextService` uses a private constructor + static `_instance` singleton:
```dart
static final CompanyContextService _instance = CompanyContextService._();
static CompanyContextService get instance => _instance;
CompanyContextService._();
```

## Dart Language Features Used

- Enhanced enums (Dart 2.17+) with methods and getters: `AuditStatus` in `lib/models/audit.dart`
- `extension` on enums for UI labels: `extension _AuditFilterLabel on _AuditFilter`
- `Future.wait([...])` for parallel async operations
- Named parameters everywhere (`required` for mandatory, optional with `?` type)
- Null-aware operators (`?.`, `??`, `??=`) used throughout
- `switch` expressions without `break` (enhanced switch in Dart 3): used in enum getter bodies
- No `async*` / `yield` / streams in application logic (only Supabase's `onAuthStateChange` stream is consumed)
