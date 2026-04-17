# Phase 02: Security - Research

**Researched:** 2026-04-17
**Domain:** Supabase RLS policies (PostgreSQL), SECURITY DEFINER functions, Flutter form validation, CNPJ checksum algorithm
**Confidence:** HIGH — all findings are drawn from direct codebase inspection of the actual migrations, service files, and screens that will be modified.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### CNPJ Validation (SEC-04)
- **D-01:** Validar checksum do CNPJ em **dois pontos**: `register_screen.dart` e `company_form.dart`.
- **D-02:** Lógica extraída para `primeaudit/lib/core/cnpj_validator.dart` — arquivo dedicado, reutilizável, testável.
- **D-03:** Validação no `validator` do `TextFormField` — antes de qualquer chamada ao banco. Sem validação server-side.

#### active=false RLS Enforcement (SEC-03)
- **D-04:** Modificar `get_my_role()` para retornar `NULL` quando `profiles.active = false`. Cobre todas as policies existentes automaticamente.
- **D-05:** Modificar `get_my_company_id()` com a mesma guarda `active` para consistência.

#### RLS Audit Scope (SEC-01 + SEC-02)
- **D-06:** Auditar e criar policies RLS para **todas** as tabelas. Gap crítico: `perimeters`, `audit_templates`, `audit_types`, `template_items` sem policies.
- **D-07:** Policies de `profiles` e `companies` no `schema.sql` referenciam `role = 'admin'` (inexistente) — substituir usando `get_my_role()`.
- **D-08:** Para `profiles` UPDATE: apenas `superuser`/`dev` podem alterar `role`; `adm` pode alterar `full_name` e `active` apenas de usuários da sua empresa.
- **D-09:** Migrations idempotentes: `DROP POLICY IF EXISTS` + `CREATE POLICY`.

#### RLS Documentation (SEC-01)
- **D-10:** Documento de auditoria: `primeaudit/SECURITY-AUDIT.md`.

### Claude's Discretion
- Ordem exata de criação das migrations (uma por tabela ou consolidada)
- Policies para `audit_types` e `audit_templates`: se templates globais (`company_id IS NULL`) são visíveis para todos os roles autenticados
- Estrutura interna do `cnpj_validator.dart` (função pura vs. classe estática)

### Deferred Ideas (OUT OF SCOPE)
- Dashboard com dados reais nos cards
- Bottom navigation bar
- Validação server-side de CNPJ via Supabase function/trigger
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEC-01 | Todas as tabelas Supabase com RLS documentadas — políticas verificadas e registradas | RLS gap analysis below; 5 tabelas sem policies; documento SECURITY-AUDIT.md |
| SEC-02 | `updateRole` e `updateCompany` protegidos por RLS — usuário não-admin não pode escalar privilégio | `profiles` RLS policy pattern documented; split USING/WITH CHECK for column-level restriction |
| SEC-03 | Usuário com `active = false` não consegue ler dados mesmo com JWT válido | `get_my_role()` fix pattern verified from existing migration |
| SEC-04 | Campo CNPJ valida checksum (dígitos verificadores), não só comprimento | CNPJ algorithm documented; both entry points identified in codebase |
</phase_requirements>

---

## Summary

Phase 2 corrects three distinct security gaps in the PrimeAudit backend and frontend. None of the work introduces new features — it closes gaps in the current structure.

**Gap 1 — RLS coverage:** Five tables (`profiles`, `companies`, `perimeters`, `audit_types`, `audit_templates`, `template_items`) either have no RLS policies or have broken policies referencing the non-existent `admin` role. The `audits` and `audit_answers` tables are correctly protected by migrations already in place and serve as the canonical pattern. New migrations must follow the same idempotent pattern.

