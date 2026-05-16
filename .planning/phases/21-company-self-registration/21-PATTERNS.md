# Phase 21: Company Self-Registration - Pattern Map

**Mapped:** 2026-05-15
**Files analyzed:** 5
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `primeaudit/supabase/migrations/20260515_add_company_status_trial.sql` | migration | batch (DDL) | `primeaudit/supabase/migrations/20260508_add_segment_modules_placa.sql` | exact |
| `primeaudit/lib/models/company.dart` | model | CRUD | self (extend existing) | exact |
| `primeaudit/lib/services/company_service.dart` | service | request-response (RPC) | self (extend existing) | exact |
| `primeaudit/lib/services/auth_service.dart` | service | request-response | self (extend existing) | exact |
| `primeaudit/lib/screens/register_screen.dart` | screen (StatefulWidget) | request-response | self (extend existing) | exact |

---

## Pattern Assignments

### `primeaudit/supabase/migrations/20260515_add_company_status_trial.sql` (migration, DDL batch)

**Analog:** `primeaudit/supabase/migrations/20260508_add_segment_modules_placa.sql`

**File header pattern** (lines 1-5 of analog):
```sql
-- =============================================================================
-- Migração: segmento e módulos em companies; placa em checklist_executions
-- Data: 2026-05-06
-- Idempotente: ADD COLUMN IF NOT EXISTS + DROP/ADD CONSTRAINT não falham em re-execução.
-- =============================================================================
```
Copy this header verbatim, updating the description and date to `2026-05-15`.

**ADD COLUMN IF NOT EXISTS + CHECK constraint pattern** (lines 10-15 of analog):
```sql
ALTER TABLE companies ADD COLUMN IF NOT EXISTS segment TEXT NOT NULL DEFAULT 'industrial';

ALTER TABLE companies DROP CONSTRAINT IF EXISTS companies_segment_check;
ALTER TABLE companies
  ADD CONSTRAINT companies_segment_check
  CHECK (segment IN ('industrial', 'transportador', 'construcao', 'alimenticio', 'logistica', 'outro'));
```
Use the same `DROP CONSTRAINT IF EXISTS` + `ADD CONSTRAINT` pattern for `companies_status_check`.

**NOTIFY pattern** (last line of analog):
```sql
NOTIFY pgrst, 'reload schema';
```
Always the last statement in every migration.

**SECURITY DEFINER function pattern** (from `20260420_handle_new_user_company_id.sql`, lines 11-24):
```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, email, role, company_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'auditor'),
    (NEW.raw_user_meta_data->>'company_id')::UUID
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```
The new `create_company_for_registration` function uses the same `LANGUAGE plpgsql SECURITY DEFINER` declaration. Add `SET search_path = public` after `SECURITY DEFINER` for injection safety (differs from the trigger — new standalone functions require it explicitly).

**Section divider pattern** (lines 9-11, 22-24 of 20260508 analog):
```sql
-- ----------------------------------------------------------------------------
-- 1. companies.segment — segmento de mercado da empresa
-- ----------------------------------------------------------------------------
```
Use numbered section dividers for each logical block in the migration.

**Complete migration structure to produce:**
1. Section 1 — `ALTER TABLE companies ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'` + constraint
2. Section 2 — `ALTER TABLE companies ADD COLUMN IF NOT EXISTS trial_expires_at TIMESTAMPTZ`
3. Section 3 — `ALTER TABLE companies ADD COLUMN IF NOT EXISTS license_expires_at TIMESTAMPTZ`
4. Section 4 — `CREATE OR REPLACE FUNCTION handle_new_user()` patching role clamping (existing SECURITY DEFINER pattern from analog)
5. Section 5 — `CREATE OR REPLACE FUNCTION create_company_for_registration(...)` with SECURITY DEFINER + SET search_path = public + GRANT EXECUTE TO anon
6. `NOTIFY pgrst, 'reload schema'`

---

### `primeaudit/lib/models/company.dart` (model, CRUD)

**Analog:** `primeaudit/lib/models/company.dart` — extend in place

**Constructor pattern** (lines 18-30):
```dart
Company({
  required this.id,
  required this.name,
  this.cnpj,
  this.email,
  this.phone,
  this.address,
  required this.active,
  required this.requiresPerimeter,
  required this.segment,
  required this.modules,
  required this.createdAt,
});
```
Add three new named parameters after `createdAt`:
- `required this.status` (String, NOT NULL with DB default, so always present)
- `this.trialExpiresAt` (DateTime?, nullable)
- `this.licenseExpiresAt` (DateTime?, nullable)

