---
plan: 02-02
phase: 02-security
status: complete
completed: 2026-04-18
---

## Summary

Created consolidated idempotent RLS migration for 6 tables (profiles, companies, perimeters, audit_types, audit_templates, template_items) and the SECURITY-AUDIT.md documentation artifact (SEC-01, SEC-02).

## What Was Built

**`primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql`** — 6 tables, 19 policies, 22 DROP IF EXISTS guards. Key highlights:
- Drops broken `Admin full access on profiles/companies` policies (referenced `role = 'admin'` which doesn't exist)
- `adm_profiles_update` WITH CHECK subquery `role = (SELECT p.role FROM profiles p WHERE p.id = profiles.id)` prevents privilege escalation (SEC-02)
- `audit_types`/`audit_templates`/`template_items` include global visibility pattern (`company_id IS NULL OR company_id = get_my_company_id()`) required by app's `.or()` queries
- All policies use `get_my_role()`/`get_my_company_id()` (fixed in Plan 01 to include `active = true` guard)

**`primeaudit/SECURITY-AUDIT.md`** — Full audit document at app root: SECURITY DEFINER function status, table-by-table RLS coverage, template_sections flagged as UNKNOWN gap, 9-item manual verification plan with ⬜ pending status for Plan 04 to fill.

## Key Files

### Created
- `primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql`
- `primeaudit/SECURITY-AUDIT.md`

### Not Modified
- `primeaudit/supabase/migrations/20260406_create_audits.sql`
- `primeaudit/lib/supabase/migrations/20260406_create_audit_answers.sql`
- `primeaudit/supabase/schema.sql`

## Self-Check: PASSED

- [x] Migration covers all 6 tables with `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` (6 occurrences)
- [x] 19 `CREATE POLICY` statements, 22 `DROP POLICY IF EXISTS` (idempotent)
- [x] No `role = 'admin'` anywhere (broken pattern removed)
- [x] No `auth.jwt() ->> 'role'` anywhere (anti-pattern avoided)
- [x] `adm_profiles_update` WITH CHECK contains role-immutability subquery with alias `p`
- [x] Global visibility pattern (`company_id IS NULL OR company_id = get_my_company_id()`) present for audit_types, audit_templates, template_items
- [x] `NOTIFY pgrst, 'reload schema'` on last non-empty line
- [x] SECURITY-AUDIT.md at `primeaudit/` root (not `.planning/`)
- [x] All 8 tables documented, template_sections flagged as UNKNOWN
- [x] 9 manual verification items (10 ⬜ pending occurrences — 9 in table + 1 in legend)
