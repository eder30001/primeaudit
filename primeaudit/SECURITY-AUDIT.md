# SECURITY-AUDIT — PrimeAudit

**Audited:** 2026-04-18
**Phase:** 02-security
**Requirements covered:** SEC-01, SEC-02, SEC-03
**Migrations applied:**
- `primeaudit/supabase/migrations/20260406_create_audits.sql`
- `primeaudit/lib/supabase/migrations/20260406_create_audit_answers.sql`
- `primeaudit/supabase/migrations/20260418_fix_active_guard.sql` (Plan 01 — SEC-03)
- `primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql` (Plan 02 — SEC-01 + SEC-02)

---

## SECURITY DEFINER Functions

| Function | Returns | Guarded by `active = true` | Purpose |
|----------|---------|----------------------------|---------|
| `get_my_role()` | TEXT (role) or NULL | ✅ Yes (Plan 01, D-04) | Resolves caller role from profiles; NULL for inactive users |
| `get_my_company_id()` | UUID or NULL | ✅ Yes (Plan 01, D-05) | Resolves caller company scope; NULL for inactive users |

**Cascade effect (SEC-03):** All policies that use `get_my_role() IN (...)` or `get_my_role() = 'xxx'` automatically deny inactive users because `NULL IN (...)` and `NULL = 'xxx'` both evaluate to false in PostgreSQL.

---

## Table-by-Table RLS Coverage

### `audits`
- **RLS enabled:** ✅ (20260406_create_audits.sql)
- **Policies:**
  - `superuser_dev_full_access` — ALL — `get_my_role() IN ('superuser','dev')`
  - `adm_company_access` — ALL — `get_my_role() = 'adm' AND company_id = get_my_company_id()`
  - `auditor_select_company` — SELECT — `get_my_role() = 'auditor' AND company_id = get_my_company_id()`
  - `auditor_insert_own` — INSERT — auditor AND company match AND `auditor_id = auth.uid()`
  - `auditor_update_own` — UPDATE — auditor AND `auditor_id = auth.uid()`

### `audit_answers`
- **RLS enabled:** ✅ (20260406_create_audit_answers.sql)
- **Policies:**
  - `superuser_dev_answers_full` — ALL — `get_my_role() IN ('superuser','dev')`
  - `adm_answers_company` — ALL — adm AND EXISTS audit of same company
  - `auditor_answers_select` — SELECT — auditor AND EXISTS audit of same company
  - `auditor_answers_insert` — INSERT — auditor AND EXISTS audit with `auditor_id = auth.uid()`
  - `auditor_answers_update` — UPDATE — auditor AND EXISTS audit with `auditor_id = auth.uid()`

### `profiles`
- **RLS enabled:** ✅ (20260418_rls_profiles_companies_perimeters.sql)
- **Broken policies removed:** `Admin full access on profiles`, `Users can view own profile` (schema.sql lines 51-56 — referenced inexistent role 'admin')
- **Policies:**
  - `superuser_dev_profiles_full` — ALL — `get_my_role() IN ('superuser','dev')`
  - `adm_profiles_select` — SELECT — `get_my_role() = 'adm' AND company_id = get_my_company_id()`
  - `adm_profiles_update` — UPDATE — adm AND same company; **WITH CHECK enforces `role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id)` — adm cannot change role column (SEC-02)**
  - `user_select_own` — SELECT — `id = auth.uid() AND get_my_role() IS NOT NULL`

### `companies`
- **RLS enabled:** ✅ (20260418_rls_profiles_companies_perimeters.sql)
- **Broken policies removed:** `Admin full access on companies`
- **Policies:**
  - `superuser_dev_companies_full` — ALL — `get_my_role() IN ('superuser','dev')`
  - `adm_companies_select` — SELECT — `get_my_role() = 'adm' AND id = get_my_company_id()`
  - `auditor_companies_select` — SELECT — `get_my_role() = 'auditor' AND id = get_my_company_id()`

### `perimeters`
- **RLS enabled:** ✅ (20260418_rls_profiles_companies_perimeters.sql — was a gap, now closed)
- **Policies:**
  - `superuser_dev_perimeters_full` — ALL — `get_my_role() IN ('superuser','dev')`
  - `adm_perimeters_company` — ALL — `get_my_role() = 'adm' AND company_id = get_my_company_id()`
  - `auditor_perimeters_select` — SELECT — `get_my_role() = 'auditor' AND company_id = get_my_company_id()`

