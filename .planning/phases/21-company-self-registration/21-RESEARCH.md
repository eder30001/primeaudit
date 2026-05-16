# Phase 21: Company Self-Registration - Research

**Researched:** 2026-05-15
**Domain:** Flutter registration flow + Supabase RLS + PostgreSQL migration
**Confidence:** HIGH

---

## Summary

Phase 21 adds self-service company creation to the existing `RegisterScreen`. Today, when a
user types a CNPJ that does not match any company in the database, the screen shows an error
badge and allows the user to proceed without a company (role defaults to `auditor`, no
`company_id`). This phase makes that "not found" branch actionable: the user can type a company
name and have the app create the company and then register the user as `adm` of that company in
one sequential flow.

The critical architectural constraint is that the Supabase `companies` table has RLS enabled
and currently only permits `superuser`/`dev` roles to INSERT. An unauthenticated caller cannot
use the standard authenticated client to insert a company. The solution is a Supabase `SECURITY
DEFINER` PostgreSQL function (invoked via PostgREST RPC `rpc('register_company_and_user')`) that
atomically creates the company and the auth user inside the database, bypassing RLS safely. This
is the same pattern Supabase recommends for bootstrap/self-registration scenarios.

An alternative approach — create the company first with an anon key from the Flutter app — is
blocked by RLS policies and would require either disabling RLS (unacceptable) or granting
anonymous INSERT on `companies` (dangerous). The RPC approach keeps the privileged operation
server-side.

The SQL migration for `status`, `trial_expires_at`, and `license_expires_at` columns is
straightforward: `ADD COLUMN IF NOT EXISTS` with safe defaults for existing rows (`status =
'active'` for existing companies preserves current behavior; trial fields nullable).

**Primary recommendation:** Use a `SECURITY DEFINER` RPC function to atomically create the
company and sign up the user. The Flutter app calls `rpc()` instead of doing two separate
network hops. No new packages required; no state management changes.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CNPJ lookup (already exists) | API / Supabase | Flutter client | `findByCnpj` already implemented in `CompanyService` |
| "Create my company" UI branch | Browser / Flutter client | — | New conditional section in `RegisterScreen` |
| Company INSERT + user signup (atomic) | API / Supabase DB function | Flutter client (caller) | RLS blocks unauthenticated INSERT on `companies`; SECURITY DEFINER function runs as postgres |
| Profile insertion on signup | Database / Trigger | — | `handle_new_user` trigger already handles this |
| Trial columns migration | Database / Storage | — | Idempotent `ALTER TABLE ADD COLUMN IF NOT EXISTS` |

---

## 1. Current State Analysis

### RegisterScreen (verified)
[VERIFIED: read `primeaudit/lib/screens/register_screen.dart`]

- Has full CNPJ field with live search via `_searchCompany()` (calls `CompanyService.findByCnpj`)
- State variables: `_foundCompany` (Company?), `_cnpjNotFound` (bool)
- When `_cnpjNotFound == true`, shows a red info badge: "Nenhuma empresa encontrada com este CNPJ"
- Calls `_authService.signUp(name, email, password, companyId: _foundCompany?.id)` on submit
- If `companyId` is null (no company found), user is created without a company (role becomes
  default from trigger: `auditor`)
- **Gap:** There is no "create my company" affordance today — the not-found state is a dead end

### AuthService.signUp (verified)
[VERIFIED: read `primeaudit/lib/services/auth_service.dart`]

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

- Passes `company_id` and `full_name` as `raw_user_meta_data` via Supabase Auth
- The `handle_new_user` trigger reads these fields and inserts into `profiles`
- Does NOT pass `role` — the trigger defaults to `'auditor'`
- **Gap:** No way to pass `role = 'adm'` through the current `signUp` signature

### handle_new_user trigger (verified)
[VERIFIED: read `primeaudit/supabase/migrations/20260420_handle_new_user_company_id.sql`]

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

- **Key finding:** The trigger already reads `role` from `raw_user_meta_data`. Passing
  `'role': 'adm'` in `signUp`'s `data` map will set the profile role to `adm`.
- No trigger modification is needed for role assignment.

### CompanyService.findByCnpj (verified)
[VERIFIED: read `primeaudit/lib/services/company_service.dart`]

