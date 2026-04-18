---
plan: 02-01
phase: 02-security
status: complete
completed: 2026-04-18
---

## Summary

Created idempotent SQL migration `20260418_fix_active_guard.sql` that rewrites both `get_my_role()` and `get_my_company_id()` SECURITY DEFINER functions with `AND active = true` predicate.

## What Was Built

**`primeaudit/supabase/migrations/20260418_fix_active_guard.sql`** — Single migration file with two `CREATE OR REPLACE FUNCTION` statements. No policies modified — the fix cascades automatically: every existing RLS policy that calls `get_my_role() IN (...)` or `get_my_company_id()` will now deny inactive users because `NULL IN (...)` evaluates to false in PostgreSQL.

## Key Files

### Created
- `primeaudit/supabase/migrations/20260418_fix_active_guard.sql`

### Not Modified
- `primeaudit/supabase/migrations/20260406_create_audits.sql` (original unchanged — `CREATE OR REPLACE` overwrites the function definition in the database on push)

## Self-Check: PASSED

- [x] Migration file exists with both functions rewritten
- [x] Both functions contain `AND active = true` (2 occurrences)
- [x] Migration contains no `CREATE POLICY` or `DROP POLICY` statements
- [x] `NOTIFY pgrst, 'reload schema'` present
- [x] Idempotent: uses `CREATE OR REPLACE`, no `DROP` required
- [x] Original `20260406_create_audits.sql` unmodified (git diff clean)