### `audit_types`
- **RLS enabled:** ✅ (20260418_rls_profiles_companies_perimeters.sql — was a gap, now closed)
- **Policies:**
  - `superuser_dev_audit_types_full` — ALL — `get_my_role() IN ('superuser','dev')`
  - `adm_audit_types_company` — ALL — `get_my_role() = 'adm' AND company_id = get_my_company_id()`
  - `authenticated_audit_types_select` — SELECT — `get_my_role() IS NOT NULL AND (company_id IS NULL OR company_id = get_my_company_id())` (globals visíveis a todos os ativos)

### `audit_templates`
- **RLS enabled:** ✅ (20260418_rls_profiles_companies_perimeters.sql — was a gap, now closed)
- **Policies:**
  - `superuser_dev_audit_templates_full` — ALL — `get_my_role() IN ('superuser','dev')`
  - `adm_audit_templates_company` — ALL — `get_my_role() = 'adm' AND company_id = get_my_company_id()`
  - `authenticated_audit_templates_select` — SELECT — `get_my_role() IS NOT NULL AND (company_id IS NULL OR company_id = get_my_company_id())`

### `template_items`
- **RLS enabled:** ✅ (20260418_rls_profiles_companies_perimeters.sql — was a gap, now closed)
- **Policies:**
  - `superuser_dev_template_items_full` — ALL — `get_my_role() IN ('superuser','dev')`
  - `adm_template_items_company` — ALL — adm AND EXISTS template of same company
  - `authenticated_template_items_select` — SELECT — any active authenticated user AND EXISTS template (global or same company)

### `template_sections`
- **Status:** ⚠️ UNKNOWN — table not found in any local SQL file (Assumption A3 from RESEARCH.md)
- **Action item:** Verify existence in Supabase dashboard during Plan 04 manual verification. If exists with RLS disabled or no policies, file follow-up migration.

---

## Manual Verification Plan

These tests cannot be automated by `flutter test` — they require a Supabase session / SQL editor. Execute during Plan 04 (BLOCKING gate).

| # | Requirement | Scenario | Expected Result | Status |
|---|-------------|----------|-----------------|--------|
| 1 | SEC-03 | Autenticado como usuário com `active = true`, execute `SELECT get_my_role();` no SQL editor | Retorna a role do perfil | ⬜ pending |
| 2 | SEC-03 | Autenticado como usuário com `active = false`, execute `SELECT get_my_role();` | Retorna NULL | ⬜ pending |
| 3 | SEC-03 | Autenticado como usuário com `active = false` (JWT válido), `SELECT * FROM audits LIMIT 1;` | 0 rows | ⬜ pending |
| 4 | SEC-03 | Autenticado como usuário com `active = false`, `SELECT * FROM audit_answers LIMIT 1;` | 0 rows | ⬜ pending |
| 5 | SEC-02 | Autenticado como `auditor`, execute `UPDATE profiles SET role = 'superuser' WHERE id = auth.uid();` | `0 rows updated` OU PostgREST error 42501 | ⬜ pending |
| 6 | SEC-02 | Autenticado como `adm`, tente `UPDATE profiles SET role = 'superuser' WHERE id = '<user-da-sua-empresa>';` | `0 rows updated` (WITH CHECK bloqueia mudança da coluna role) | ⬜ pending |
| 7 | SEC-02 | Autenticado como `adm`, `UPDATE profiles SET full_name = 'Teste' WHERE id = '<user-da-sua-empresa>';` | 1 row updated (full_name é permitido) | ⬜ pending |
| 8 | SEC-01 | No dashboard Supabase, abrir Table Editor → Authentication → Policies: verificar que cada tabela listada acima tem RLS ON | Todas as 8 tabelas listam "RLS enabled" | ⬜ pending |
| 9 | SEC-01 | Verificar existência de `template_sections` no dashboard | Documentar resultado (existe ou não) | ⬜ pending |

### Status Legend
- ⬜ pending — aguardando execução manual
- ✅ passed — verificação executada e resultado corresponde ao esperado
- ❌ failed — verificação falhou; criar gap para Plan 05+

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Documento criado (Phase 02-security Plan 02) |
| — | Plan 04 preencherá os resultados de verificação manual |