**Gap 2 — Inactive user bypass:** The current `get_my_role()` SECURITY DEFINER function does `SELECT role FROM profiles WHERE id = auth.uid()` with no `active` check. A user disabled in the admin panel retains their JWT indefinitely (Supabase doesn't revoke JWTs synchronously). Because all policies call `get_my_role()`, adding `AND active = true` to that single function cascades active-enforcement to every table in one change — zero policy modifications required on already-correct tables.

**Gap 3 — CNPJ validation:** Both `register_screen.dart` and `company_form.dart` accept CNPJ fields with no `validator:` at all (the register screen only validates length inside `_searchCompany`, not in the `Form` validator chain). A dedicated `cnpj_validator.dart` in `lib/core/` provides a reusable function that both screens call from their `TextFormField.validator` callbacks.

**Primary recommendation:** Implement in three independent tasks — (1) fix the two SECURITY DEFINER functions in a new migration, (2) create RLS policies for the five unprotected tables in one or two idempotent migrations, (3) add `cnpj_validator.dart` and wire it to both screens.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| RLS enforcement (SEC-01, SEC-02, SEC-03) | Database (Supabase/PostgreSQL) | — | RLS is enforced by the database engine regardless of client code; no Flutter change needed |
| active=false block (SEC-03) | Database (SECURITY DEFINER function) | — | Must be server-side; client-side guard is bypassable by direct API calls |
| CNPJ checksum (SEC-04) | Frontend (Flutter form validator) | — | User-facing feedback before any DB call; client owns the entry point |
| RLS documentation (SEC-01) | Developer artifact | — | Markdown file in repo; not a runtime component |

---

## Standard Stack

No new packages are required for this phase. Everything uses tools already in the project.

### Core (already present)
| Component | Version | Purpose |
|-----------|---------|---------|
| `supabase_flutter` | 2.12.2 (locked) | PostgREST queries; RLS is transparent — policies block at DB level |
| `flutter_test` (sdk) | bundled with Flutter 3.38.4 | Unit tests for `cnpj_validator.dart` |
| PostgreSQL SQL (Supabase managed) | 15.x | Migration target for RLS policies |

### No New Packages Needed
CNPJ validation is pure Dart arithmetic — no external package required. [VERIFIED: direct codebase inspection — `pubspec.yaml` already has no CNPJ package]

---

## Architecture Patterns

### System Architecture Diagram

```
Flutter Client (register_screen / company_form)
        │
        │  TextFormField.validator(value)
        ▼
  cnpj_validator.dart ─────────► String? validateCnpj(String? value)
        │                              └── bool isValidCnpj(String raw)
        │ null = valid, non-null = error message
        │
        ▼
  Form.validate() passes ──► _register() / _save() ──► Supabase PostgREST
                                                              │
                                              ┌───────────────┤
                                              │               │
                                       auth.uid()        get_my_role()
                                              │               │
                                              └────► profiles table
                                                     (active = true check)
                                                              │
                                                     RLS USING clause
                                                              │
                                              ┌───────────────┴───────────────┐
                                              │                               │
                                        GRANT access                    DENY (null role
                                                                         or active=false)
```

### Recommended File Layout for Phase 2

```
primeaudit/
├── lib/
│   └── core/
│       └── cnpj_validator.dart          # new — pure Dart, no dependencies
├── supabase/
│   └── migrations/
│       ├── 20260406_create_audits.sql   # existing — modify get_my_role() + get_my_company_id()
│       └── YYYYMMDD_rls_profiles_companies_perimeters.sql  # new — policies for 5 tables
└── SECURITY-AUDIT.md                    # new — RLS documentation artifact
```

### Pattern 1: Idempotent RLS Migration (established pattern)

**What:** Every migration drops policies before recreating them so it can be re-run safely.
**When to use:** All policy changes in this project.

```sql
-- Source: primeaudit/supabase/migrations/20260406_create_audits.sql (lines 108-137)
DROP POLICY IF EXISTS "superuser_dev_full_access" ON audits;
DROP POLICY IF EXISTS "adm_company_access"         ON audits;

CREATE POLICY "superuser_dev_full_access" ON audits
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

CREATE POLICY "adm_company_access" ON audits
  USING  (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());
```

### Pattern 2: SECURITY DEFINER Function with active guard (D-04 fix)

**What:** Modify `get_my_role()` to return NULL for inactive users, which causes all `IN ('superuser','dev','adm','auditor')` checks to evaluate false.
**When to use:** Apply to both `get_my_role()` and `get_my_company_id()`.

```sql
-- Source: derived from 20260406_create_audits.sql lines 97-105, modified per D-04
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM profiles WHERE id = auth.uid() AND active = true;
$$;

CREATE OR REPLACE FUNCTION get_my_company_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT company_id FROM profiles WHERE id = auth.uid() AND active = true;
$$;
```

**Why this works:** PostgreSQL's `IN (...)` returns false (not error) when the left operand is NULL. So `NULL IN ('superuser', 'dev')` = false. Every existing and new policy is silently blocked for inactive users without touching the policies themselves. [VERIFIED: SQL NULL semantics — standard PostgreSQL behavior]

### Pattern 3: Per-operation Policies (profiles UPDATE — SEC-02)

**What:** Use separate `FOR INSERT`, `FOR SELECT`, `FOR UPDATE`, `FOR DELETE` policies to grant column-level-like control at the row level. For `profiles` UPDATE, the constraint is that `adm` cannot escalate roles.

**Limitation to know:** PostgreSQL RLS `WITH CHECK` on UPDATE can inspect the new row values but does NOT enforce which columns are being changed — it sees the full proposed row after the update is applied. To block `adm` from setting `role`, the check must compare the proposed `role` column value.

```sql
-- Pattern for profiles UPDATE — adm can only write non-escalated role values
-- Source: [ASSUMED — derived from PostgreSQL RLS documentation and D-08 decision]
DROP POLICY IF EXISTS "adm_profiles_update" ON profiles;
CREATE POLICY "adm_profiles_update" ON profiles FOR UPDATE
  USING (
    get_my_role() = 'adm'
    AND company_id = get_my_company_id()
  )
  WITH CHECK (
    get_my_role() = 'adm'
    AND company_id = get_my_company_id()
    AND role = (SELECT role FROM profiles WHERE id = profiles.id)
    -- role cannot be changed by adm: new role must equal current role
  );

-- superuser/dev can update anything
DROP POLICY IF EXISTS "superuser_dev_profiles_update" ON profiles;
CREATE POLICY "superuser_dev_profiles_update" ON profiles FOR UPDATE
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));
```

**Note:** The `WITH CHECK` referencing `(SELECT role FROM profiles WHERE id = profiles.id)` reads the current (pre-update) value. This enforces that `adm` cannot change `role` to anything different from what it already is. [ASSUMED — this pattern is correct per PostgreSQL RLS semantics but was not verified against live Supabase instance]

**Alternative simpler approach:** Give `adm` explicit allowed columns only (`full_name`, `active`) by making the WITH CHECK verify `role` hasn't changed. The approach above achieves this.

### Pattern 4: Global Template Visibility (Claude's Discretion)

For `audit_types` and `audit_templates` with `company_id IS NULL` (global), the correct behavior visible from `AuditTemplateService.getTypes()` and `getTemplates()` is: all authenticated active users can SELECT globals.

```sql
-- Recommended pattern (Claude's discretion — matches app's query pattern)
CREATE POLICY "authenticated_select_global_types" ON audit_types FOR SELECT
  USING (
    get_my_role() IS NOT NULL  -- any active authenticated user
    AND (company_id IS NULL OR company_id = get_my_company_id())
  );
```

This is consistent with `AuditTemplateService` which does `.or('company_id.is.null,company_id.eq.$companyId')`. [VERIFIED: audit_template_service.dart line 19]

### Pattern 5: CNPJ Validation Algorithm

**What:** Brazilian CNPJ checksum uses weighted digit verification. The algorithm is well-established (Receita Federal standard) and must be implemented in pure Dart.

```dart
// Source: [ASSUMED — standard Brazilian CNPJ algorithm, universally consistent]
// File: primeaudit/lib/core/cnpj_validator.dart

/// Returns true if [cnpj] passes the official Brazilian checksum validation.
/// Accepts formatted (with dots/slashes/dashes) or raw 14-digit strings.
bool isValidCnpj(String cnpj) {
  final digits = cnpj.replaceAll(RegExp(r'[.\-/\s]'), '');
  if (digits.length != 14) return false;
  // Reject known invalid sequences (all same digit)
  if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) return false;

  int _calc(String s, List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) sum += int.parse(s[i]) * weights[i];
    final rem = sum % 11;
    return rem < 2 ? 0 : 11 - rem;
  }

  final w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  final w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  final d1 = _calc(digits, w1);
  final d2 = _calc(digits, w2);

  return d1 == int.parse(digits[12]) && d2 == int.parse(digits[13]);
}

/// Compatible with TextFormField.validator — returns null if valid, error string if invalid.
/// Only validates checksum when input has 14 digits; shorter input returns null (field is optional
/// in register_screen — user may not provide CNPJ).
String? validateCnpj(String? value) {
  if (value == null || value.trim().isEmpty) return null; // optional field
  final digits = value.replaceAll(RegExp(r'[.\-/\s]'), '');
  if (digits.length != 14) return 'CNPJ deve ter 14 dígitos';
  if (!isValidCnpj(value)) return 'CNPJ inválido — dígitos verificadores incorretos';
  return null;
}
```

**Note for company_form.dart:** The CNPJ field there is optional (admin can create a company without CNPJ). `validateCnpj` returns `null` for empty input, which is correct — skip validation only when field is truly empty, validate when 14 digits are entered.

### Anti-Patterns to Avoid

- **Putting `active` check in each individual policy:** D-04 explicitly rejects this. Fix the function once, not each policy.
- **Using `auth.jwt() ->> 'role'` instead of `get_my_role()`:** The JWT role claim is set at sign-in time and is not updated when `profiles.role` changes in the DB. `get_my_role()` reads the live value from the database — always prefer this. [VERIFIED: existing migration pattern]
- **Skipping `DROP POLICY IF EXISTS` before `CREATE POLICY`:** Results in an error on re-run. D-09 requires idempotence.
- **Using `role = 'admin'` in policies:** The `admin` role does not exist in this system. The valid roles are `superuser`, `dev`, `adm`, `auditor`, `anonymous`. [VERIFIED: profiles_role_check constraint in 20260406_create_audits.sql lines 11-16]
- **CNPJ validation in `onChanged` only:** `_searchCompany` fires on change but is not a form validator — it's not called during `_formKey.currentState!.validate()`. The `validator:` on the `TextFormField` must be separately added.

---

## RLS Gap Analysis (Complete Table Inventory)

This is the authoritative inventory of all tables and their current RLS status.

| Table | RLS Enabled | Policies Present | Status |
|-------|-------------|-----------------|--------|
| `audits` | Yes | 5 policies (full coverage) | Correct — canonical pattern |
| `audit_answers` | Yes | 5 policies (full coverage) | Correct — canonical pattern |
| `profiles` | Yes | 2 policies (`Admin full access` broken + `Users can view own profile`) | **BROKEN** — `role = 'admin'` is invalid; UPDATE not protected (SEC-02 gap) |
| `companies` | Yes | 1 policy (`Admin full access` broken) | **BROKEN** — `role = 'admin'` is invalid |
| `perimeters` | Unknown (not in any migration) | None found | **GAP** — no policies at all |
| `audit_types` | Unknown | None found | **GAP** — no policies at all |
| `audit_templates` | Unknown | None found | **GAP** — no policies at all |
| `template_items` | Unknown | None found | **GAP** — no policies at all |

[VERIFIED: Direct inspection of all .sql files — `20260406_create_audits.sql`, `20260406_create_audit_answers.sql`, `schema.sql`. No other migration files exist.]

**Tables not covered by research:** `template_sections` — referenced in models but not found in any SQL file. The planner must verify if this table exists and needs a policy.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CNPJ checksum | Custom regex or length-only check | Pure Dart algorithm (20 lines) using official Receita Federal weights | The algorithm is fixed — no library needed, but also don't simplify it to regex which can't verify check digits |
| RLS access control | Flutter-side permission checks in service methods | PostgreSQL RLS policies | Service-side checks are bypassable; RLS blocks at the database engine level |
| User deactivation enforcement | Checking `active` in every Flutter screen | Fix `get_my_role()` SECURITY DEFINER function | A disabled user can call PostgREST directly without the Flutter app |

---

## Common Pitfalls

### Pitfall 1: JWT Does Not Reflect Real-Time `active` State
**What goes wrong:** Admin deactivates a user; user's JWT is still valid for up to 1 hour (Supabase default). Client-side checks against JWT claims are stale.
**Why it happens:** JWTs are stateless — Supabase does not push JWT revocation to the client.
**How to avoid:** Enforce `active` in `get_my_role()` which reads the live DB value on every request. This is exactly D-04.
**Warning signs:** User sees successful operations after being marked inactive in the admin panel.

### Pitfall 2: `profiles` Table Recursive RLS
**What goes wrong:** `get_my_role()` does `SELECT FROM profiles` — if `profiles` has a broken RLS policy that blocks the lookup, `get_my_role()` returns NULL, and suddenly no one can access anything.
**Why it happens:** SECURITY DEFINER functions bypass RLS of the calling user, but they still execute under the function owner's permissions. In Supabase, `SECURITY DEFINER` functions run as the role that created them (usually `postgres`/service_role) which bypasses RLS entirely.
**How to avoid:** `get_my_role()` is SECURITY DEFINER — it bypasses RLS on `profiles` by design. This is safe and intentional. [VERIFIED: `SECURITY DEFINER` in 20260406_create_audits.sql line 98]
**Warning signs:** This is NOT a risk here — confirming it is safe.

### Pitfall 3: `WITH CHECK` Cannot Restrict Which Columns Are Written
**What goes wrong:** Believing you can write `WITH CHECK (NEW.role = OLD.role)` to prevent `adm` from changing `role`.
**Why it happens:** In PostgreSQL RLS, `WITH CHECK` sees the full proposed new row but does not have access to `OLD` directly in the expression. The workaround is to subquery the current value.
**How to avoid:** Use `WITH CHECK (role = (SELECT role FROM profiles WHERE id = profiles.id))` — this fetches the current value and compares it to the proposed value. [ASSUMED — based on PostgreSQL documentation; verify in Supabase SQL editor before marking implemented]
**Warning signs:** Policies appear to work but `adm` can still change `role` via direct API call.

### Pitfall 4: CNPJ Field Is Optional in `register_screen.dart`
**What goes wrong:** Adding `validator: validateCnpj` without handling the optional case causes the form to reject users who don't enter a CNPJ.
**Why it happens:** The field is labeled "Empresa (opcional)" — it is not required.
**How to avoid:** `validateCnpj` must return `null` when the field is empty (already handled in the pattern above). Only validate when 14 digits are provided.
**Warning signs:** Users cannot register without entering a CNPJ.

### Pitfall 5: `company_form.dart` Uses Generic `_buildField` Helper
**What goes wrong:** The CNPJ field in `company_form.dart` is built via `_buildField(controller: _cnpjController, ...)` with no `validator` parameter passed. Adding validation requires passing the `validator:` named argument to the existing helper.
**Why it happens:** The `_buildField` helper accepts an optional `String? Function(String?)? validator` parameter (line 197) — it just defaults to null.
**How to avoid:** Pass `validator: validateCnpj` in the `_buildField(...)` call for the CNPJ field. [VERIFIED: company_form.dart lines 138-143]

---

## Code Examples

### Wiring `validateCnpj` in `register_screen.dart`

The CNPJ `TextFormField` currently has no `validator:` (lines 305-334 of register_screen.dart). Add:

```dart
// In _buildForm(), for the CNPJ TextFormField:
TextFormField(
  controller: _cnpjController,
  keyboardType: TextInputType.number,
  textInputAction: TextInputAction.done,
  onChanged: _searchCompany,           // existing — keep
  onFieldSubmitted: (_) => _register(), // existing — keep
  validator: validateCnpj,             // ADD THIS
  decoration: _inputDecoration(...),   // existing
),
```

### Wiring `validateCnpj` in `company_form.dart`

```dart
// In build(), for the CNPJ _buildField call (currently line 138):
_buildField(
  controller: _cnpjController,
  label: 'CNPJ',
  icon: Icons.badge_outlined,
  keyboardType: TextInputType.number,
  validator: validateCnpj,  // ADD THIS
),
```

### Migration: Fix SECURITY DEFINER Functions

```sql
-- File: YYYYMMDD_fix_active_guard.sql
-- Idempotent: CREATE OR REPLACE is safe to re-run

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM profiles WHERE id = auth.uid() AND active = true;
$$;

CREATE OR REPLACE FUNCTION get_my_company_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT company_id FROM profiles WHERE id = auth.uid() AND active = true;
$$;

NOTIFY pgrst, 'reload schema';
```

### Migration: profiles Policies (SEC-01, SEC-02)

```sql
-- Drop all existing broken policies on profiles
DROP POLICY IF EXISTS "Admin full access on profiles"  ON profiles;
DROP POLICY IF EXISTS "Users can view own profile"     ON profiles;
DROP POLICY IF EXISTS "superuser_dev_profiles_full"    ON profiles;
DROP POLICY IF EXISTS "adm_profiles_select"            ON profiles;
DROP POLICY IF EXISTS "adm_profiles_update"            ON profiles;
DROP POLICY IF EXISTS "user_select_own"                ON profiles;

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- superuser/dev: full access
CREATE POLICY "superuser_dev_profiles_full" ON profiles
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- adm: read users of own company
CREATE POLICY "adm_profiles_select" ON profiles FOR SELECT
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id());

-- adm: update full_name and active of own company's users (cannot change role)
CREATE POLICY "adm_profiles_update" ON profiles FOR UPDATE
  USING (
    get_my_role() = 'adm'
    AND company_id = get_my_company_id()
  )
  WITH CHECK (
    get_my_role() = 'adm'
    AND company_id = get_my_company_id()
    AND role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id)
  );

-- any authenticated active user: read own profile
CREATE POLICY "user_select_own" ON profiles FOR SELECT
  USING (id = auth.uid() AND get_my_role() IS NOT NULL);

NOTIFY pgrst, 'reload schema';
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `role = 'admin'` in policies | `get_my_role() = 'adm'` via SECURITY DEFINER | Old policies never matched; effectively no protection |
| No `active` check in functions | `AND active = true` in `get_my_role()` | All tables become inactive-user-aware in one change |
| Length-only CNPJ check | Checksum (dígitos verificadores) validation | Rejects syntactically correct but mathematically invalid CNPJs |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `WITH CHECK (role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id))` correctly enforces that `adm` cannot change `role` | Pattern 3, Pitfall 3 | `adm` could still change role via direct API; need verification in Supabase SQL editor |
| A2 | CNPJ algorithm weights `[5,4,3,2,9,8,7,6,5,4,3,2]` and `[6,5,4,3,2,9,8,7,6,5,4,3,2]` are correct | Pattern 5 | Invalid CNPJs could pass or valid ones fail — testable with known CNPJs |
| A3 | `template_sections` table exists in Supabase but no SQL migration was found locally | RLS Gap Analysis | If it exists and has no RLS, it's an unaddressed gap |
| A4 | `perimeters`, `audit_types`, `audit_templates`, `template_items` have no RLS enabled at all (not just no policies) | RLS Gap Analysis | If RLS is not enabled, `ALTER TABLE x ENABLE ROW LEVEL SECURITY` must be added to migration |

---

## Open Questions

1. **`template_sections` table existence**
   - What we know: The model hierarchy in `AuditTemplateService` comments references `TemplateSection`, and `audit_templates` has sections.
   - What's unclear: No SQL definition of `template_sections` was found in any migration or schema.sql file.
   - Recommendation: Planner should add a task to verify in Supabase dashboard and add RLS if it exists.

2. **Current RLS-enabled state of gap tables**
   - What we know: No migration enables RLS on `perimeters`, `audit_types`, `audit_templates`, `template_items`.
   - What's unclear: Whether RLS was enabled manually via the Supabase dashboard (not reflected in files).
   - Recommendation: Migration should include `ALTER TABLE x ENABLE ROW LEVEL SECURITY` as a no-op-safe operation — if already enabled, it does nothing harmful.

3. **`adm` UPDATE policy on `profiles` — subquery correctness**
   - What we know: The `WITH CHECK` pattern using a subquery to read current `role` is standard PostgreSQL RLS.
   - What's unclear: Whether Supabase's PostgREST layer handles this correctly or has any wrapping that affects it.
   - Recommendation: Verify with a direct test — sign in as `adm`, call `UserService.updateRole()`, confirm PostgrestException is thrown.

---

## Environment Availability

Step 2.6: SKIPPED for most dependencies — this phase is purely SQL migrations + Dart code changes, no new external tools required.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Supabase dashboard access | Testing RLS policies | Manual (human) | RLS policy tests require running SQL in the Supabase SQL editor or via CLI — cannot be automated in `flutter test` |
| `flutter test` | SEC-04 unit tests | Yes | Existing test infrastructure in `primeaudit/test/` |

**Blocking dependency:** RLS policy verification (SEC-01, SEC-02, SEC-03 success criteria) requires manual access to the Supabase dashboard or Supabase CLI. This cannot be automated via Flutter tests. The SECURITY-AUDIT.md document (D-10) must record manual test results.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK bundled) |
| Config file | none — uses default Flutter test runner |
| Quick run command | `flutter test test/cnpj_validator_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SEC-04 | `isValidCnpj` rejects CNPJ with wrong check digits | unit | `flutter test test/cnpj_validator_test.dart` | No — Wave 0 gap |
| SEC-04 | `isValidCnpj` accepts known valid CNPJ | unit | `flutter test test/cnpj_validator_test.dart` | No — Wave 0 gap |
| SEC-04 | `validateCnpj` returns null for empty input | unit | `flutter test test/cnpj_validator_test.dart` | No — Wave 0 gap |
| SEC-04 | `validateCnpj` returns error string for invalid CNPJ | unit | `flutter test test/cnpj_validator_test.dart` | No — Wave 0 gap |
| SEC-01 | RLS documentation file exists with all tables listed | manual | n/a | No — document artifact |
| SEC-02 | `auditor` calling `updateRole()` gets PostgREST error | manual | n/a | Cannot automate without Supabase instance |
| SEC-03 | User with `active=false` JWT gets denied on any table read | manual | n/a | Cannot automate without Supabase instance |