**fromMap pattern** (lines 32-46):
```dart
factory Company.fromMap(Map<String, dynamic> map) {
  return Company(
    id: map['id'],
    name: map['name'],
    cnpj: map['cnpj'],
    email: map['email'],
    phone: map['phone'],
    address: map['address'],
    active: map['active'] ?? true,
    requiresPerimeter: map['requires_perimeter'] ?? false,
    segment: map['segment'] ?? 'industrial',
    modules: (map['modules'] as List?)?.cast<String>() ?? ['auditoria', 'checklist'],
    createdAt: DateTime.parse(map['created_at']),
  );
}
```
Add after `createdAt`:
```dart
status: map['status'] ?? 'active',
trialExpiresAt: map['trial_expires_at'] != null
    ? DateTime.parse(map['trial_expires_at'] as String)
    : null,
licenseExpiresAt: map['license_expires_at'] != null
    ? DateTime.parse(map['license_expires_at'] as String)
    : null,
```
The `?? 'active'` default is critical — existing tests pass `_baseMap()` without `status`, and this prevents a null crash.

**toMap pattern** (lines 50-62) — also update if the method is used for company creation (currently only admin path, not self-registration):
```dart
Map<String, dynamic> toMap() {
  return {
    'name': name,
    'cnpj': cnpj,
    'email': email,
    'phone': phone,
    'address': address,
    'active': active,
    'requires_perimeter': requiresPerimeter,
    'segment': segment,
    'modules': modules,
  };
}
```
`status`, `trial_expires_at`, `license_expires_at` are NOT included in `toMap()` — they are set by the SQL function, not by Flutter-side create calls. This matches the existing pattern of omitting computed/server-set fields from `toMap()`.

**Computed getter pattern** (line 48):
```dart
bool hasModule(String module) => modules.contains(module);
```
Optionally add `bool get isTrial => status == 'trial';` following the same pattern. This is at discretion — not strictly required by Phase 21.

---

### `primeaudit/lib/services/company_service.dart` (service, request-response + RPC)

**Analog:** `primeaudit/lib/services/company_service.dart` — extend in place

**Imports + client declaration pattern** (lines 1-9):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_roles.dart';
import '../models/company.dart';