```dart
Future<Company?> findByCnpj(String cnpj) async {
  final clean = cnpj.replaceAll(RegExp(r'[.\-/\s]'), '');
  if (clean.length != 14) return null;
  final data = await _client
      .from('companies')
      .select()
      .eq('active', true)
      .eq('cnpj', clean)
      .maybeSingle();
  return data != null ? Company.fromMap(data) : null;
}
```

- Returns null when no company found — already drives `_cnpjNotFound` state in `RegisterScreen`
- Can be reused as-is; no changes needed

### CompanyService.create (verified)
[VERIFIED: read `primeaudit/lib/services/company_service.dart`]

```dart
Future<Company> create(Map<String, dynamic> data) async {
  final result = await _client
      .from('companies')
      .insert(data)
      .select()
      .single();
  return Company.fromMap(result);
}
```

- Uses the authenticated client — **requires a logged-in user with sufficient role**
- An unauthenticated caller (during registration, before `signUp`) cannot use this

### RLS on companies table (verified)
[VERIFIED: read `primeaudit/supabase/migrations/20260419_rls_profiles_companies_perimeters.sql`]

Current policies:
- `superuser_dev_companies_full` — full access for superuser/dev only
- `adm_companies_select` — adm can SELECT own company
- `auditor_companies_select` — auditor can SELECT own company

**No INSERT policy exists for unauthenticated users or any non-superuser/dev role.**
A Flutter app call to `companies.insert()` before auth will be rejected by RLS.

### companies table schema (verified)
[VERIFIED: read `primeaudit/supabase/schema.sql` + all migrations]

Current columns after all applied migrations:
- `id` UUID PK
- `name` TEXT NOT NULL
- `cnpj` TEXT UNIQUE (unique constraint confirmed in schema.sql)
- `email` TEXT
- `phone` TEXT
- `address` TEXT
- `active` BOOLEAN DEFAULT true
- `created_at` TIMESTAMPTZ DEFAULT NOW()
- `requires_perimeter` BOOLEAN NOT NULL DEFAULT false (added 20260406)
- `segment` TEXT NOT NULL DEFAULT 'industrial' (added 20260508)
- `modules` TEXT[] NOT NULL DEFAULT ARRAY['auditoria', 'checklist'] (added 20260508)

**Missing columns** (to be added by Phase 21 migration):
- `status` TEXT — trial/active/payment_pending/suspended
- `trial_expires_at` TIMESTAMPTZ — nullable
- `license_expires_at` TIMESTAMPTZ — nullable

### Company.fromMap (verified)
[VERIFIED: read `primeaudit/lib/models/company.dart`]

Does not include `status`, `trial_expires_at`, or `license_expires_at` fields.
Model must be updated to handle these new columns (even if Phase 22 consumes them, the Dart
model should not break when Supabase returns the new columns).

---

## 2. Migration Strategy

### Why safe defaults matter

Existing companies in production have no `status` value. The default must not break Phase 22's
logic. Decision:
- `status` default `'active'` — existing companies are treated as fully active (preserves access)
- `trial_expires_at` default `NULL` — existing companies are not in trial
- `license_expires_at` default `NULL` — existing companies have no expiry (Phase 22 sets this on payment)

Phase 22 will query `status = 'trial'` and `trial_expires_at < now()` to detect expiry — existing
companies with `status = 'active'` are immune.

### Migration SQL

```sql
-- =============================================================================
-- Migration: add status and trial/license expiry columns to companies
-- Date: 2026-05-15
-- Idempotent: ADD COLUMN IF NOT EXISTS + DROP/ADD CONSTRAINT are safe on re-run
-- Required by: Phase 21 (self-registration trial) + Phase 22 (billing)
-- =============================================================================

-- 1. Add status column (TEXT, NOT NULL with default 'active' for existing rows)
ALTER TABLE companies ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

-- 2. Add constraint for valid status values
ALTER TABLE companies DROP CONSTRAINT IF EXISTS companies_status_check;
ALTER TABLE companies
  ADD CONSTRAINT companies_status_check
  CHECK (status IN ('trial', 'active', 'payment_pending', 'suspended'));

-- 3. Add trial_expires_at (nullable — only set for self-registered companies)
ALTER TABLE companies ADD COLUMN IF NOT EXISTS trial_expires_at TIMESTAMPTZ;

-- 4. Add license_expires_at (nullable — set by Phase 22 Asaas webhook on payment)
ALTER TABLE companies ADD COLUMN IF NOT EXISTS license_expires_at TIMESTAMPTZ;

NOTIFY pgrst, 'reload schema';
```