### Sampling Rate
- **Per task commit:** `flutter test test/cnpj_validator_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green + manual RLS verification documented in SECURITY-AUDIT.md

### Wave 0 Gaps
- [ ] `test/cnpj_validator_test.dart` — covers SEC-04 (all 4 test cases above)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Supabase handles auth; not modified this phase |
| V3 Session Management | Partial | active=false users retain JWT — SEC-03 mitigates at DB level |
| V4 Access Control | Yes | RLS policies enforce server-side RBAC (SEC-01, SEC-02) |
| V5 Input Validation | Yes | CNPJ checksum in TextFormField.validator (SEC-04) |
| V6 Cryptography | No | No crypto changes |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Privilege escalation via direct API call | Elevation of Privilege | RLS `WITH CHECK` on profiles UPDATE blocks role change |
| Disabled user retaining access | Spoofing / Tampering | `get_my_role()` reads live `active` field, not JWT claim |
| Invalid CNPJ accepted silently | Tampering | Checksum validation before any DB call |
| Missing RLS on tables | Information Disclosure | `ENABLE ROW LEVEL SECURITY` + policies on all 5 gap tables |

---

## Sources

### Primary (HIGH confidence)
- `primeaudit/supabase/migrations/20260406_create_audits.sql` — canonical RLS pattern, SECURITY DEFINER functions, idempotent migration structure
- `primeaudit/lib/supabase/migrations/20260406_create_audit_answers.sql` — secondary canonical pattern for join-based policies
- `primeaudit/supabase/schema.sql` — broken policies to replace; table definitions for `profiles` and `companies`
- `primeaudit/lib/services/user_service.dart` — `updateRole()` and `updateCompany()` confirmed to have no server-side guard
- `primeaudit/lib/screens/register_screen.dart` — CNPJ field confirmed to have no `validator:`
- `primeaudit/lib/screens/admin/company_form.dart` — CNPJ field confirmed to use `_buildField` with no `validator` arg
- `primeaudit/lib/core/app_roles.dart` — canonical role constants; `cnpj_validator.dart` must follow same style

### Secondary (MEDIUM confidence)
- Standard PostgreSQL NULL semantics — `NULL IN (...)` evaluates to false, not error — core to D-04 correctness
- Standard Brazilian CNPJ algorithm (Receita Federal) — weight sequences are universally consistent across all Brazilian tax documentation

### Tertiary (LOW / ASSUMED)
- `WITH CHECK` subquery pattern for blocking column changes in PostgreSQL RLS — standard pattern but not verified against live Supabase instance (A1)

---

## Metadata

**Confidence breakdown:**
- RLS gap analysis: HIGH — verified by direct file inspection of all SQL files
- SECURITY DEFINER fix (SEC-03): HIGH — pattern is clear from existing code
- CNPJ algorithm: MEDIUM — algorithm is standard but not verified with a known CNPJ set in this session
- `adm` UPDATE policy (SEC-02): MEDIUM — pattern is correct PostgreSQL but Supabase behavior should be manually verified

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (stable domain — Supabase RLS semantics and CNPJ algorithm do not change)