class CompanyService {
  final _client = Supabase.instance.client;
```
No new imports needed — `_client.rpc()` is available on the existing `SupabaseClient`.

**Existing RPC call shape** — there are no existing `rpc()` calls in this service yet; use the Supabase Flutter 2.x pattern:
```dart
final result = await _client.rpc(
  'function_name',
  params: {'param_key': value},
);
```
The return type of a scalar UUID function is a `String` (or possibly dynamic cast to String — see Assumption A4 in RESEARCH.md).

**New method to add** — after `findByCnpj` (line 66), add:
```dart
/// Cria uma empresa via RPC SECURITY DEFINER (funciona pré-auth, ignora RLS).
/// Retorna o UUID da empresa criada para uso imediato no signUp.
Future<String> createForRegistration({
  required String cnpj,
  required String name,
}) async {
  final result = await _client.rpc(
    'create_company_for_registration',
    params: {'p_cnpj': cnpj, 'p_name': name},
  );
  return result as String;
}
```
Method name follows `createX()` convention (CONVENTIONS.md Services Layer). Does not return `Company` object — the anonymous client cannot SELECT the row after creation due to RLS (Pitfall 1 in RESEARCH.md). Returns only the UUID string.

**Error handling pattern** — the service does NOT catch exceptions internally (per CONVENTIONS.md Services Layer: "Does not handle exceptions internally — callers are responsible for try/catch"). The `createForRegistration` method lets `PostgrestException` propagate to `RegisterScreen._register()`.

---

### `primeaudit/lib/services/auth_service.dart` (service, request-response)

**Analog:** `primeaudit/lib/services/auth_service.dart` — extend in place

**Existing signUp signature** (lines 40-55):
```dart
Future<AuthResponse> signUp({
  required String name,
  required String email,
  required String password,
  String? companyId,
}) async {
  final response = await _client.auth.signUp(
    email: email,
    password: password,
    data: {
      'full_name': name,
      if (companyId != null) 'company_id': companyId,
    },
  );
  return response;
}
```

**Updated signUp signature** — add optional `String? role` parameter and pass it conditionally in `data`:
```dart
Future<AuthResponse> signUp({
  required String name,
  required String email,
  required String password,
  String? companyId,
  String? role,
}) async {
  final response = await _client.auth.signUp(
    email: email,
    password: password,
    data: {
      'full_name': name,
      if (companyId != null) 'company_id': companyId,
      if (role != null) 'role': role,
    },
  );
  return response;
}
```
The conditional map entry pattern `if (companyId != null) 'company_id': companyId` is already used — replicate exactly for `role`. The `handle_new_user` trigger reads `role` from `raw_user_meta_data` and already supports it (verified in RESEARCH.md Section 1, trigger code lines 19-20).

---

### `primeaudit/lib/screens/register_screen.dart` (screen, request-response)

**Analog:** `primeaudit/lib/screens/register_screen.dart` — extend in place

**State fields pattern** (lines 19-33):
```dart
final _formKey = GlobalKey<FormState>();
final _nameController = TextEditingController();
// ... other controllers ...
final _authService = AuthService();
final _companyService = CompanyService();

bool _isLoading = false;
bool _obscurePassword = true;
bool _obscureConfirm = true;
bool _searchingCompany = false;
Company? _foundCompany;
bool _cnpjNotFound = false;
```
Add after `_cnpjNotFound`:
```dart
bool _wantsToCreateCompany = false;
final _companyNameController = TextEditingController();
```

**dispose() pattern** (lines 36-43):
```dart
@override
void dispose() {
  _nameController.dispose();
  _emailController.dispose();
  _passwordController.dispose();
  _confirmPasswordController.dispose();
  _cnpjController.dispose();
  super.dispose();
}
```
Add `_companyNameController.dispose();` before `super.dispose()`. This is Pitfall 7 in RESEARCH.md — a leak if omitted.

**_searchCompany setState pattern** (lines 55-75) — when `_cnpjNotFound` changes to false (new CNPJ typed), also reset `_wantsToCreateCompany`:
```dart
setState(() {
  _foundCompany = null;
  _cnpjNotFound = false;
  _wantsToCreateCompany = false; // reset when CNPJ changes
});
```

**_register() async pattern** (lines 78-114):
```dart
Future<void> _register() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);
  try {
    final response = await _authService.signUp(...);
    if (!mounted) return;
    if (response.user != null) {
      if (response.session == null) {
        _showInfo('...');
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  } on AuthException catch (e) {
    if (!mounted) return;
    _showError(_translateError(e.message));
  } catch (e) {
    if (!mounted) return;
    _showError('Erro inesperado. Tente novamente.');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```
Extend to add a `PostgrestException` catch before the generic `catch`:
```dart
} on PostgrestException catch (e) {
  if (!mounted) return;
  _showError(_translateRegistrationError(e.message));
} on AuthException catch (e) {
```
And insert the self-registration branch before the `signUp` call:
```dart
String? companyId = _foundCompany?.id;

if (_wantsToCreateCompany && _cnpjNotFound) {
  companyId = await _companyService.createForRegistration(
    cnpj: _cnpjController.text.trim(),
    name: _companyNameController.text.trim(),
  );
}

final response = await _authService.signUp(
  name: _nameController.text.trim(),
  email: _emailController.text.trim(),
  password: _passwordController.text,
  companyId: companyId,
  role: _wantsToCreateCompany ? AppRole.adm : null,
);
```
`AppRole.adm` is a constant from `primeaudit/lib/core/app_roles.dart` — import it at the top of the file.

**_showError / _showInfo snackbar pattern** (lines 123-142):
```dart
void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
```
Add `_translateRegistrationError(String message)` alongside `_translateError` — same structure, different message map for `PostgrestException` messages (e.g., `'CNPJ já cadastrado'`, `'CNPJ deve ter 14 dígitos'`).

**_cnpjNotFound container pattern** (lines 376-398):
```dart
} else if (_cnpjNotFound) ...[
  const SizedBox(height: 8),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline_rounded, color: AppColors.error, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Nenhuma empresa encontrada com este CNPJ',
            style: TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ),
      ],
    ),
  ),
],
```
Keep this container as the first child. After it, add a new `if (_cnpjNotFound) ...[ ]` block containing:
1. A `TextButton` "Criar minha empresa" (shown when `!_wantsToCreateCompany`)
2. When `_wantsToCreateCompany == true`: a `TextFormField` for company name + an "X" cancel `IconButton`

**_inputDecoration pattern** (lines 404-437) — reuse for the company name field:
```dart
_inputDecoration(
  label: 'Nome da empresa',
  hint: 'Razão social',
  icon: Icons.business_rounded,
)
```

**CNPJ field validator update** — the existing validator is `validateCnpj` (line 315). When `_wantsToCreateCompany == true`, wrap it to make CNPJ required:
```dart
validator: (v) {
  if (_wantsToCreateCompany) {
    if (v == null || v.trim().isEmpty) return 'CNPJ é obrigatório para criar empresa';
  }
  return validateCnpj(v);
},
```

**Import to add** — `AppRole` is needed for `AppRole.adm`:
```dart
import '../core/app_roles.dart';
```
Also add `PostgrestException` — it is already available via `supabase_flutter` (already imported line 2).

---

## Shared Patterns

### Idempotent Migration Structure
**Source:** `primeaudit/supabase/migrations/20260508_add_segment_modules_placa.sql`
**Apply to:** `20260515_add_company_status_trial.sql`

Every migration follows this exact structure:
1. Header comment block with `=` borders, description, date, idempotency note
2. Numbered section dividers with `-` borders
3. `ADD COLUMN IF NOT EXISTS` for column additions
4. `DROP CONSTRAINT IF EXISTS` + `ADD CONSTRAINT` for check constraints
5. `CREATE OR REPLACE FUNCTION` for function additions (never `CREATE FUNCTION`)
6. `NOTIFY pgrst, 'reload schema'` as final statement

### SECURITY DEFINER Function Declaration
**Source:** `primeaudit/supabase/migrations/20260420_handle_new_user_company_id.sql` (lines 11-24)
**Apply to:** `create_company_for_registration` function in Phase 21 migration

Pattern:
```sql
CREATE OR REPLACE FUNCTION function_name(...)
RETURNS return_type
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  ...
BEGIN
  ...