**Filename:** `20260515_add_company_status_trial.sql`

---

## 3. RLS & Auth Flow

### The Core Problem

Company INSERT before authentication:
```
User types CNPJ → not found → wants to create company
→ Must INSERT into companies BEFORE creating auth user (to get company_id)
→ But companies INSERT requires superuser/dev role (RLS)
→ User is not authenticated yet
→ BLOCKED by RLS
```

### Option A: SECURITY DEFINER RPC Function (RECOMMENDED)

Create a PostgreSQL function with `SECURITY DEFINER` that runs as the `postgres` superuser,
bypassing RLS. The function accepts company data + user credentials and atomically:
1. Creates the company (gets `company_id`)
2. Calls `auth.users` insert OR returns the company_id for the client to call `signUp`

**The complication:** Supabase Edge's PostgREST can call SQL functions via `rpc()`, but those
functions cannot directly call `supabase.auth.signUp` (that's a GoTrue API call, not SQL). The
function can only create a row in `auth.users` directly — which is possible but fragile and
bypasses GoTrue's hashing/validation.

**Practical resolution:** The SECURITY DEFINER function creates ONLY the company row and returns
the `company_id`. The Flutter app then calls `auth.signUp()` with that `company_id` in metadata.
The trigger handles profile creation with `role = 'adm'`.

```
Flutter:
1. rpc('create_company_for_registration', {cnpj, name, segment, modules})
   → SECURITY DEFINER function runs as postgres
   → INSERTs into companies with status='trial', trial_expires_at=now()+30d
   → Returns new company_id (UUID)
2. authService.signUp(name, email, password, companyId: company_id, role: 'adm')
   → Supabase Auth creates auth.users row
   → handle_new_user trigger fires: INSERTs into profiles with company_id + role='adm'
3. On success → navigate to HomeScreen (or show "verify email" if email confirmation enabled)
```

**Why not two separate app-level calls with an authenticated client?**
- The user is not authenticated during step 1 — cannot use authenticated Supabase client policies
- Step 2 (signUp) must happen after step 1 (to have company_id) — cannot parallelize

**Rollback concern:** If `signUp` fails after `create_company_for_registration` succeeds, the
company row exists but no user is linked to it. Mitigations:
- The CNPJ unique constraint means a retry with the same CNPJ will return a "CNPJ already in use"
  error to the next attempt to create
- A simpler mitigation: the RPC function also accepts a `check_cnpj_unique` parameter and returns
  early if the CNPJ already exists — avoiding orphan companies
- Orphan companies (no owner) are a minor ops concern for MVP. Add cleanup logic in a later phase.

**The RPC function:**

```sql
-- SECURITY DEFINER function: creates a company for self-registration
-- Called via rpc() from unauthenticated (anon key) Flutter app
-- Returns the new company's UUID for use in the subsequent signUp call
CREATE OR REPLACE FUNCTION create_company_for_registration(
  p_cnpj    TEXT,
  p_name    TEXT,
  p_segment TEXT DEFAULT 'industrial',
  p_modules TEXT[] DEFAULT ARRAY['auditoria', 'checklist']
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_clean_cnpj TEXT;
  v_company_id UUID;
BEGIN
  -- Normalize CNPJ (strip formatting)
  v_clean_cnpj := regexp_replace(p_cnpj, '[.\-/\s]', '', 'g');

  -- Guard: CNPJ must be 14 digits
  IF length(v_clean_cnpj) != 14 THEN
    RAISE EXCEPTION 'CNPJ deve ter 14 dígitos';
  END IF;

  -- Guard: CNPJ must not already exist
  IF EXISTS (SELECT 1 FROM companies WHERE cnpj = v_clean_cnpj) THEN
    RAISE EXCEPTION 'CNPJ já cadastrado no sistema';
  END IF;

  -- Guard: name must not be empty
  IF trim(p_name) = '' THEN
    RAISE EXCEPTION 'Nome da empresa é obrigatório';
  END IF;

  -- Create the company
  INSERT INTO companies (cnpj, name, segment, modules, status, trial_expires_at, active)
  VALUES (
    v_clean_cnpj,
    trim(p_name),
    p_segment,
    p_modules,
    'trial',
    now() + interval '30 days',
    true
  )
  RETURNING id INTO v_company_id;

  RETURN v_company_id;
END;
$$;
```

**Important:** Grant execute to `anon` role so the unauthenticated Supabase client can call it:

```sql
GRANT EXECUTE ON FUNCTION create_company_for_registration(TEXT, TEXT, TEXT, TEXT[]) TO anon;
```

**Security analysis of the RPC approach:**
- The function can only INSERT into `companies`, not read/update/delete anything else
- Input is validated: CNPJ uniqueness, name non-empty, CNPJ length
- `SET search_path = public` prevents search_path injection attacks [CITED: Supabase docs on security definer]
- The `anon` key is designed to be public per Supabase's model — granting `anon` EXECUTE is the
  standard pattern for public-facing unauthenticated actions [ASSUMED: Supabase anon EXECUTE pattern]

### Option B: Two-step with pre-signUp then post-signUp update (NOT RECOMMENDED)

1. Call `signUp` with no `company_id`
2. After auth, use the authenticated client to create the company and update the profile

Rejected because:
- Race condition: profile exists without company_id between steps 1 and 2
- RLS on profiles UPDATE: the new `adm` user would need an UPDATE policy on their own profile
  that doesn't currently exist
- The user sees the home screen briefly without company context

### Option C: Edge Function (OVERKILL for this phase)

Supabase Edge Function using `service_role` key could do everything. Phase 23 (invite) uses
this pattern. For this phase, a simpler SQL RPC suffices — no extra infrastructure needed.

### Flow Diagram

```
RegisterScreen (_cnpjNotFound == true)
        │
        ▼
User types company name → taps "Criar minha empresa"
        │
        ▼
Flutter: _companyService.createForRegistration(cnpj, name)
  → Supabase rpc('create_company_for_registration', {...})
  → SECURITY DEFINER runs as postgres
  → companies INSERT (status='trial', trial_expires_at=+30d)
  → Returns company_id
        │
        ▼
Flutter: _authService.signUp(name, email, password,
           companyId: company_id, role: 'adm')
  → Supabase auth.signUp with raw_user_meta_data:
      {full_name, company_id, role:'adm'}
  → GoTrue creates auth.users row
  → handle_new_user trigger fires:
      profiles INSERT (company_id, role='adm')
        │
        ▼
On success → HomeScreen or "verify email" snackbar
```

---

## 4. Flutter Implementation Approach

### New State Variables in RegisterScreen

```dart
bool _wantsToCreateCompany = false;      // user clicked "Criar minha empresa"
final _companyNameController = TextEditingController();  // company name input
bool _creatingCompany = false;           // loading state for RPC call
```

### Branching Logic (in `_buildForm`)

When `_cnpjNotFound == true`:
- Show existing red badge ("Nenhuma empresa encontrada com este CNPJ")
- PLUS a new "Criar minha empresa" button / expandable section
- When `_wantsToCreateCompany == true`, show a `TextFormField` for company name

The "Criar minha empresa" section replaces the current dead-end with an actionable option.
No new screen needed — inline expansion within the existing form.

### Updated `_register()` flow

```dart
Future<void> _register() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);

  try {
    String? companyId = _foundCompany?.id;

    // Self-registration path: create company first, then sign up
    if (_wantsToCreateCompany && _cnpjNotFound) {
      final createdCompany = await _companyService.createForRegistration(
        cnpj: _cnpjController.text.trim(),
        name: _companyNameController.text.trim(),
      );
      companyId = createdCompany.id;
    }

    final response = await _authService.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      companyId: companyId,
      role: companyId != null && _wantsToCreateCompany ? AppRole.adm : null,
    );

    // ... existing navigation logic unchanged
  } on PostgrestException catch (e) {
    _showError(_translateRegistrationError(e.message));
  } on AuthException catch (e) {
    _showError(_translateError(e.message));
  } catch (e) {
    _showError('Erro inesperado. Tente novamente.');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### Form Validation for company name

The CNPJ field validator (`validateCnpj`) already runs. The company name field needs its own
validator when `_wantsToCreateCompany == true`:

```dart
validator: (v) {
  if (!_wantsToCreateCompany) return null; // not required if not creating
  if (v == null || v.trim().isEmpty) return 'Informe o nome da empresa';
  return null;
},
```

### UI for "Criar minha empresa" branch

Design pattern consistent with existing codebase (no new libraries):
- A `TextButton` or outlined button "Criar minha empresa" inside the `_cnpjNotFound` container
- When tapped: `setState(() => _wantsToCreateCompany = true)`
- Shows a `TextFormField` for company name with `Icons.business_rounded`
- An "X" (cancel) button to revert: `setState(() => _wantsToCreateCompany = false)`

The "Empresa (opcional)" section divider text can remain as-is for the found-company branch.
When `_wantsToCreateCompany == true`, the section becomes effectively required.

---

## 5. Service Layer Changes

### CompanyService: add `createForRegistration`

```dart
/// Creates a company via SECURITY DEFINER RPC (works pre-auth, bypasses RLS).
/// Returns the created Company with status='trial' and trial_expires_at set.
Future<Company> createForRegistration({
  required String cnpj,
  required String name,
  String segment = 'industrial',
  List<String> modules = const ['auditoria', 'checklist'],
}) async {
  final companyId = await _client.rpc(
    'create_company_for_registration',
    params: {
      'p_cnpj': cnpj,
      'p_name': name,
      'p_segment': segment,
      'p_modules': modules,
    },
  );
  // RPC returns the UUID; fetch the full row to return a Company object
  final data = await _client
      .from('companies')
      .select()
      .eq('id', companyId as String)
      .single();
  return Company.fromMap(data);
}
```

Note: After creating the company and before `signUp`, the client is still unauthenticated.
The SELECT after RPC creation requires a read policy. Options:
1. Have the RPC return the full row (simpler, one round-trip)
2. Skip fetching the full Company object — just use the returned UUID for signUp

**Option 2 is simpler and sufficient for the registration flow.** The Flutter app only needs
`company_id` (the UUID) to pass to `signUp`. No need to display company details at this point.

```dart
/// Simpler variant: returns only the UUID
Future<String> createForRegistration({
  required String cnpj,
  required String name,
}) async {
  final companyId = await _client.rpc(
    'create_company_for_registration',
    params: {'p_cnpj': cnpj, 'p_name': name},
  );
  return companyId as String;
}
```

### AuthService: extend `signUp` to accept `role`

```dart
Future<AuthResponse> signUp({
  required String name,
  required String email,
  required String password,
  String? companyId,
  String? role,            // NEW: optional role for self-registration as 'adm'
}) async {
  final response = await _client.auth.signUp(
    email: email,
    password: password,
    data: {
      'full_name': name,
      if (companyId != null) 'company_id': companyId,
      if (role != null) 'role': role,          // NEW
    },
  );
  return response;
}
```

The trigger already handles `role` from metadata — no trigger changes needed.

### Company model: add new fields

```dart
class Company {
  // ... existing fields ...
  final String status;              // 'trial' | 'active' | 'payment_pending' | 'suspended'
  final DateTime? trialExpiresAt;   // null for legacy companies
  final DateTime? licenseExpiresAt; // null until first payment

  // In fromMap:
  status: map['status'] ?? 'active',
  trialExpiresAt: map['trial_expires_at'] != null
      ? DateTime.parse(map['trial_expires_at']) : null,
  licenseExpiresAt: map['license_expires_at'] != null
      ? DateTime.parse(map['license_expires_at']) : null,
}
```

The existing `company_test.dart` `_baseMap()` does not include `status` — the `?? 'active'`
default means tests continue to pass without changes to the test base map. New tests should
cover status parsing.

---

## 6. Risk & Pitfalls

### Pitfall 1: RLS blocks company SELECT after creation (before auth)
**What goes wrong:** After `create_company_for_registration` returns the UUID, calling
`_client.from('companies').select().eq('id', uuid)` as an anonymous user will be rejected
by RLS (no SELECT policy for anon).
**Prevention:** Have the RPC return all needed data (or just use the UUID without fetching full
row). Design `createForRegistration` to return only the UUID string.

### Pitfall 2: Orphan company if signUp fails
**What goes wrong:** RPC creates the company, then `signUp` throws (e.g., email already
registered). Company row exists with no owner.
**Prevention:** Show a specific error message "Empresa criada, mas falha no cadastro. Tente
novamente com o mesmo CNPJ." The CNPJ unique constraint will surface the conflict on the next
attempt. Add a comment in the code noting this is a known edge case for future cleanup.

### Pitfall 3: CNPJ unique constraint race condition
**What goes wrong:** Two users simultaneously register with the same CNPJ. Both pass
`findByCnpj` (returns null), both call the RPC. Second RPC call hits the UNIQUE constraint.
**Prevention:** The RPC function includes a guard (`IF EXISTS ... RAISE EXCEPTION`) AND the
`cnpj UNIQUE` DB constraint provides a hard stop. The exception message is translated to user-
friendly text in `_translateRegistrationError`. This is acceptable for MVP.

### Pitfall 4: CNPJ validator is optional today — must be required for self-registration
**What goes wrong:** `validateCnpj` in `cnpj_validator.dart` returns null for empty input
(the field is currently optional). If the user taps "Criar minha empresa" and the CNPJ is
empty or invalid, the form submits with a bad CNPJ.
**Prevention:** When `_wantsToCreateCompany == true`, the CNPJ validator must be non-optional.
Use a wrapper validator in the form that calls `validateCnpj` for the non-empty case AND
additionally requires a valid CNPJ when creating a company:

```dart
validator: (v) {
  if (_wantsToCreateCompany) {
    if (v == null || v.trim().isEmpty) return 'CNPJ é obrigatório para criar empresa';
    return validateCnpj(v); // full validation
  }
  return validateCnpj(v); // already handles null/empty as optional
},
```

### Pitfall 5: `handle_new_user` trigger role escalation risk
**What goes wrong:** A malicious user crafts a signUp request with `'role': 'superuser'` in
user_metadata. The trigger would create a `superuser` profile.
**Current status:** The RLS policies for `profiles` UPDATE guard against role escalation
(adm_profiles_update policy). But the trigger INSERT has no role check.
**Scope:** This is a pre-existing vulnerability in the codebase. Phase 21 increases the risk
by making self-registration more prominent.
**Recommendation:** The trigger should be updated to clamp the allowed roles for self-
registration. A simple guard: if the request does not come from an admin context (no
authenticated session), only allow `'auditor'` or `'adm'` — not `'superuser'` or `'dev'`.
The migration should patch `handle_new_user` to reject privilege escalation:

```sql
COALESCE(
  CASE WHEN NEW.raw_user_meta_data->>'role' IN ('auditor', 'adm')
       THEN NEW.raw_user_meta_data->>'role'
       ELSE 'auditor' END,
  'auditor'
)
```

This clamps self-registered users to `auditor` or `adm`. Superuser/dev must still be set
by an existing superuser via the Admin panel.

### Pitfall 6: Email confirmation flow
**What goes wrong:** If Supabase project has email confirmation enabled, `signUp` returns
`response.session == null` and the user is redirected to pop the screen with a "check email"
message. The company was already created but the user has not confirmed their email. Until
confirmation, the profile trigger does NOT fire (GoTrue only fires the trigger on confirmation,
not on initial signup in some configurations).
**Verification needed:** Check whether the Supabase project has email confirmation enabled.
[ASSUMED: email confirmation behavior — depends on project settings. The existing RegisterScreen
already handles `session == null` case correctly — same behavior applies.]
**Mitigation:** The existing RegisterScreen logic already handles both cases. No change needed
for the session-null branch. The company is already created and will be linked when the user
confirms.

### Pitfall 7: Missing dispose for new controller
**What goes wrong:** `_companyNameController` must be disposed in `dispose()` or it leaks.
**Prevention:** Add `_companyNameController.dispose()` to `RegisterScreen.dispose()`.

---

## 7. Recommended Implementation Order

### Wave 0 — Database Foundation
1. **SQL migration file** `20260515_add_company_status_trial.sql`
   - Add `status`, `trial_expires_at`, `license_expires_at` columns
   - Add `companies_status_check` constraint
   - Patch `handle_new_user` to clamp role to `auditor`|`adm`
   - Add `create_company_for_registration` SECURITY DEFINER function
   - `GRANT EXECUTE ON FUNCTION ... TO anon`
   - `NOTIFY pgrst, 'reload schema'`

### Wave 1 — Dart Model
2. **Update `Company` model** (`primeaudit/lib/models/company.dart`)
   - Add `status`, `trialExpiresAt`, `licenseExpiresAt` fields
   - Update `fromMap` with safe defaults
   - Update `toMap` if needed (probably not — create writes directly to map)
3. **Update `company_test.dart`**
   - Verify `_baseMap()` still passes (should via `?? 'active'` default)
   - Add test for `status` parsing

### Wave 2 — Service Layer
4. **Update `AuthService.signUp`** to accept optional `role` parameter
5. **Update `CompanyService`** — add `createForRegistration(cnpj, name)` method that calls RPC

### Wave 3 — UI
6. **Update `RegisterScreen`**
   - Add `_wantsToCreateCompany`, `_companyNameController`, `_creatingCompany` state
   - Replace dead-end `_cnpjNotFound` container with actionable "Criar minha empresa" section
   - Add company name `TextFormField` (shown when `_wantsToCreateCompany == true`)
   - Update `_register()` to call `createForRegistration` before `signUp` in self-reg path
   - Update CNPJ field validator to require CNPJ when `_wantsToCreateCompany == true`
   - Add dispose for `_companyNameController`

### Wave 4 — Tests
7. **New test file** `test/services/company_service_test.dart` (or extend existing)
   - Test `createForRegistration` method signature and error handling
8. **Update `company_test.dart`**
   - Add fromMap test with status/trialExpiresAt/licenseExpiresAt

---

## Standard Stack

No new packages required. All implementation uses:

| Component | Already Present | Purpose |
|-----------|----------------|---------|
| `supabase_flutter` 2.12.2 | Yes | `_client.rpc()`, `_client.auth.signUp()` |
| `flutter_test` SDK | Yes | Unit tests |
| Existing `cnpj_validator.dart` | Yes | CNPJ validation (reused) |
| Existing `AppRole` constants | Yes | `AppRole.adm` constant |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Bypassing RLS for unauthenticated INSERT | Custom auth token magic | `SECURITY DEFINER` SQL function via `rpc()` |
| CNPJ validation | New validator | Existing `cnpj_validator.dart` `validateCnpj` |
| Role constants | String literals | Existing `AppRole.adm` constant |
| CNPJ cleanup in SQL | Regex in Dart only | `regexp_replace` inside the SQL function (normalize at DB level) |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `GRANT EXECUTE ... TO anon` is the standard Supabase pattern for public RPC calls | RLS & Auth Flow | If wrong: RPC returns 403; need to use service_role via Edge Function instead |
| A2 | GoTrue fires `handle_new_user` trigger on `auth.signUp()` regardless of email confirmation | Pitfall 6 | If trigger fires only on confirmation: company created but profile not linked until email confirmed — acceptable for MVP but must test |
| A3 | Existing Supabase project does not have email confirmation enforced (RegisterScreen already handles both cases) | Current State | If enabled: flow works but user may be confused — no code change needed |
| A4 | `_client.rpc()` in supabase_flutter 2.12.2 returns the scalar value directly (UUID as String) for functions returning UUID | Service Layer | If it returns a Map instead: need to cast differently (e.g., `result['create_company_for_registration']`) |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK built-in) |
| Config file | none (uses Flutter default test runner) |
| Quick run command | `flutter test test/models/company_test.dart` |
| Full suite command | `flutter test` (from `primeaudit/`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ONBOARD-01 (SC-1) | CNPJ not found → "Criar minha empresa" UI branch appears | widget | `flutter test test/screens/register_screen_self_reg_test.dart` | ❌ Wave 0 |
| ONBOARD-01 (SC-2) | Company created with status='trial', trial_expires_at=+30d | unit | `flutter test test/services/company_service_test.dart` | ❌ Wave 4 |
| ONBOARD-01 (SC-3) | signUp passes role='adm' + company_id in metadata | unit | `flutter test test/services/auth_service_test.dart` | ❌ Wave 4 |
| ONBOARD-01 (SC-4) | Existing CNPJ found path unchanged | widget | `flutter test test/screens/register_screen_self_reg_test.dart` | ❌ Wave 0 |
| ONBOARD-01 (SC-5) | Company.fromMap parses status/trialExpiresAt/licenseExpiresAt | unit | `flutter test test/models/company_test.dart` | ✅ (needs extension) |

### Sampling Rate
- **Per task commit:** `flutter test test/models/company_test.dart test/core/cnpj_validator_test.dart`
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/screens/register_screen_self_reg_test.dart` — covers ONBOARD-01 SC-1, SC-4 (widget tests)
- [ ] `test/services/company_service_test.dart` — covers SC-2 method signature
- [ ] `test/services/auth_service_test.dart` — covers SC-3 role parameter

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Supabase GoTrue (existing) |
| V3 Session Management | no | — |
| V4 Access Control | yes | SECURITY DEFINER + role clamping in trigger |
| V5 Input Validation | yes | `validateCnpj` + server-side guards in SQL function |
| V6 Cryptography | no | Password hashing handled by GoTrue |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Role escalation via user_metadata | Elevation of Privilege | Clamp `role` in `handle_new_user` to `auditor`/`adm` only |
| CNPJ squatting (register competitor's CNPJ) | Tampering | Unique constraint + admin can revoke; accept as MVP limitation |
| Orphan company DoS (repeated failed signUps) | Denial of Service | Supabase rate limiting on auth.signUp + DB UNIQUE on CNPJ limits duplicates |
| SQL injection in RPC params | Tampering | Parameterized RPC call; SQL function uses `$1` params not string concat |

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: `primeaudit/lib/screens/register_screen.dart`] — current registration flow, state variables
- [VERIFIED: `primeaudit/lib/services/auth_service.dart`] — signUp signature and metadata passing
- [VERIFIED: `primeaudit/lib/services/company_service.dart`] — findByCnpj, create, RLS-dependent methods
- [VERIFIED: `primeaudit/lib/models/company.dart`] — Company model fields and fromMap
- [VERIFIED: `primeaudit/lib/models/app_user.dart`] — AppUser model
- [VERIFIED: `primeaudit/lib/core/app_roles.dart`] — AppRole constants
- [VERIFIED: `primeaudit/lib/core/cnpj_validator.dart`] — CNPJ validation logic
- [VERIFIED: `primeaudit/supabase/schema.sql`] — companies table base schema, UNIQUE on cnpj
- [VERIFIED: `primeaudit/supabase/migrations/20260419_rls_profiles_companies_perimeters.sql`] — RLS policies
- [VERIFIED: `primeaudit/supabase/migrations/20260420_handle_new_user_company_id.sql`] — trigger reads role from metadata
- [VERIFIED: `primeaudit/supabase/migrations/20260406_create_audits.sql`] — idempotent migration pattern
- [VERIFIED: `primeaudit/supabase/migrations/20260508_add_segment_modules_placa.sql`] — ADD COLUMN IF NOT EXISTS pattern
- [VERIFIED: `primeaudit/test/models/company_test.dart`] — existing test structure
- [VERIFIED: `.planning/config.json`] — nyquist_validation: true, commit_docs: true

### Secondary (MEDIUM confidence)
- [ASSUMED: Supabase RPC + SECURITY DEFINER pattern] — standard Supabase self-registration approach, widely documented

---

## Metadata

**Confidence breakdown:**
- Current state analysis: HIGH — all files read directly from codebase
- Migration strategy: HIGH — follows existing idempotent ADD COLUMN IF NOT EXISTS pattern verified in codebase
- RLS & auth flow: HIGH (architecture) / MEDIUM (RPC anon grant behavior — not verifiable without live Supabase project)
- Flutter implementation: HIGH — follows existing setState patterns exactly
- Service layer changes: HIGH — mirrors existing service method signatures

**Research date:** 2026-05-15
**Valid until:** 2026-06-15 (Supabase SDK 2.x stable; Flutter 3.38 stable)