END;
$$;
```
The existing trigger omits `SET search_path = public`. The new standalone function (called from the public API via anon key) MUST include it to prevent search_path injection.

### Service Client Declaration
**Source:** `primeaudit/lib/services/company_service.dart` (line 9) and `auth_service.dart` (line 8)
**Apply to:** No new service files — both services are extended, not created

```dart
final _client = Supabase.instance.client;
```
Every service holds exactly one private `_client` field. No dependency injection.

### setState Loading Pattern
**Source:** `primeaudit/lib/screens/register_screen.dart` (lines 81, 112)
**Apply to:** `_register()` method in `RegisterScreen`

```dart
setState(() => _isLoading = true);
// ...
finally {
  if (mounted) setState(() => _isLoading = false);
}
```
Single-line `setState` for simple boolean toggles. `mounted` guard in `finally`. The `if (!mounted) return;` guard appears after every `await` that is followed by context access.

### fromMap Null-Safe Default Pattern
**Source:** `primeaudit/lib/models/company.dart` (lines 40-44)
**Apply to:** New fields in `Company.fromMap`

```dart
active: map['active'] ?? true,
requiresPerimeter: map['requires_perimeter'] ?? false,
segment: map['segment'] ?? 'industrial',
```
New columns with DB defaults (`status DEFAULT 'active'`) use the same `?? 'defaultValue'` pattern. Nullable columns use a conditional `DateTime.parse`:
```dart
trialExpiresAt: map['trial_expires_at'] != null
    ? DateTime.parse(map['trial_expires_at'] as String)
    : null,
```

### SnackBar Error/Info Pattern
**Source:** `primeaudit/lib/screens/register_screen.dart` (lines 123-142)
**Apply to:** `_translateRegistrationError` error messages from `PostgrestException`

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(message),
    backgroundColor: AppColors.error,   // or AppColors.primary for info
    behavior: SnackBarBehavior.floating,
  ),
);
```

### Test fromMap Structure
**Source:** `primeaudit/test/models/company_test.dart` (lines 1-81)
**Apply to:** New tests for `status`, `trialExpiresAt`, `licenseExpiresAt` in the same file

```dart
Map<String, dynamic> _baseMap() => <String, dynamic>{
  'id': 'c1',
  'name': 'Acme',
  // ... existing fields ...
};

group('Company.fromMap — defaults', () {
  test('field defaults to X when key absent', () {
    final m = _baseMap()..remove('field_key');
    expect(Company.fromMap(m).fieldName, equals(defaultValue));
  });
});
```
The `_baseMap()` helper does NOT need `status` added — the `?? 'active'` default in `fromMap` ensures existing tests pass unchanged. New test groups cover the three new fields.

---

## No Analog Found

All five files have close analogs in the codebase. No entries in this section.

---

## Metadata

**Analog search scope:** `primeaudit/lib/models/`, `primeaudit/lib/services/`, `primeaudit/lib/screens/`, `primeaudit/supabase/migrations/`, `primeaudit/test/`
**Files scanned:** 8 source files + 20 migration files (glob)
**Pattern extraction date:** 2026-05-15
